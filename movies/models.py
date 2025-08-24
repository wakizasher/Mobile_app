from __future__ import annotations

from django.db import models


class Movie(models.Model):
    """Movie entity cached from OMDb API results."""

    imdb_id = models.CharField(max_length=20, unique=True, db_index=True)
    title = models.CharField(max_length=300)
    year = models.CharField(max_length=10, blank=True)
    poster = models.URLField(blank=True)
    plot = models.TextField(blank=True)
    genre = models.CharField(max_length=200, blank=True)
    data = models.JSONField(default=dict, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.title} ({self.imdb_id})"
