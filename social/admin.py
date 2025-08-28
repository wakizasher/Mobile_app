from django.contrib import admin
from .models import (
    Favorite,
    Like,
    Review,
    Share,
    Friendship,
    FriendRequest,
    MovieNight,
    MovieNightParticipant,
    MovieNightVote,
)


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "movie", "created_at")
    search_fields = ("user__username", "movie__title", "movie__imdb_id")


@admin.register(Like)
class LikeAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "movie", "created_at")
    search_fields = ("user__username", "movie__title", "movie__imdb_id")


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "movie",
        "rating",
        "sentiment",
        "created_at",
    )
    search_fields = ("user__username", "movie__title", "movie__imdb_id")


@admin.register(Share)
class ShareAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "movie", "platform", "created_at")
    search_fields = (
        "user__username",
        "movie__title",
        "movie__imdb_id",
        "platform",
    )


@admin.register(Friendship)
class FriendshipAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "friend", "created_at")
    search_fields = ("user__username", "friend__username")


@admin.register(FriendRequest)
class FriendRequestAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "from_user",
        "to_user",
        "status",
        "created_at",
        "updated_at",
    )
    search_fields = ("from_user__username", "to_user__username", "status")


@admin.register(MovieNight)
class MovieNightAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "title",
        "organizer",
        "scheduled_date",
        "status",
        "max_participants",
        "created_at",
    )
    search_fields = (
        "title",
        "organizer__username",
        "status",
        "location",
    )


@admin.register(MovieNightParticipant)
class MovieNightParticipantAdmin(admin.ModelAdmin):
    list_display = ("id", "movie_night", "user", "status", "joined_at")
    search_fields = ("movie_night__title", "user__username", "status")


@admin.register(MovieNightVote)
class MovieNightVoteAdmin(admin.ModelAdmin):
    list_display = ("id", "movie_night", "user", "movie", "created_at")
    search_fields = (
        "movie_night__title",
        "user__username",
        "movie__title",
        "movie__imdb_id",
    )
