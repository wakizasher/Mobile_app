from django.urls import path
from .views import (
    NotificationListView,
    NotificationGenerateView,
    NotificationBulkCreateView,
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
]
