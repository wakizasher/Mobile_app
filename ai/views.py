from __future__ import annotations

from typing import Any, Dict
import logging
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from social.models import Favorite, Like, Review
from notifications.services import gemini_generate_recommendations
from notifications.services import gemini_healthcheck
from movies.models import Movie
from movies.services import get_movie_details, map_omdb_to_fields


logger = logging.getLogger(__name__)


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
        # Best-effort upsert of recommended movies by imdb_id to avoid
        # downstream errors when movie records are missing in DB.
        try:
            if isinstance(recos, list):
                for item in recos:
                    try:
                        imdb_id = (item.get("imdb_id") or "").strip()
                        if not imdb_id:
                            continue
                        exists = Movie.objects.filter(imdb_id=imdb_id).exists()
                        if not exists:
                            payload = get_movie_details(imdb_id)
                            if payload and payload.get("Response") != "False":
                                fields = map_omdb_to_fields(payload)
                                Movie.objects.create(**fields)
                                logger.debug(
                                    "reco_upsert: created id=%s "
                                    "title=%s",
                                    imdb_id,
                                    fields.get("title"),
                                )
                            else:
                                logger.debug(
                                    "reco_upsert: OMDb fail id=%s",
                                    imdb_id,
                                )
                    except Exception:
                        imdb_val = None
                        if isinstance(item, dict):
                            imdb_val = item.get("imdb_id")
                        logger.exception(
                            "reco_upsert: failed imdb_id=%s",
                            imdb_val,
                        )
        except Exception:
            # Never fail the endpoint due to upsert attempts
            logger.exception("reco_upsert: outer failure")
        return Response(recos)


class GeminiHealthcheckView(APIView):
    """Lightweight Gemini connectivity check for authenticated users."""

    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    def get(self, request):
        info: Dict[str, Any] = gemini_healthcheck()
        return Response(info)
