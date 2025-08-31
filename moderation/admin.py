from django.contrib import admin
from .models import ModerationQueue


@admin.register(ModerationQueue)
class ModerationQueueAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "content_type",
        "content_id",
        "user",
        "status",
        "resolved_by",
        "created_at",
    )
    list_filter = ("status", "content_type", "created_at")
    search_fields = (
        "content_type",
        "reason",
        "user__email",
        "user__username",
    )
    date_hierarchy = "created_at"
