from __future__ import annotations

from django.conf import settings
from django.db import models


class AnalyticsEvent(models.Model):
    """Generic analytics event captured from app or n8n workflows."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="analytics_events",
    )
    event = models.CharField(max_length=64)
    imdb_id = models.CharField(max_length=16, blank=True, default="")
    # e.g., flutter, n8n
    source = models.CharField(max_length=32, blank=True, default="")
    payload = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["event"]),
            models.Index(fields=["imdb_id"]),
            models.Index(fields=["created_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self) -> str:  # pragma: no cover
        who = getattr(self.user, "id", None)
        return (
            f"AnalyticsEvent(event={self.event}, user={who}, "
            f"imdb_id={self.imdb_id})"
        )
