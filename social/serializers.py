from __future__ import annotations

from typing import Any

from django.db import transaction
from rest_framework import serializers

from movies.models import Movie
from movies.serializers import MovieSerializer
from movies.services import get_movie_details, map_omdb_to_fields
from .models import Favorite, Like, Review, Share


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
