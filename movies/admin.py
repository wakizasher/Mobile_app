from django.contrib import admin
from .models import Movie


@admin.register(Movie)
class MovieAdmin(admin.ModelAdmin):
    list_display = ("id", "imdb_id", "title", "year")
    search_fields = ("imdb_id", "title", "year")
