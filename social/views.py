from __future__ import annotations

import logging

from django.db.models import Q
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.exceptions import PermissionDenied

from movies.models import Movie
from .models import (
    Favorite,
    Like,
    Review,
    Friendship,
    FriendRequest,
    MovieNight,
    MovieNightParticipant,
    FriendSuggestion,
)
from .serializers import (
    FavoriteSerializer,
    LikeToggleSerializer,
    ReviewSerializer,
    ShareSerializer,
    SocialStatsSerializer,
    SocialPostGenerateSerializer,
    FriendshipSerializer,
    FriendRequestSerializer,
    MovieNightSerializer,
    MovieNightParticipantSerializer,
    MovieNightVoteSerializer,
)
from notifications.services import (
    gemini_advanced_sentiment,
    gemini_generate_social_posts,
)
from notifications.models import Notification

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
    """Run Gemini sentiment analysis on a review and save results."""

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


# ---- Friend System Views ----


class FriendRequestListCreateView(generics.ListCreateAPIView):
    """List related friend requests or create a new one."""

    serializer_class = FriendRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return (
            FriendRequest.objects.filter(Q(from_user=user) | Q(to_user=user))
            .select_related("from_user", "to_user")
            .order_by("-created_at")
        )

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx.update({"request": self.request})
        return ctx


class FriendRequestUpdateView(generics.UpdateAPIView):
    """Accept/decline a friend request by updating `status`.

    Only the recipient (`to_user`) can update. When accepted, create
    reciprocal `Friendship` rows.
    """

    serializer_class = FriendRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = FriendRequest.objects.all().select_related("from_user", "to_user")

    def update(self, request, *args, **kwargs):
        instance: FriendRequest = self.get_object()
        if instance.to_user != request.user:
            raise PermissionDenied(
                "Only the recipient can update this request."
            )
        action = request.data.get("action")  # "accept" or "decline"
        if action == "accept":
            instance.status = FriendRequest.STATUS_ACCEPTED
            instance.save(update_fields=["status", "updated_at"])
            # create friendships both directions
            Friendship.objects.get_or_create(
                user=instance.from_user,
                friend=instance.to_user,
            )
            Friendship.objects.get_or_create(
                user=instance.to_user,
                friend=instance.from_user,
            )
        elif action == "decline":
            instance.status = FriendRequest.STATUS_DECLINED
            instance.save(update_fields=["status", "updated_at"])
        else:
            return Response(
                {"detail": "Invalid action."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = self.get_serializer(instance)
        return Response(serializer.data)


class FriendshipListView(generics.ListAPIView):
    """List current user's friends."""

    serializer_class = FriendshipSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Friendship.objects.filter(user=self.request.user)
            .select_related("user", "friend")
            .order_by("-created_at")
        )


# ---- Movie Night Views ----


class MovieNightListCreateView(generics.ListCreateAPIView):
    """List or create movie nights."""

    serializer_class = MovieNightSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            MovieNight.objects.all()
            .select_related("organizer")
            .prefetch_related("participants__user")
            .order_by("-created_at")
        )

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx.update({"request": self.request})
        return ctx


class MovieNightDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update, or delete a movie night.

    Only the organizer can update or delete.
    """

    serializer_class = MovieNightSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = (
        MovieNight.objects.all()
        .select_related("organizer")
        .prefetch_related("participants__user")
    )

    def perform_update(self, serializer):
        obj: MovieNight = self.get_object()
        if obj.organizer != self.request.user:
            raise PermissionDenied("Only the organizer can update this movie night.")
        serializer.save()

    def perform_destroy(self, instance: MovieNight):
        if instance.organizer != self.request.user:
            raise PermissionDenied("Only the organizer can delete this movie night.")
        return super().perform_destroy(instance)


class MovieNightParticipantView(APIView):
    """Join or leave a movie night for the current user."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int):
        movie_night = MovieNight.objects.filter(pk=pk).first()
        if not movie_night:
            return Response(
                {"detail": "Movie night not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        # capacity check
        if movie_night.max_participants:
            accepted_count = MovieNightParticipant.objects.filter(
                movie_night=movie_night,
                status=MovieNightParticipant.STATUS_ACCEPTED,
            ).count()
            if accepted_count >= movie_night.max_participants:
                return Response(
                    {"detail": "Movie night is full."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        participant, _ = MovieNightParticipant.objects.get_or_create(
            movie_night=movie_night,
            user=request.user,
            defaults={"status": MovieNightParticipant.STATUS_ACCEPTED},
        )
        if participant.status != MovieNightParticipant.STATUS_ACCEPTED:
            participant.status = MovieNightParticipant.STATUS_ACCEPTED
            participant.save(update_fields=["status"])
        return Response(MovieNightParticipantSerializer(participant).data)

    def delete(self, request, pk: int):
        movie_night = MovieNight.objects.filter(pk=pk).first()
        if not movie_night:
            return Response({"detail": "Movie night not found."}, status=status.HTTP_404_NOT_FOUND)
        participant = MovieNightParticipant.objects.filter(
            movie_night=movie_night, user=request.user
        ).first()
        if not participant:
            return Response(status=status.HTTP_204_NO_CONTENT)
        participant.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MovieNightVoteView(generics.CreateAPIView):
    """Vote for a movie for a given movie night."""

    serializer_class = MovieNightVoteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        movie_night = MovieNight.objects.filter(pk=self.kwargs.get("pk")).first()
        ctx.update({"request": self.request, "movie_night": movie_night})
        return ctx


class UsersByGenreView(APIView):
    """Find users who engaged with movies in any of the given genres.

    Query params:
    - genres: comma-separated list (e.g. "Action,Drama,Comedy")

    Response includes: id, username, email, and a small preferences summary.
    """

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request):
        genres_param = request.query_params.get("genres", "")
        if not genres_param.strip():
            return Response(
                {"detail": "Query param 'genres' is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        genres = [g.strip() for g in genres_param.split(",") if g.strip()]
        if not genres:
            return Response({"users": [], "count": 0})

        # Build engagement filter over favorites and likes
        q = Q()
        for g in genres:
            q |= Q(favorites__movie__genre__icontains=g)
            q |= Q(likes__movie__genre__icontains=g)

        User = get_user_model()

        # Anti-spam: exclude users with recent notifications (last 24h)
        cutoff = timezone.now() - timedelta(hours=24)
        recent_notified_user_ids = set(
            Notification.objects.filter(sent_at__gte=cutoff)
            .values_list("user_id", flat=True)
        )

        users_qs = (
            User.objects.filter(q)
            .exclude(id__in=recent_notified_user_ids)
            .distinct()
        )

        # Summarize preference data per user
        def _engagement_counts(user_id: int) -> dict:
            genre_q = Q()
            for g in genres:
                genre_q |= Q(movie__genre__icontains=g)
            fav_count = (
                Favorite.objects.filter(user_id=user_id)
                .filter(genre_q)
                .count()
            )
            like_count = (
                Like.objects.filter(user_id=user_id)
                .filter(genre_q)
                .count()
            )
            return {
                "total_engagements": fav_count + like_count,
                "favorites": fav_count,
                "likes": like_count,
            }

        users = []
        for u in users_qs.values("id", "username", "email"):
            users.append(
                {
                    "id": u["id"],
                    "username": u.get("username") or "",
                    "email": u.get("email") or "",
                    "preferences": _engagement_counts(u["id"]),
                }
            )

        return Response({"users": users, "count": len(users)})


class FriendSuggestionsView(APIView):
    """Receive friend suggestions from n8n and log them.

    POST only. Requires authentication. Payload is expected to be JSON from the
    recommendation pipeline (n8n). We log for debugging and, when possible,
    upsert `FriendSuggestion` rows for the authenticated user. Returns 201 on
    success with a short summary. Errors are handled gracefully with a 400.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            data = request.data or {}
            logger.debug(
                "friend_suggestions: user=%s payload=%s",
                request.user.id,
                data,
            )

            # Optional persistence if payload contains structured suggestions
            suggestions = data.get("suggestions")
            saved = 0
            if isinstance(suggestions, list):
                for item in suggestions:
                    try:
                        suggested_user_id = (
                            item.get("suggested_user_id")
                            if isinstance(item, dict)
                            else None
                        )
                        # Some flows might provide `user_id` instead
                        if suggested_user_id is None and isinstance(item, dict):
                            suggested_user_id = item.get("user_id")
                        if not isinstance(suggested_user_id, int):
                            continue
                        similarity_score = (
                            item.get("similarity_score")
                            if isinstance(item, dict)
                            else None
                        )
                        shared_genres = (
                            item.get("shared_genres")
                            if isinstance(item, dict)
                            else None
                        )
                        defaults = {}
                        if similarity_score is not None:
                            defaults["similarity_score"] = similarity_score
                        if shared_genres is not None:
                            defaults["shared_genres"] = shared_genres
                        FriendSuggestion.objects.update_or_create(
                            user=request.user,
                            suggested_user_id=suggested_user_id,
                            defaults=defaults,
                        )
                        saved += 1
                    except Exception:  # pragma: no cover - best-effort per item
                        logger.exception(
                            (
                                "friend_suggestions: "
                                "failed to upsert item for user=%s"
                            ),
                            request.user.id,
                        )

            return Response(
                {
                    "detail": "Friend suggestions received.",
                    "received": bool(data),
                    "saved": saved,
                },
                status=status.HTTP_201_CREATED,
            )
        except Exception as exc:
            logger.exception(
                "friend_suggestions: error user=%s",
                request.user.id,
            )
            return Response(
                {
                    "detail": "Invalid payload or server error.",
                    "error": str(exc),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
