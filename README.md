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