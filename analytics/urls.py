from django.urls import path
from .views import AnalyticsIngestView, AnalyticsListView

urlpatterns = [
    path("ingest/", AnalyticsIngestView.as_view(), name="analytics_ingest"),
    path("events/", AnalyticsListView.as_view(), name="analytics_events"),
]
