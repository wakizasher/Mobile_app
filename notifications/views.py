from __future__ import annotations

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.throttling import ScopedRateThrottle
from drf_spectacular.utils import extend_schema, OpenApiTypes

from .models import Notification
from .serializers import (
    NotificationSerializer,
    NotificationGenerateSerializer,
)
from .services import (
    push_notify,
    gemini_generate_notification_message,
)


@extend_schema(summary="List notifications", responses=NotificationSerializer)
class NotificationListView(generics.ListAPIView):
    """List notifications for the authenticated user."""

    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)


class NotificationGenerateView(APIView):
    """Generate a personalized notification.

    POST body:
    - context: JSON for message generation (required)
    - device_token: optional FCM token to send the push
    - data: optional JSON payload to attach to the notification
    """

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    @extend_schema(
        summary="Generate notification via Gemini",
        request=NotificationGenerateSerializer,
        responses={201: OpenApiTypes.OBJECT},
    )
    def post(self, request):
        serializer = NotificationGenerateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        context = serializer.validated_data["context"]
        device_token = serializer.validated_data.get("device_token", "")
        data_payload = serializer.validated_data.get("data") or {}

        user_dict = {
            "id": request.user.id,
            "username": getattr(request.user, "username", ""),
        }
        msg = gemini_generate_notification_message(
            user=user_dict,
            context=context,
        )
        title = msg.get("title", "")
        body = msg.get("body", "")
        delivered = False
        if device_token:
            delivered = push_notify(
                device_token=device_token,
                title=title,
                body=body,
                data=data_payload,
            )

        notif = Notification.objects.create(
            user=request.user,
            title=title,
            body=body,
            data=data_payload,
            delivered=delivered,
        )
        return Response(
            {
                "notification": NotificationSerializer(notif).data,
                "generated": {"title": title, "body": body},
            },
            status=status.HTTP_201_CREATED,
        )
