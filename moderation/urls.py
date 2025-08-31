from django.urls import path
from .views import (
    ModerationIngestView,
    ModerationQueueListView,
    ModerationQueueUpdateView,
)

urlpatterns = [
    path(
        "ingest/",
        ModerationIngestView.as_view(),
        name="moderation_ingest",
    ),
    path(
        "queue/",
        ModerationQueueListView.as_view(),
        name="moderation_queue_list",
    ),
    path(
        "queue/<int:pk>/",
        ModerationQueueUpdateView.as_view(),
        name="moderation_queue_update",
    ),
]
