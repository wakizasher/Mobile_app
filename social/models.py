from __future__ import annotations

from django.conf import settings
from django.db import models

from movies.models import Movie


class Favorite(models.Model):
    """A movie favorited by a user."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorites")
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name="favorites")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "movie")


class Like(models.Model):
    """A user like for a movie."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="likes")
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name="likes")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "movie")


class Review(models.Model):
    """A user review for a movie with sentiment analysis.

    Advanced sentiment data fields:
    - sentiment_confidence: Optional confidence score (0..1)
    - emotions: JSON mapping of emotions to scores
    - sentiment_breakdown: JSON with pros/cons/themes
    """

    SENTIMENT_CHOICES = (
        ("positive", "Positive"),
        ("neutral", "Neutral"),
        ("negative", "Negative"),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews")
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name="reviews")
    content = models.TextField()
    rating = models.PositiveSmallIntegerField(null=True, blank=True)
    sentiment = models.CharField(max_length=10, choices=SENTIMENT_CHOICES, default="neutral")
    sentiment_confidence = models.FloatField(null=True, blank=True)
    emotions = models.JSONField(default=dict, blank=True)
    sentiment_breakdown = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)


class Share(models.Model):
    """Record of a user sharing a movie."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="shares")
    movie = models.ForeignKey(Movie, on_delete=models.CASCADE, related_name="shares")
    platform = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
