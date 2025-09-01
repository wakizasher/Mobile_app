from __future__ import annotations

import logging

from django.db.models import Q, Count
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
    FavoriteSimpleSerializer,
    FavoriteWithUserSerializer,
    LikeToggleSerializer,
    LikeSimpleSerializer,
    LikeWithUserSerializer,
    ReviewSerializer,
    ReviewActivitySerializer,
    ShareSerializer,
    SocialStatsSerializer,
    SocialPostGenerateSerializer,
    TrendingUsersInputSerializer,
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
from users.serializers import UserSerializer

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

    def delete(self, request, *args, **kwargs):
        """Allow the sender to cancel/remove their friend request.

        Only `from_user` can delete. Recipients cannot delete the request here.
        """
        instance: FriendRequest = self.get_object()
        if instance.from_user != request.user:
            raise PermissionDenied("Only the sender can delete this request.")
        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


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
        user = self.request.user
        visible_statuses = [
            MovieNightParticipant.STATUS_INVITED,
            MovieNightParticipant.STATUS_ACCEPTED,
            MovieNightParticipant.STATUS_MAYBE,
        ]
        return (
            MovieNight.objects.filter(
                Q(organizer=user)
                | Q(
                    participants__user=user,
                    participants__status__in=visible_statuses,
                )
            )
            .select_related("organizer")
            .prefetch_related("participants__user")
            .order_by("-created_at")
            .distinct()
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
    def get_queryset(self):
        user = self.request.user
        visible_statuses = [
            MovieNightParticipant.STATUS_INVITED,
            MovieNightParticipant.STATUS_ACCEPTED,
            MovieNightParticipant.STATUS_MAYBE,
        ]
        return (
            MovieNight.objects.filter(
                Q(organizer=user)
                | Q(
                    participants__user=user,
                    participants__status__in=visible_statuses,
                )
            )
            .select_related("organizer")
            .prefetch_related(
                "participants__user",
                # Optimize votes payload for detail view (serializer may conditionally include)
                "votes__user",
                "votes__movie",
            )
            .distinct()
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

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        obj: MovieNight | None = None
        try:
            obj = self.get_object()
        except Exception:
            obj = None
        include_votes = False
        if obj is not None:
            is_organizer = obj.organizer_id == self.request.user.id
            is_accepted = MovieNightParticipant.objects.filter(
                movie_night=obj,
                user=self.request.user,
                status=MovieNightParticipant.STATUS_ACCEPTED,
            ).exists()
            include_votes = bool(is_organizer or is_accepted)
        ctx.update({"request": self.request, "include_votes": include_votes})
        return ctx


class MovieNightParticipantView(APIView):
    """Join/request or leave/cancel participation for the current user.

    POST behavior:
    - If user is invited (invited/maybe), accept the invite (status -> accepted) with capacity check.
    - If user already accepted, no-op.
    - If no participation exists, create a join request (status=requested).
    - If participation exists as requested, return current object (idempotent).

    DELETE behavior:
    - If status=requested, cancel the request (delete row).
    - Otherwise, remove participation (leave the movie night), except organizer cannot leave.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int):
        movie_night = MovieNight.objects.filter(pk=pk).first()
        if not movie_night:
            return Response(
                {"detail": "Movie night not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        # Organizer is already added on create; just return current participation
        if movie_night.organizer_id == request.user.id:
            participant = MovieNightParticipant.objects.filter(
                movie_night=movie_night, user=request.user
            ).first()
            if not participant:
                participant = MovieNightParticipant.objects.create(
                    movie_night=movie_night,
                    user=request.user,
                    status=MovieNightParticipant.STATUS_ACCEPTED,
                )
            return Response(MovieNightParticipantSerializer(participant).data)

        participant = MovieNightParticipant.objects.filter(
            movie_night=movie_night, user=request.user
        ).first()

        # Accept invite if invited/maybe
        if participant and participant.status in (
            MovieNightParticipant.STATUS_INVITED,
            MovieNightParticipant.STATUS_MAYBE,
        ):
            # capacity check applies when moving to accepted
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
            participant.status = MovieNightParticipant.STATUS_ACCEPTED
            participant.save(update_fields=["status"])
            return Response(MovieNightParticipantSerializer(participant).data)

        # Already accepted -> no-op
        if participant and participant.status == MovieNightParticipant.STATUS_ACCEPTED:
            return Response(MovieNightParticipantSerializer(participant).data)

        # Already requested -> idempotent
        if participant and participant.status == MovieNightParticipant.STATUS_REQUESTED:
            return Response(MovieNightParticipantSerializer(participant).data)

        # Otherwise, create a join request
        participant = MovieNightParticipant.objects.create(
            movie_night=movie_night,
            user=request.user,
            status=MovieNightParticipant.STATUS_REQUESTED,
        )
        return Response(MovieNightParticipantSerializer(participant).data, status=status.HTTP_201_CREATED)

    def delete(self, request, pk: int):
        movie_night = MovieNight.objects.filter(pk=pk).first()
        if not movie_night:
            return Response({"detail": "Movie night not found."}, status=status.HTTP_404_NOT_FOUND)
        participant = MovieNightParticipant.objects.filter(
            movie_night=movie_night, user=request.user
        ).first()
        if not participant:
            return Response(status=status.HTTP_204_NO_CONTENT)
        # Organizer cannot leave their own movie night
        if movie_night.organizer_id == request.user.id:
            raise PermissionDenied("Organizer cannot leave their own movie night.")
        participant.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MovieNightInviteView(APIView):
    """Organizer invites a user to a movie night (creates or updates participation).

    Body: {"user_id": <int>}
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int):
        movie_night = MovieNight.objects.filter(pk=pk).first()
        if not movie_night:
            return Response(
                {"detail": "Movie night not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if movie_night.organizer_id != request.user.id:
            raise PermissionDenied("Only the organizer can invite participants.")

        try:
            user_id = int(request.data.get("user_id"))
        except (TypeError, ValueError):
            return Response(
                {"detail": "user_id is required and must be an integer."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Organizer cannot invite themselves (they are already accepted)
        if user_id == request.user.id:
            participant = MovieNightParticipant.objects.filter(
                movie_night=movie_night, user=request.user
            ).first()
            if not participant:
                participant = MovieNightParticipant.objects.create(
                    movie_night=movie_night,
                    user=request.user,
                    status=MovieNightParticipant.STATUS_ACCEPTED,
                )
            return Response(MovieNightParticipantSerializer(participant).data)

        participant, created = MovieNightParticipant.objects.get_or_create(
            movie_night=movie_night,
            user_id=user_id,
            defaults={"status": MovieNightParticipant.STATUS_INVITED},
        )
        if not created and participant.status == MovieNightParticipant.STATUS_REQUESTED:
            # Upgrade a join request to an invite
            participant.status = MovieNightParticipant.STATUS_INVITED
            participant.save(update_fields=["status"])
        return Response(MovieNightParticipantSerializer(participant).data)


class MovieNightVoteView(generics.CreateAPIView):
    """Vote for a movie for a given movie night."""

    serializer_class = MovieNightVoteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        movie_night = MovieNight.objects.filter(pk=self.kwargs.get("pk")).first()
        if not movie_night:
            raise PermissionDenied("Movie night not found.")
        # Only organizer or accepted participants can vote
        is_organizer = movie_night.organizer_id == self.request.user.id
        is_accepted = MovieNightParticipant.objects.filter(
            movie_night=movie_night,
            user=self.request.user,
            status=MovieNightParticipant.STATUS_ACCEPTED,
        ).exists()
        if not (is_organizer or is_accepted):
            raise PermissionDenied("You are not allowed to vote in this movie night.")
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


# ---- New Social Endpoints ----


class RecentFavoritesView(generics.ListAPIView):
    """List recent favorites across all users within the last X minutes.

    Query params:
    - minutes: integer window (default 60)
    """

    serializer_class = FavoriteWithUserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        try:
            minutes = int(self.request.query_params.get("minutes", 60))
        except (TypeError, ValueError):
            minutes = 60
        cutoff = timezone.now() - timedelta(minutes=max(1, minutes))
        return (
            Favorite.objects.filter(created_at__gte=cutoff)
            .select_related("user", "movie")
            .order_by("-created_at")
        )


class UsersInterestedInTrendingView(APIView):
    """Return users who engaged with the provided trending movies.

    POST body: see `TrendingUsersInputSerializer`.
    Engagement includes favorites, likes, or reviews for the movies.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        ser = TrendingUsersInputSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        imdb_ids = ser.get_imdb_ids()
        if not imdb_ids:
            return Response({"users": [], "count": 0})

        User = get_user_model()
        q = (
            Q(favorites__movie__imdb_id__in=imdb_ids)
            | Q(likes__movie__imdb_id__in=imdb_ids)
            | Q(reviews__movie__imdb_id__in=imdb_ids)
        )

        users_qs = (
            User.objects.filter(q)
            .annotate(
                favs=Count(
                    "favorites",
                    filter=Q(favorites__movie__imdb_id__in=imdb_ids),
                    distinct=True,
                ),
                likes=Count(
                    "likes",
                    filter=Q(likes__movie__imdb_id__in=imdb_ids),
                    distinct=True,
                ),
                revs=Count(
                    "reviews",
                    filter=Q(reviews__movie__imdb_id__in=imdb_ids),
                    distinct=True,
                ),
            )
            .order_by("-favs", "-likes", "-revs")
            .distinct()
        )

        data = UserSerializer(users_qs, many=True).data
        return Response({"users": data, "count": len(data)})


class ActiveUsersView(generics.ListAPIView):
    """List users active in the last 7 days (favorites, likes, reviews)."""

    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        cutoff = timezone.now() - timedelta(days=7)
        User = get_user_model()
        return (
            User.objects.filter(
                Q(favorites__created_at__gte=cutoff)
                | Q(likes__created_at__gte=cutoff)
                | Q(reviews__created_at__gte=cutoff)
            )
            .annotate(
                favs=Count(
                    "favorites",
                    filter=Q(favorites__created_at__gte=cutoff),
                    distinct=True,
                ),
                likes=Count(
                    "likes",
                    filter=Q(likes__created_at__gte=cutoff),
                    distinct=True,
                ),
                revs=Count(
                    "reviews",
                    filter=Q(reviews__created_at__gte=cutoff),
                    distinct=True,
                ),
            )
            .order_by("-favs", "-likes", "-revs")
            .distinct()
        )


class UserMovieHistoryView(APIView):
    """Summarize a user's movie history: favorites, likes, and reviews.

    Path param: user_id
    Query param: limit (default 20)
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, user_id: int):
        try:
            limit = int(request.query_params.get("limit", 20))
        except (TypeError, ValueError):
            limit = 20
        limit = max(1, min(limit, 100))

        fav_qs = (
            Favorite.objects.filter(user_id=user_id)
            .select_related("movie")
            .order_by("-created_at")[:limit]
        )
        like_qs = (
            Like.objects.filter(user_id=user_id)
            .select_related("movie")
            .order_by("-created_at")[:limit]
        )
        rev_qs = (
            Review.objects.filter(user_id=user_id)
            .select_related("movie", "user")
            .order_by("-created_at")[:limit]
        )

        payload = {
            "user_id": user_id,
            "counts": {
                "favorites": Favorite.objects.filter(user_id=user_id).count(),
                "likes": Like.objects.filter(user_id=user_id).count(),
                "reviews": Review.objects.filter(user_id=user_id).count(),
            },
            "recent": {
                "favorites": FavoriteSimpleSerializer(fav_qs, many=True).data,
                "likes": LikeSimpleSerializer(like_qs, many=True).data,
                "reviews": ReviewActivitySerializer(rev_qs, many=True).data,
            },
        }
        return Response(payload)


class FriendsActivityView(APIView):
    """Return friends' recent activity (favorites, likes, reviews).

    Path param: user_id
    Query params:
    - minutes: window size (default 1440)
    - limit: max items to return (default 50)
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, user_id: int):
        try:
            minutes = int(request.query_params.get("minutes", 1440))
        except (TypeError, ValueError):
            minutes = 1440
        try:
            limit = int(request.query_params.get("limit", 50))
        except (TypeError, ValueError):
            limit = 50
        limit = max(1, min(limit, 200))

        cutoff = timezone.now() - timedelta(minutes=max(1, minutes))
        friend_ids = list(
            Friendship.objects.filter(user_id=user_id).values_list(
                "friend_id", flat=True
            )
        )
        if not friend_ids:
            return Response({"activities": [], "count": 0})

        favs = list(
            Favorite.objects.filter(
                user_id__in=friend_ids, created_at__gte=cutoff
            )
            .select_related("user", "movie")
            .order_by("-created_at")[: limit * 2]
        )
        likes = list(
            Like.objects.filter(user_id__in=friend_ids, created_at__gte=cutoff)
            .select_related("user", "movie")
            .order_by("-created_at")[: limit * 2]
        )
        revs = list(
            Review.objects.filter(user_id__in=friend_ids, created_at__gte=cutoff)
            .select_related("user", "movie")
            .order_by("-created_at")[: limit * 2]
        )

        activities = []
        for f in favs:
            activities.append(
                {
                    "type": "favorite",
                    "created_at": f.created_at,
                    "data": FavoriteWithUserSerializer(f).data,
                }
            )
        for like_obj in likes:
            activities.append(
                {
                    "type": "like",
                    "created_at": like_obj.created_at,
                    "data": LikeWithUserSerializer(like_obj).data,
                }
            )
        for r in revs:
            activities.append(
                {
                    "type": "review",
                    "created_at": r.created_at,
                    "data": ReviewActivitySerializer(r).data,
                }
            )

        # Sort by created_at desc and trim
        activities.sort(key=lambda x: x.get("created_at"), reverse=True)
        activities = activities[:limit]

        # Convert datetime to isoformat for JSON
        for item in activities:
            dt = item.get("created_at")
            item["created_at"] = dt.isoformat() if dt else None

        return Response({"activities": activities, "count": len(activities)})
