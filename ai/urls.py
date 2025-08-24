from __future__ import annotations

from django.urls import path
from .views import RecommendationsView, GeminiHealthcheckView

urlpatterns = [
    path(
        "recommendations/",
        RecommendationsView.as_view(),
        name="recommendations",
    ),
    path(
        "healthcheck/",
        GeminiHealthcheckView.as_view(),
        name="gemini-healthcheck",
    ),
]
