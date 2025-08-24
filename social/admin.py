from django.contrib import admin
from .models import Favorite, Like, Review, Share


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
    list_display = ("id", "user", "movie", "rating", "sentiment", "created_at")
    search_fields = ("user__username", "movie__title", "movie__imdb_id")


@admin.register(Share)
class ShareAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "movie", "platform", "created_at")
    search_fields = ("user__username", "movie__title", "movie__imdb_id", "platform")
