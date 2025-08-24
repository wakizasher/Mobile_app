from __future__ import annotations

from django.db.models import Count
import logging
from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.throttling import ScopedRateThrottle

from .models import Movie
from .serializers import MovieSerializer
from .services import search_movies, get_movie_details, map_omdb_to_fields
from notifications.services import gemini_summarize_reviews
from social.models import Review

logger = logging.getLogger(__name__)


class MovieSearchView(APIView):
    """Search movies via OMDb API.

    Query params: q (required), page (optional)
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        query = request.query_params.get("q")
        if not query:
            return Response(
                {"detail": "Query parameter 'q' is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        page = int(request.query_params.get("page", 1))
        try:
            data = search_movies(query, page)
        except Exception as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(data)


class MovieDetailView(RetrieveAPIView):
    """Return movie details, caching in DB if necessary."""

    serializer_class = MovieSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = "imdb_id"
    queryset = Movie.objects.all()

    def get_object(self):
        imdb_id = self.kwargs.get("imdb_id")
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if movie:
            return movie
        # fetch and cache
        payload = get_movie_details(imdb_id)
        if not payload or payload.get("Response") == "False":
            raise get_object_or_404(Movie, pk=0)  # force 404
        fields = map_omdb_to_fields(payload)
        movie = Movie.objects.create(**fields)
        return movie


class PopularMoviesView(ListAPIView):
    """List popular movies based on likes and favorites counts."""

    serializer_class = MovieSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            Movie.objects.annotate(
                favorites_count=Count("favorites", distinct=True),
                likes_count=Count("likes", distinct=True),
            )
            .order_by("-favorites_count", "-likes_count", "-updated_at")
        )


class ReviewSummaryView(APIView):
    """Summarize reviews for a movie using Gemini.

    GET /api/movies/<imdb_id>/review-summary/
    """

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request, imdb_id: str):
        movie = (
            Movie.objects.filter(imdb_id=imdb_id)
            .values("imdb_id", "title", "genre", "year", "plot")
            .first()
        )
        if not movie:
            # attempt to fetch and cache
            payload = get_movie_details(imdb_id)
            if not payload or payload.get("Response") == "False":
                return Response(
                    {"detail": "Movie not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            fields = map_omdb_to_fields(payload)
            m = Movie.objects.create(**fields)
            movie = {
                "imdb_id": m.imdb_id,
                "title": m.title,
                "genre": m.genre,
                "year": m.year,
                "plot": m.plot,
            }
            logger.debug(
                "review_summary: fetched movie imdb_id=%s title=%s",
                imdb_id,
                movie.get("title"),
            )
        else:
            logger.debug(
                "review_summary: using cached movie imdb_id=%s title=%s",
                imdb_id,
                movie.get("title"),
            )

        genres = [s.strip() for s in (movie.get("genre") or "").split(",") if s.strip()]
        movie_dict = {
            "imdb_id": movie.get("imdb_id"),
            "title": movie.get("title"),
            "genres": genres,
            "year": movie.get("year"),
            "plot": movie.get("plot"),
        }
        reviews_qs = (
            Review.objects.filter(movie__imdb_id=imdb_id)
            .values("content", "rating", "sentiment")
        )
        reviews = list(reviews_qs)
        logger.debug(
            "review_summary: imdb_id=%s reviews_count=%s", imdb_id, len(reviews)
        )
        data = gemini_summarize_reviews(movie=movie_dict, reviews=reviews)
        return Response(data)
