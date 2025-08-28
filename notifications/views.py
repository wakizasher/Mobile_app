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
    NotificationBulkCreateSerializer,
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


class NotificationBulkCreateView(APIView):
    """Bulk create notifications for multiple users using Gemini.

    Request body:
    - user_ids: array[int] (required)
    - context: JSON (required)
    - template_type: string (optional)
    - data: JSON (optional)
    """

    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "llm"

    @extend_schema(
        summary="Bulk create notifications via Gemini",
        request=NotificationBulkCreateSerializer,
        responses={201: OpenApiTypes.OBJECT},
    )
    def post(self, request):
        serializer = NotificationBulkCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user_ids = serializer.validated_data["user_ids"]
        context = serializer.validated_data["context"]
        template_type = serializer.validated_data.get("template_type", "")
        extra_data = serializer.validated_data.get("data") or {}

        created = []
        for uid in user_ids:
            user_dict = {"id": uid}
            msg = gemini_generate_notification_message(
                user=user_dict,
                context=context,
            )
            title = msg.get("title", "")
            body = msg.get("body", "")
            data_payload = dict(extra_data)
            if template_type:
                data_payload["template_type"] = template_type

            # Create row. We do not push here; that should be handled
            # separately.
            notif = Notification.objects.create(
                user_id=uid,
                title=title,
                body=body,
                data=data_payload,
                delivered=False,
            )
            created.append(notif)

        return Response(
            {
                "count": len(created),
                "notifications": NotificationSerializer(
                    created, many=True
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )
