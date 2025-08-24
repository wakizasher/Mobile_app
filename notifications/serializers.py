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
