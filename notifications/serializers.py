from __future__ import annotations

from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "title", "body", "data", "delivered", "sent_at"]
        read_only_fields = ["id", "delivered", "sent_at"]


class NotificationGenerateSerializer(serializers.Serializer):
    """Input for generating a personalized notification message via Gemini."""

    context = serializers.JSONField()
    device_token = serializers.CharField(required=False, allow_blank=True)
    data = serializers.JSONField(required=False)


class NotificationBulkCreateSerializer(serializers.Serializer):
    """Input schema for bulk creating notifications.

    Fields:
    - user_ids: list of target user IDs (required)
    - context: JSON context for Gemini message generation (required)
    - template_type: optional hint for client-side rendering/audit
    - data: optional custom data payload to attach to each notification
    """

    user_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1), allow_empty=False
    )
    context = serializers.JSONField()
    template_type = serializers.CharField(required=False, allow_blank=True)
    data = serializers.JSONField(required=False)
