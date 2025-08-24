from django.urls import path
from .views import NotificationListView, NotificationGenerateView

urlpatterns = [
    path("", NotificationListView.as_view(), name="notifications_list"),
    path(
        "generate/",
        NotificationGenerateView.as_view(),
        name="notification_generate",
    ),
]
