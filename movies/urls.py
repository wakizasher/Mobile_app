from django.urls import path
from .views import MovieSearchView, MovieDetailView, PopularMoviesView, ReviewSummaryView

urlpatterns = [
    path("search/", MovieSearchView.as_view(), name="movie_search"),
    path("popular/", PopularMoviesView.as_view(), name="movie_popular"),
    path("<str:imdb_id>/review-summary/", ReviewSummaryView.as_view(), name="movie_review_summary"),
    path("<str:imdb_id>/", MovieDetailView.as_view(), name="movie_detail"),
]
