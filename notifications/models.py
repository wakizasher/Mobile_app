from __future__ import annotations

from django.conf import settings
from django.db import models


class Notification(models.Model):
    """Push notification record for audit and history."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications")
    title = models.CharField(max_length=200)
    body = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    delivered = models.BooleanField(default=False)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-sent_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.title} -> {self.user}"
