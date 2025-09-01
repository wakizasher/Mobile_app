from django.urls import path
from .views import (
    NotificationListView,
    NotificationGenerateView,
    NotificationBulkCreateView,
    NotificationBulkPushView,
)

urlpatterns = [
    path("", NotificationListView.as_view(), name="notifications_list"),
    path(
        "generate/",
        NotificationGenerateView.as_view(),
        name="notification_generate",
    ),
    path(
        "bulk-create/",
        NotificationBulkCreateView.as_view(),
        name="notification_bulk_create",
    ),
    path(
        "bulk-push/",
        NotificationBulkPushView.as_view(),
        name="notification_bulk_push",
    ),
]
