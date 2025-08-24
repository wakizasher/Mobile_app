from __future__ import annotations

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom user model extending Django's AbstractUser.

    Adds optional profile fields used by the mobile app.
    """

    display_name = models.CharField(max_length=150, blank=True)
    avatar_url = models.URLField(blank=True)
    bio = models.TextField(blank=True)

    def __str__(self) -> str:  # pragma: no cover - readability
        return self.username or super().__str__()
