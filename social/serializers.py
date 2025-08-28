from __future__ import annotations

from typing import Any

from django.db import transaction
from rest_framework import serializers

from movies.models import Movie
from movies.serializers import MovieSerializer
from movies.services import get_movie_details, map_omdb_to_fields
from .models import (
    Favorite,
    Like,
    Review,
    Share,
    Friendship,
    FriendRequest,
    MovieNight,
    MovieNightParticipant,
    MovieNightVote,
    FriendSuggestion,
)
from users.serializers import UserSerializer


class FavoriteSerializer(serializers.ModelSerializer):
    movie = MovieSerializer(read_only=True)
    imdb_id = serializers.CharField(write_only=True)

    class Meta:
        model = Favorite
        fields = ["id", "movie", "imdb_id", "created_at"]
        read_only_fields = ["id", "created_at", "movie"]

    def create(self, validated_data: dict[str, Any]):
        user = self.context["request"].user
        imdb_id = validated_data.pop("imdb_id")
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if not movie:
            payload = get_movie_details(imdb_id)
            fields = map_omdb_to_fields(payload)
            movie = Movie.objects.create(**fields)
        obj, _ = Favorite.objects.get_or_create(user=user, movie=movie)
        return obj


class FavoriteSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Favorite
        fields = ["id", "movie_id", "created_at"]


class LikeToggleSerializer(serializers.Serializer):
    imdb_id = serializers.CharField()

    def save(self, **kwargs):
        user = self.context["request"].user
        imdb_id = self.validated_data["imdb_id"]
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if not movie:
            payload = get_movie_details(imdb_id)
            fields = map_omdb_to_fields(payload)
            movie = Movie.objects.create(**fields)
        like, created = Like.objects.get_or_create(user=user, movie=movie)
        if not created:
            like.delete()
            return {"liked": False}
        return {"liked": True}


class ReviewSerializer(serializers.ModelSerializer):
    imdb_id = serializers.CharField(write_only=True)

    class Meta:
        model = Review
        fields = [
            "id",
            "imdb_id",
            "content",
            "rating",
            "sentiment",
            "sentiment_confidence",
            "emotions",
            "sentiment_breakdown",
            "created_at",
        ]
        read_only_fields = ["id", "sentiment", "sentiment_confidence", "emotions", "sentiment_breakdown", "created_at"]

    def create(self, validated_data):
        from notifications.services import gemini_analyze_sentiment, gemini_advanced_sentiment

        user = self.context["request"].user
        imdb_id = validated_data.pop("imdb_id")
        content = validated_data.get("content", "")
        with transaction.atomic():
            movie = Movie.objects.filter(imdb_id=imdb_id).first()
            if not movie:
                payload = get_movie_details(imdb_id)
                fields = map_omdb_to_fields(payload)
                movie = Movie.objects.create(**fields)
            adv = gemini_advanced_sentiment(content)
            sentiment = (adv.get("overall") if isinstance(adv, dict) else None) or gemini_analyze_sentiment(content) or "neutral"
            review = Review.objects.create(
                user=user,
                movie=movie,
                sentiment=sentiment,
                sentiment_confidence=(adv.get("confidence") if isinstance(adv, dict) else None),
                emotions=(adv.get("emotions") if isinstance(adv, dict) else {}),
                sentiment_breakdown=(adv.get("breakdown") if isinstance(adv, dict) else {}),
                **validated_data,
            )
        return review


class ShareSerializer(serializers.ModelSerializer):
    imdb_id = serializers.CharField(write_only=True)

    class Meta:
        model = Share
        fields = ["id", "imdb_id", "platform", "created_at"]
        read_only_fields = ["id", "created_at"]

    def create(self, validated_data):
        user = self.context["request"].user
        imdb_id = validated_data.pop("imdb_id")
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if not movie:
            payload = get_movie_details(imdb_id)
            fields = map_omdb_to_fields(payload)
            movie = Movie.objects.create(**fields)
        return Share.objects.create(user=user, movie=movie, **validated_data)


class SocialStatsSerializer(serializers.Serializer):
    likes = serializers.IntegerField()
    favorites = serializers.IntegerField()
    reviews = serializers.IntegerField()


class SocialPostGenerateSerializer(serializers.Serializer):
    """Input serializer for generating social posts for a movie."""

    imdb_id = serializers.CharField()
    preferences = serializers.JSONField(required=False)


# --- Friend System Serializers ---


class FriendshipSerializer(serializers.ModelSerializer):
    """Read-only serializer for friendships with user details."""

    user = UserSerializer(read_only=True)
    friend = UserSerializer(read_only=True)

    class Meta:
        model = Friendship
        fields = ["id", "user", "friend", "created_at"]
        read_only_fields = ["id", "user", "friend", "created_at"]


class FriendRequestSerializer(serializers.ModelSerializer):
    """Serializer for friend requests with detailed users.

    Write with `to_user_id`; `from_user` is set from the request user.
    """

    from_user = UserSerializer(read_only=True)
    to_user = UserSerializer(read_only=True)
    to_user_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = FriendRequest
        fields = [
            "id",
            "from_user",
            "to_user",
            "to_user_id",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "from_user", "to_user", "status", "created_at", "updated_at"]

    def create(self, validated_data: dict[str, Any]):
        from django.contrib.auth import get_user_model

        request = self.context.get("request")
        to_user_id = validated_data.pop("to_user_id")
        User = get_user_model()
        to_user = User.objects.filter(id=to_user_id).first()
        if not to_user:
            raise serializers.ValidationError({"to_user_id": "User not found."})
        if to_user == request.user:
            raise serializers.ValidationError({"to_user_id": "Cannot send a friend request to yourself."})
        obj, created = FriendRequest.objects.get_or_create(
            from_user=request.user,
            to_user=to_user,
            defaults={"status": FriendRequest.STATUS_PENDING},
        )
        if not created:
            # existing request; return as is to keep idempotency
            return obj
        return obj


# --- Movie Night Serializers ---


class MovieNightParticipantSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = MovieNightParticipant
        fields = ["id", "user", "status", "joined_at"]
        read_only_fields = ["id", "user", "joined_at"]


class MovieNightVoteSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    movie = MovieSerializer(read_only=True)
    movie_imdb_id = serializers.CharField(write_only=True)

    class Meta:
        model = MovieNightVote
        fields = ["id", "movie_imdb_id", "movie", "user", "created_at"]
        read_only_fields = ["id", "movie", "user", "created_at"]

    def create(self, validated_data: dict[str, Any]):
        request = self.context["request"]
        movie_night: MovieNight = self.context["movie_night"]
        imdb_id = validated_data.pop("movie_imdb_id")
        movie = Movie.objects.filter(imdb_id=imdb_id).first()
        if not movie:
            payload = get_movie_details(imdb_id)
            fields = map_omdb_to_fields(payload)
            movie = Movie.objects.create(**fields)
        vote, _ = MovieNightVote.objects.get_or_create(
            movie_night=movie_night,
            user=request.user,
            movie=movie,
        )
        return vote


class MovieNightSerializer(serializers.ModelSerializer):
    organizer = UserSerializer(read_only=True)
    participants = MovieNightParticipantSerializer(many=True, read_only=True)

    class Meta:
        model = MovieNight
        fields = [
            "id",
            "organizer",
            "title",
            "description",
            "scheduled_date",
            "location",
            "status",
            "max_participants",
            "participants",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "organizer", "status", "participants", "created_at", "updated_at"]

    def create(self, validated_data: dict[str, Any]):
        request = self.context["request"]
        mn = MovieNight.objects.create(organizer=request.user, **validated_data)
        # auto-add organizer as accepted participant
        MovieNightParticipant.objects.get_or_create(
            movie_night=mn,
            user=request.user,
            defaults={"status": MovieNightParticipant.STATUS_ACCEPTED},
        )
        return mn


class FriendSuggestionSerializer(serializers.ModelSerializer):
    """Serializer for friend suggestions records."""

    class Meta:
        model = FriendSuggestion
        fields = [
            "id",
            "user",
            "suggested_user_id",
            "similarity_score",
            "shared_genres",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "created_at", "user"]
