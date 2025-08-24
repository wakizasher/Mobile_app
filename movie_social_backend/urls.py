from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

urlpatterns = [
    path("admin/", admin.site.urls),

    # API schema and docs
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"),
         name="swagger-ui"),
    path("api/redoc/", SpectacularRedocView.as_view(url_name="schema"),
         name="redoc"),

    # Apps
    path("api/auth/", include("users.urls")),
    path("api/movies/", include("movies.urls")),
    path("api/social/", include("social.urls")),
    path("api/notifications/", include("notifications.urls")),
    path("api/ai/", include("ai.urls")),
]
