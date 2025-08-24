from django.urls import path
from .views import (
    FavoriteListCreateView,
    FavoriteDeleteView,
    LikeToggleView,
    ShareCreateView,
    ReviewListCreateView,
    SocialStatsView,
    ReviewSentimentAnalysisView,
    GenerateSocialPostView,
)

urlpatterns = [
    path("favorites/", FavoriteListCreateView.as_view(), name="favorite_list_create"),
    path("favorites/<str:imdb_id>/", FavoriteDeleteView.as_view(), name="favorite_delete"),
    path("likes/toggle/", LikeToggleView.as_view(), name="like_toggle"),
    path("shares/", ShareCreateView.as_view(), name="share_create"),
    path("reviews/", ReviewListCreateView.as_view(), name="review_list_create"),
    path("stats/<str:imdb_id>/", SocialStatsView.as_view(), name="social_stats"),
    path("sentiment-analysis/<int:review_id>/", ReviewSentimentAnalysisView.as_view(), name="review_sentiment_analysis"),
    path("generate-post/", GenerateSocialPostView.as_view(), name="generate_social_post"),
]
