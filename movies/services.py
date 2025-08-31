from __future__ import annotations

from typing import Any, Dict

import requests
from django.conf import settings

OMDB_BASE_URL = "https://www.omdbapi.com/"


def _api_key() -> str:
    key = getattr(settings, "OMDB_API_KEY", "")
    if not key:
        raise ValueError("OMDb API key not configured")
    return key


def search_movies(query: str, page: int = 1) -> Dict[str, Any]:
    """Search movies via OMDb API."""
    params = {"apikey": _api_key(), "s": query, "page": page}
    resp = requests.get(OMDB_BASE_URL, params=params, timeout=15)
    data = resp.json()
    return data


def get_movie_details(imdb_id: str) -> Dict[str, Any]:
    """Get movie details by IMDB ID via OMDb API."""
    params = {"apikey": _api_key(), "i": imdb_id, "plot": "full"}
    resp = requests.get(OMDB_BASE_URL, params=params, timeout=15)
    return resp.json()


def map_omdb_to_fields(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Map OMDb details payload to our Movie fields."""
    return {
        "imdb_id": payload.get("imdbID", ""),
        "title": payload.get("Title", ""),
        "year": payload.get("Year", ""),
        "poster": payload.get("Poster", ""),
        "plot": payload.get("Plot", ""),
        "genre": payload.get("Genre", ""),
        "data": payload,
    }
