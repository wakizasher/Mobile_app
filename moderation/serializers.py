from __future__ import annotations

from rest_framework import serializers
from .models import ModerationQueue


class ModerationQueueSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModerationQueue
        fields = [
            "id",
            "content_type",
            "content_id",
            "user",
            "reason",
            "status",
            "metadata",
            "resolved_by",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "resolved_by"]
