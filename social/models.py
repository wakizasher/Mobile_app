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


class Friendship(models.Model):
    """Represents a friendship between two users.

    Stored as a directed edge (user -> friend). For an undirected friendship,
    two rows will exist: (A -> B) and (B -> A).
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friendships",
    )
    friend = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friend_of",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "friend")
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} -> {self.friend}"


class FriendRequest(models.Model):
    """A friend request from one user to another."""

    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_DECLINED = "declined"
    STATUS_CHOICES = (
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_DECLINED, "Declined"),
    )

    from_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sent_friend_requests",
    )
    to_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="received_friend_requests",
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("from_user", "to_user")
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.from_user} -> {self.to_user} ({self.status})"


class MovieNight(models.Model):
    """A planned movie night organized by a user."""

    STATUS_PLANNING = "planning"
    STATUS_CONFIRMED = "confirmed"
    STATUS_CANCELLED = "cancelled"
    STATUS_COMPLETED = "completed"
    STATUS_CHOICES = (
        (STATUS_PLANNING, "Planning"),
        (STATUS_CONFIRMED, "Confirmed"),
        (STATUS_CANCELLED, "Cancelled"),
        (STATUS_COMPLETED, "Completed"),
    )

    organizer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="organized_movie_nights",
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    scheduled_date = models.DateTimeField()
    location = models.CharField(max_length=200, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PLANNING)
    max_participants = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.title} ({self.scheduled_date:%Y-%m-%d %H:%M})"


class MovieNightParticipant(models.Model):
    """A participant's status for a given movie night."""

    STATUS_INVITED = "invited"
    STATUS_ACCEPTED = "accepted"
    STATUS_DECLINED = "declined"
    STATUS_MAYBE = "maybe"
    STATUS_CHOICES = (
        (STATUS_INVITED, "Invited"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_DECLINED, "Declined"),
        (STATUS_MAYBE, "Maybe"),
    )

    movie_night = models.ForeignKey(
        MovieNight,
        on_delete=models.CASCADE,
        related_name="participants",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="movie_night_participations",
    )
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_INVITED)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("movie_night", "user")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} @ {self.movie_night} ({self.status})"


class MovieNightVote(models.Model):
    """A user's vote for a movie for a specific movie night."""

    movie_night = models.ForeignKey(
        MovieNight,
        on_delete=models.CASCADE,
        related_name="votes",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="movie_night_votes",
    )
    movie = models.ForeignKey(
        Movie,
        on_delete=models.CASCADE,
        related_name="movie_night_votes",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("movie_night", "user", "movie")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} voted {self.movie} for {self.movie_night}"


class FriendSuggestion(models.Model):
    """A suggested friend for a user, produced by the recommendation pipeline.

    Stores a recommendation record with optional similarity score and shared genres
    context so the client can present relevant details to the user.
    """

    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_DISMISSED = "dismissed"
    STATUS_CHOICES = (
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_DISMISSED, "Dismissed"),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="friend_suggestions",
    )
    suggested_user_id = models.IntegerField()
    similarity_score = models.FloatField(null=True, blank=True)
    shared_genres = models.JSONField(default=list, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "suggested_user_id")
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user} -> {self.suggested_user_id} ({self.status})"
