from __future__ import annotations

from typing import Any

from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import AnalyticsEvent
from .serializers import AnalyticsEventSerializer
from .authentication import N8NSharedSecretAuthentication


class IsAuthenticatedOrN8N(permissions.BasePermission):
    """
    Allow if the user is authenticated OR request is authenticated via
    n8n shared-secret authentication (request.auth == "n8n").
    """

    def has_permission(self, request, view) -> bool:  # type: ignore[override]
        if request.user and request.user.is_authenticated:
            return True
        return request.auth == "n8n"


class AnalyticsIngestView(APIView):
    """Ingest analytics events from the app or n8n.

    Auth: JWT or X-N8N-SECRET
    """

    authentication_classes = [
        N8NSharedSecretAuthentication,
        JWTAuthentication,
    ]
    permission_classes = [IsAuthenticatedOrN8N]

    def post(self, request):
        data: dict[str, Any] = request.data or {}
        event = (data.get("event") or "").strip()
        if not event:
            return Response(
                {"detail": "'event' is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        imdb_id = (data.get("imdb_id") or "").strip()
        source = (
            data.get("source")
            or ("n8n" if not request.user.is_authenticated else "app")
        )
        source = (source or "").strip()
        payload = data.get("payload") or data
        obj = AnalyticsEvent.objects.create(
            user=(
                request.user
                if getattr(request.user, "is_authenticated", False)
                else None
            ),
            event=event,
            imdb_id=imdb_id,
            source=source,
            payload=payload,
        )
        return Response(
            AnalyticsEventSerializer(obj).data,
            status=status.HTTP_201_CREATED,
        )


class AnalyticsListView(generics.ListAPIView):
    """
    List analytics events for the current user
    (optional filter by imdb_id).
    """

    serializer_class = AnalyticsEventSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = AnalyticsEvent.objects.filter(user=self.request.user)
        imdb_id = (self.request.query_params.get("imdb_id") or "").strip()
        if imdb_id:
            qs = qs.filter(imdb_id=imdb_id)
        return qs
