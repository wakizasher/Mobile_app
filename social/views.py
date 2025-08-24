from __future__ import annotations

import logging

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.throttling import ScopedRateThrottle

from movies.models import Movie
from .models import Favorite, Like, Review
from .serializers import (
    FavoriteSerializer,
    LikeToggleSerializer,
    ReviewSerializer,
    ShareSerializer,
    SocialStatsSerializer,
    SocialPostGenerateSerializer,
)
from notifications.services import (
    gemini_advanced_sentiment,
    gemini_generate_social_posts,
)

logger = logging.getLogger(__name__)


class FavoriteListCreateView(generics.ListCreateAPIView):
    """List authenticated user's favorites or add a new favorite by IMDB id."""

    serializer_class = FavoriteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Favorite.objects.filter(user=self.request.user)
            .select_related("movie")
        )


class FavoriteDeleteView(APIView):
    """Remove a favorite by IMDB id."""

    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, imdb_id: str):
        fav = (
            Favorite.objects.filter(user=request.user, movie__imdb_id=imdb_id)
            .first()
        )
        if not fav:
            return Response(
                {"detail": "Favorite not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        fav.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class LikeToggleView(APIView):
    """Toggle like for a movie by IMDB id."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = LikeToggleSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return Response(result)


class ShareCreateView(generics.CreateAPIView):
    """Create a share record for a movie by IMDB id."""

    serializer_class = ShareSerializer
    permission_classes = [permissions.IsAuthenticated]


class ReviewListCreateView(generics.ListCreateAPIView):
    """List reviews for a movie (by imdb_id query) or create a new one."""

    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        imdb_id = self.request.query_params.get("imdb_id")
        qs = Review.objects.all().select_related("user", "movie")
        if imdb_id:
            qs = qs.filter(movie__imdb_id=imdb_id)
        return qs


class SocialStatsView(APIView):
    """Get social stats (likes, favorites, reviews) for a movie by IMDB id."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, imdb_id: str):
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if not movie:
            return Response(
                {"detail": "Movie not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        stats = {
            "likes": Like.objects.filter(movie=movie).count(),
            "favorites": Favorite.objects.filter(movie=movie).count(),
            "reviews": Review.objects.filter(movie=movie).count(),
        }
        return Response(SocialStatsSerializer(stats).data)


class ReviewSentimentAnalysisView(APIView):
    """Run advanced Gemini sentiment analysis on a specific review and persist results."""

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request, review_id: int):
        review = (
            Review.objects.filter(id=review_id, user=request.user)
            .select_related("movie")
            .first()
        )
        if not review:
            return Response(
                {"detail": "Review not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        logger.debug(
            "sentiment: user=%s review_id=%s content_len=%s",
            request.user.id,
            review_id,
            len(review.content or ""),
        )
        adv = gemini_advanced_sentiment(review.content or "")
        if isinstance(adv, dict):
            review.sentiment = adv.get("overall") or review.sentiment
            review.sentiment_confidence = adv.get("confidence")
            review.emotions = adv.get("emotions") or {}
            review.sentiment_breakdown = adv.get("breakdown") or {}
            review.save(
                update_fields=[
                    "sentiment",
                    "sentiment_confidence",
                    "emotions",
                    "sentiment_breakdown",
                ]
            )
            logger.debug(
                "sentiment: saved review_id=%s overall=%s conf=%s "
                "emotions_keys=%s",
                review.id,
                review.sentiment,
                review.sentiment_confidence,
                sorted(list((review.emotions or {}).keys())),
            )
        return Response(
            {
                "id": review.id,
                "overall": review.sentiment,
                "confidence": review.sentiment_confidence,
                "emotions": review.emotions,
                "breakdown": review.sentiment_breakdown,
            }
        )


class GenerateSocialPostView(APIView):
    """Generate platform-specific social posts for a movie and current user."""

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def post(self, request):
        serializer = SocialPostGenerateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        imdb_id = serializer.validated_data["imdb_id"]
        preferences = serializer.validated_data.get("preferences") or {}

        movie = (
            Movie.objects.filter(imdb_id=imdb_id)
            .values("imdb_id", "title", "genre", "year", "plot")
            .first()
        )
        if not movie:
            return Response(
                {"detail": "Movie not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        # Normalize movie dict
        genres = [
            s.strip()
            for s in (movie.get("genre") or "").split(",")
            if s.strip()
        ]
        movie_dict = {
            "imdb_id": movie.get("imdb_id"),
            "title": movie.get("title"),
            "genres": genres,
            "year": movie.get("year"),
            "plot": movie.get("plot"),
        }
        user_dict = {
            "id": request.user.id,
            "username": getattr(request.user, "username", ""),
        }
        posts = gemini_generate_social_posts(
            movie=movie_dict,
            user=user_dict,
            preferences=preferences,
        )
        return Response(posts)
