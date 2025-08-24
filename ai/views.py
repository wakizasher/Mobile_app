from __future__ import annotations

from typing import Any, Dict
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from social.models import Favorite, Like, Review
from notifications.services import gemini_generate_recommendations
from notifications.services import gemini_healthcheck


class RecommendationsView(APIView):
    """Generate personalized movie recommendations for the user.

    Requires authentication and is LLM throttled.
    """

    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request):
        user = request.user
        # Build context from user's favorites, likes, and reviews
        favorites = (
            Favorite.objects.filter(user=user)
            .select_related("movie")
            .values(
                "movie__imdb_id",
                "movie__title",
                "movie__genre",
            )
        )
        likes = (
            Like.objects.filter(user=user)
            .select_related("movie")
            .values(
                "movie__imdb_id",
                "movie__title",
                "movie__genre",
            )
        )
        reviews_qs = (
            Review.objects.filter(user=user)
            .values(
                "content",
                "sentiment",
                "rating",
            )
        )

        def _norm_items(items):
            out = []
            for it in items:
                genres = []
                g = (it.get("movie__genre") or "").strip()
                if g:
                    genres = [s.strip() for s in g.split(",") if s.strip()]
                out.append(
                    {
                        "imdb_id": it.get("movie__imdb_id") or "",
                        "title": it.get("movie__title") or "",
                        "genres": genres,
                    }
                )
            return out

        context: Dict[str, Any] = {
            "favorites": _norm_items(list(favorites)),
            "likes": _norm_items(list(likes)),
            "reviews": list(reviews_qs),
        }
        recos = gemini_generate_recommendations(
            user_id=user.id,
            context=context,
        )
        return Response(recos)


class GeminiHealthcheckView(APIView):
    """Lightweight Gemini connectivity check for authenticated users."""

    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request):
        info: Dict[str, Any] = gemini_healthcheck()
        return Response(info)
