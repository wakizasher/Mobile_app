from __future__ import annotations

from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed


class N8NSharedSecretAuthentication(BaseAuthentication):
    """
    Authenticate requests coming from n8n via X-N8N-SECRET header.

    If the header is present and matches settings.N8N_SHARED_SECRET,
    we authenticate the request and set request.auth == "n8n" while
    leaving request.user as AnonymousUser (so business logic can decide
    whether to associate a user or not).
    """

    def authenticate(self, request):
        secret = (
            request.headers.get("X-N8N-SECRET")
            or request.META.get("HTTP_X_N8N_SECRET")
        )
        if not secret:
            return None  # No attempt
        expected = getattr(settings, "N8N_SHARED_SECRET", "")
        if not expected:
            raise AuthenticationFailed("N8N shared secret not configured")
        if secret != expected:
            raise AuthenticationFailed("Invalid n8n secret")
        return (AnonymousUser(), "n8n")
