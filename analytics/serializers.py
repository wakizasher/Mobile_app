from __future__ import annotations

from rest_framework import serializers
from .models import AnalyticsEvent


class AnalyticsEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalyticsEvent
        fields = [
            "id",
            "user",
            "event",
            "imdb_id",
            "source",
            "payload",
            "created_at",
        ]
        read_only_fields = ["id", "user", "created_at"]
