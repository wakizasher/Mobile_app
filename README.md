# Movie Social Backend

Backend API for the movie social app. Uses Django, Django REST Framework, JWT auth, and drf-spectacular for API docs.

## Setup

1) Create a `.env` in this directory. See `ENV.md` for all required variables.
2) Install dependencies and run migrations:

```bash
python -m pip install -r requirements.txt
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

Run server:

```bash
python manage.py runserver 0.0.0.0:8000
```

API docs:
- Swagger UI: `/api/docs/`
- ReDoc: `/api/redoc/`

## New Apps

- `analytics`
  - POST `/api/analytics/ingest/` (JWT or `X-N8N-SECRET`)
  - GET `/api/analytics/events/` (user-scoped)

- `moderation`
  - POST `/api/moderation/ingest/` (JWT or `X-N8N-SECRET`)
  - GET `/api/moderation/queue/` (admin-only)
  - PATCH `/api/moderation/queue/<id>/` (admin-only)

Admin: `/admin/`

See `ENV.md` for CORS and n8n config. The backend validates n8n requests via the `X-N8N-SECRET` header using `N8N_SHARED_SECRET` from the environment.

---

# Overview

Movie Social Backend is a Django + Django REST Framework API for a social movie application. It provides user auth (JWT), social interactions (favorites, likes, reviews, friendships, movie nights), analytics/moderation ingestion, AI-assisted content, and push notifications via FCM. API schema and docs are available with drf-spectacular.

# Features

* __Authentication__: JWT-based auth via DRF SimpleJWT.
* __Movies__: OMDb-powered movie data retrieval (requires API key).
* __Social__: favorites, likes, reviews, friendships, friend requests, and movie nights.
* __Notifications__: bulk create and bulk push via Firebase Cloud Messaging (FCM).
* __Analytics__: event ingest and per-user event viewing.
* __Moderation__: ingest queue and admin review actions.
* __AI__: content generation (e.g., social posts, notification text) via Gemini.
* __API Docs__: OpenAPI schema, Swagger UI, and ReDoc.

# Tech Stack

* Django 5, Django REST Framework
* SimpleJWT for JWT auth
* drf-spectacular for schema/docs
* pyfcm for push notifications (FCM)
* google-generativeai for Gemini integration
* django-cors-headers, django-filter
* SQLite by default; optional Postgres via env vars

# Project structure

Key apps mounted in `movie_social_backend/movie_social_backend/urls.py`:

* __`users/`__: authentication, user search.
* __`movies/`__: movie lookups and related features.
* __`social/`__: favorites, likes, reviews, friendships, movie nights, and the new social endpoints listed below.
* __`notifications/`__: list, generate (AI), bulk-create, bulk-push.
* __`analytics/`__: event ingest and user-scoped listing.
* __`moderation/`__: ingest and review queue.
* __`ai/`__: AI utilities and endpoints.

# Environment

All config is via environment variables. See `ENV.md` for the full reference and `.env` template. Important keys:

* __SECRET_KEY__: Django secret key
* __DEBUG__: `true` for local
* __ALLOWED_HOSTS__: JSON array of allowed hosts
* __OMDB_API_KEY__: required for OMDb
* __GEMINI_API_KEY__: required for AI generation
* __FCM_SERVER_KEY__: required for FCM push
* __N8N_SHARED_SECRET__: shared secret for n8n webhooks
* Optional Postgres vars: `POSTGRES_*`

# Quick start

1) Create `.env` in this directory (see `ENV.md`).
2) Install deps and run migrations:

```bash
python -m pip install -r requirements.txt
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

Run server:

```bash
python manage.py runserver 0.0.0.0:8000
```

API docs:

* Swagger UI: `/api/docs/`
* ReDoc: `/api/redoc/`

# Docker (optional)

This repo includes a `docker-compose.yml`. Typical workflow:

```bash
docker-compose up -d
# Identify the web service name from docker-compose.yml, then:
docker-compose exec <web-service> python manage.py migrate
docker-compose exec <web-service> python manage.py createsuperuser
```

# Authentication

Auth uses JWT via SimpleJWT. Include the header on protected routes:

```
Authorization: Bearer <access_token>
```

Token issuance/refresh endpoints are exposed by the `users` app. Use Swagger UI to discover exact paths and payloads.

# Core API endpoints (selected)

See Swagger UI for the full, always-up-to-date list. Below are selected endpoints, including newly added social and notification routes.

## Social

New endpoints:

* __GET__ `/api/social/recent-favorites/`
  - Recent favorites across all users within a time window.
  - Query params: `minutes` (default 60), pagination params.

* __POST__ `/api/social/users-interested-in-trending/`
  - Given trending IMDB IDs, returns users who engaged with any of those movies.
  - Body: `{ "trending_imdb_ids": ["tt..."], "limit": <int> }`.

* __GET__ `/api/social/active-users/`
  - Users active in the last N days based on favorites, likes, reviews.
  - Query params: `days` (default 7), `limit`.

* __GET__ `/api/social/user-movie-history/<user_id>/`
  - Summary of a user's movie interactions with recent items.

* __GET__ `/api/social/friends/<user_id>/activity/`
  - Friends' recent activity (favorites, likes, reviews) within a time window.
  - Query params: `minutes`, `limit`.

Additional social routes include favorites, likes, reviews, friend requests, friendships, and movie nights.

## Notifications

* __GET__ `/api/notifications/`
  - List notifications for the authenticated user.

* __POST__ `/api/notifications/generate/`
  - Generate a personalized notification via Gemini, optionally push to a provided `device_token`.

* __POST__ `/api/notifications/bulk-create/`
  - Generate and persist notifications for multiple users (no push).

* __POST__ `/api/notifications/bulk-push/`
  - Push to explicit `recipients` and create matching notification records with delivery status.

## Users

* __GET__ `/api/auth/search/?q=<term>`
  - Authenticated user search by username/display name/email fields (project-defined).

## AI

* __POST__ `/api/social/generate/`
  - Generate an AI-assisted social post for a movie (Gemini-based).
  - Requires `GEMINI_API_KEY`. The backend expects the movie to exist; consider adding an auto-create fallback if needed.

## Analytics and Moderation

* __Analytics__
  - __POST__ `/api/analytics/ingest/` (JWT or `X-N8N-SECRET`)
  - __GET__ `/api/analytics/events/` (user-scoped)

* __Moderation__
  - __POST__ `/api/moderation/ingest/` (JWT or `X-N8N-SECRET`)
  - __GET__ `/api/moderation/queue/` (admin-only)
  - __PATCH__ `/api/moderation/queue/<id>/` (admin-only)

# Examples

All examples assume a valid JWT access token in `AUTH`.

```bash
AUTH="Authorization: Bearer <token>"
```

## Social: Recent favorites

```bash
curl -H "$AUTH" \
  "http://localhost:8000/api/social/recent-favorites/?minutes=60&page=1"
```

## Social: Users interested in trending

```bash
curl -H "$AUTH" -H "Content-Type: application/json" \
  -X POST \
  -d '{"trending_imdb_ids":["tt0111161","tt4154796"],"limit":50}' \
  http://localhost:8000/api/social/users-interested-in-trending/
```

## Notifications: Bulk push

```bash
curl -H "$AUTH" -H "Content-Type: application/json" -X POST \
  -d '{
    "recipients": [
      {"user_id": 1, "device_token": "fcm_token_1"},
      {"user_id": 2, "device_token": "fcm_token_2"}
    ],
    "title": "Trending now",
    "body": "New hot picks are out!",
    "data": {"screen": "trending", "cta": "open_app"}
  }' \
  http://localhost:8000/api/notifications/bulk-push/
```

## Users: Search

```bash
curl -H "$AUTH" \
  "http://localhost:8000/api/auth/search/?q=anna"
```

## AI: Social post generation

```bash
curl -H "$AUTH" -H "Content-Type: application/json" -X POST \
  -d '{
    "imdb_id": "tt0111161",
    "tone": "twitter",
    "hashtags": ["#movies","#mustwatch"]
  }' \
  http://localhost:8000/api/social/generate/
```

# Development guidelines

* __Code style__: PEP 8, DRF, class-based views, docstrings on models and views.
* __Security__: never commit secrets; use environment variables. Ensure authentication on protected endpoints.
* __Apps__: keep distinct features in separate apps.
* __Models__: create migrations after model changes.

# Testing

Basic test workflow:

```bash
# (add tests/ as needed)
python manage.py test -v 2
```

# Deployment notes

* Set `DEBUG=false` and configure `ALLOWED_HOSTS`.
* Configure CORS to your frontend origins.
* Provide production DB settings or use the default SQLite only for small deployments.

---

If you have questions or want to extend the API, check the Swagger UI and browse the apps under `movie_social_backend/`.