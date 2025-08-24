from __future__ import annotations

from django.apps import AppConfig


class AiConfig(AppConfig):
    """App config for AI-powered endpoints and services."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "ai"
