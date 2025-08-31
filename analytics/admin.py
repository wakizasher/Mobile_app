from django.contrib import admin
from .models import AnalyticsEvent


@admin.register(AnalyticsEvent)
class AnalyticsEventAdmin(admin.ModelAdmin):
    list_display = ("id", "event", "user", "imdb_id", "source", "created_at")
    list_filter = ("event", "source", "created_at")
    search_fields = ("event", "imdb_id", "user__email", "user__username")
    date_hierarchy = "created_at"
