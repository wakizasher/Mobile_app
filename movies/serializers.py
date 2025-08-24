from __future__ import annotations

from rest_framework import serializers
from .models import Movie


class MovieSerializer(serializers.ModelSerializer):
    """Serializer for `Movie` model."""

    class Meta:
        model = Movie
        fields = [
            "id",
            "imdb_id",
            "title",
            "year",
            "poster",
            "plot",
            "genre",
            "data",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "data"]
