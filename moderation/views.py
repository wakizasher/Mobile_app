from __future__ import annotations

from typing import Any

from django.conf import settings
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ModerationQueue
from .serializers import ModerationQueueSerializer


class IsAuthenticatedOrN8N(permissions.BasePermission):
    def has_permission(self, request, view) -> bool:  # type: ignore[override]
        if request.user and request.user.is_authenticated:
            return True
        secret = (
            request.headers.get("X-N8N-SECRET")
            or request.META.get("HTTP_X_N8N_SECRET")
        )
        expected = getattr(settings, "N8N_SHARED_SECRET", "")
        return bool(secret) and secret == expected


class ModerationIngestView(APIView):
    """Create a pending moderation item from app or n8n webhook."""

    permission_classes = [IsAuthenticatedOrN8N]

    def post(self, request):
        data: dict[str, Any] = request.data or {}
        content_type = (data.get("content_type") or "").strip()
        if not content_type:
            return Response(
                {"detail": "'content_type' is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        content_id = data.get("content_id")
        reason = (data.get("reason") or "").strip()
        metadata = data.get("metadata") or data
        obj = ModerationQueue.objects.create(
            user=(
                request.user
                if getattr(request.user, "is_authenticated", False)
                else None
            ),
            content_type=content_type,
            content_id=content_id if isinstance(content_id, int) else None,
            reason=reason,
            metadata=metadata,
        )
        return Response(
            ModerationQueueSerializer(obj).data,
            status=status.HTTP_201_CREATED,
        )


class ModerationQueueListView(generics.ListAPIView):
    """List moderation queue items (admin-only).

    Optional query param: ``status`` to filter by status.
    """
    serializer_class = ModerationQueueSerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        qs = ModerationQueue.objects.all()
        status_param = (self.request.query_params.get("status") or "").strip()
        if status_param:
            qs = qs.filter(status=status_param)
        return qs


class ModerationQueueUpdateView(generics.UpdateAPIView):
    """Update a moderation queue item (admin-only).

    If status becomes approved/rejected, set ``resolved_by`` to the
    current user.
    """
    serializer_class = ModerationQueueSerializer
    permission_classes = [permissions.IsAdminUser]
    queryset = ModerationQueue.objects.all()

    def perform_update(self, serializer):
        instance = serializer.save()
        if instance.status in (
            ModerationQueue.STATUS_APPROVED,
            ModerationQueue.STATUS_REJECTED,
        ):
            instance.resolved_by = self.request.user
            instance.save(update_fields=["resolved_by"])  # type: ignore
