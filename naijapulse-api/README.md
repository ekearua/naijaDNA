# NaijaPulse API

FastAPI backend for:

- News feed endpoints (`top`, `latest`, `sources`)
- Polls endpoints (`active`, `get poll`, `create poll`, `vote`)
- Categories endpoints (`list`, `create`)
- Users endpoints (`create`, `get`, `update`)
- Ingestion endpoints (`run`, `status`) with scheduled API/RSS ingestion

## Prerequisites

- Python 3.10+
- PostgreSQL 14+ (local or Docker)

## Environment

Copy `.env.example` to `.env` and update values as needed.

Required DB settings:

- `DATABASE_URL=postgresql+asyncpg://postgres:your_postgres_password@localhost:5432/naijapulse`
- `DATABASE_ECHO=false`

Optional provider keys:

- `NEWSAPI_API_KEY=...`
- `GNEWS_API_KEY=...`
- `ENABLE_RSS_SOURCES=true`
- `ENABLE_NEWSAPI_SOURCE=false`
- `ENABLE_GNEWS_SOURCE=false`

## Create database (if needed)

Local Postgres (`psql` installed):

```bash
psql -U postgres -h localhost -c "CREATE DATABASE naijapulse;"
```

Alternative:

```bash
createdb -U postgres -h localhost naijapulse
```

Docker one-liner:

```bash
docker run --name naijapulse-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=naijapulse -p 5432:5432 -d postgres:16
```

## Run locally

1. Install dependencies

```bash
uv sync
```

2. Apply DB migrations

```bash
uv run alembic upgrade head
```

Create local test users:

```bash
uv run python scripts/create_admin.py --email admin@example.com --prompt-password --name "Admin User"
uv run python scripts/create_editor.py --email editor@example.com --prompt-password --name "Editor User"
uv run python scripts/create_user.py --email user@example.com --prompt-password --name "Standard User"
```

Or use the generic role-aware command:

```bash
uv run python scripts/manage_user.py --email contributor@example.com --role contributor --prompt-password --name "Contributor User"
```

3. Start API server

```bash
uv run uvicorn app.main:app --reload
```

4. Open docs

- Swagger UI: `http://127.0.0.1:8000/docs`
- OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`

Startup behavior:

- On first run, default source records are synchronized into Postgres.
- The app triggers one ingestion run on startup to pull real news immediately.
- Startup ingestion has a timeout guard; API startup continues even if upstream providers are slow/unreachable.
- No sample news or poll rows are seeded.
- RSS sources are the default ingestion path for the current rollout.
- `newsapi` and `gnews` remain optional adapters, but are disabled by default unless explicitly enabled in `.env`.
- RSS sources do not require API keys; only reachable feed URLs.
- User data tables are now available for poll ownership, bookmarks, interests, and preferences.
- Article workflow and trust fields now support editorial review and admin publishing.

## API routes

Base prefix: `/api/v1`

- `GET /api/v1/health`
- `GET /api/v1/news/top?limit=10&category=Politics`
- `GET /api/v1/news/latest?limit=20`
- `GET /api/v1/news/sources`
- `POST /api/v1/news`
- `GET /api/v1/admin/articles?status=draft`
- `POST /api/v1/admin/articles`
- `PATCH /api/v1/admin/articles/{article_id}`
- `POST /api/v1/admin/articles/{article_id}/{action}`
- `GET /api/v1/polls/active`
- `GET /api/v1/polls/{poll_id}`
- `POST /api/v1/polls`
- `POST /api/v1/polls/{poll_id}/vote`
- `GET /api/v1/categories`
- `POST /api/v1/categories`
- `POST /api/v1/users`
- `GET /api/v1/users/{user_id}`
- `PATCH /api/v1/users/{user_id}`
- `GET /api/v1/admin/ingestion/status`
- `POST /api/v1/admin/ingestion/run`

Create category request body:

```json
{
  "id": "politics",
  "name": "Politics",
  "description": "Government, policy, and elections"
}
```

Create poll request body:

```json
{
  "question": "Which policy issue should the National Assembly prioritize this month?",
  "category_id": "politics",
  "ends_at": "2026-03-18T12:00:00Z",
  "options": [
    {"id": "economy", "label": "Economy"},
    {"id": "security", "label": "Security"},
    {"id": "power", "label": "Power supply"}
  ]
}
```

Create user article request body:

```json
{
  "title": "Community Report: Flooding worsens in Lekki axis",
  "category": "Community",
  "summary": "Residents report severe flooding after heavy overnight rainfall.",
  "content_url": "https://example.com/community/flooding-lekki",
  "image_url": "https://example.com/images/flooding.jpg"
}
```

Required header for user article creation:

```text
X-User-Id: user-123
```

Admin article create request body:

```json
{
  "title": "CBN holds rates as inflation slows",
  "source": "BusinessDay",
  "category": "Business",
  "summary": "Editors can save this as a draft or publish it immediately.",
  "source_url": "https://businessday.ng/example-story",
  "image_url": "https://businessday.ng/example-story.jpg",
  "status": "draft",
  "verification_status": "verified",
  "is_featured": true
}
```

Required header for admin article routes:

```text
X-User-Id: admin-or-editor-user-id
```

Supported article workflow actions:

- `submit`
- `approve`
- `publish`
- `reject`
- `archive`

Supported editorial verification states:

- `unverified`
- `developing`
- `verified`
- `fact_checked`
- `opinion`
- `sponsored`

Optional header for poll ownership:

```text
X-User-Id: user-123
```

Vote request body:

```json
{
  "option_id": "economy",
  "idempotency_key": "vote-1741517000123456-12345-67890"
}
```

Optional header for one-vote-per-device behavior:

```text
X-Device-Id: your-stable-device-id
```

Optional header for one-vote-per-user behavior (when signed in):

```text
X-User-Id: user-123
```

Create user request body:

```json
{
  "id": "user-123",
  "email": "john@example.com",
  "display_name": "John Olawale",
  "avatar_url": "https://cdn.example.com/avatars/john.jpg",
  "subscription_tier": "free"
}
```

Update user request body:

```json
{
  "display_name": "John O.",
  "subscription_tier": "premium",
  "subscription_started_at": "2026-03-11T00:00:00Z",
  "subscription_expires_at": "2026-12-31T23:59:59Z",
  "is_active": true
}
```

Supported `subscription_tier` values: `free`, `premium`, `pro`.

Vote response body:

```json
{
  "poll": {
    "id": "fuel-priority",
    "question": "What issue matters most to you?",
    "options": [],
    "ends_at": "2026-03-10T12:00:00",
    "has_voted": true,
    "selected_option_id": "economy"
  },
  "outcome": "applied"
}
```

`outcome` can be `applied`, `idempotent`, `already_voted`, or `closed`.

Ingestion run request body:

```json
{
  "source_ids": ["google_news_rss", "guardian_ng_rss"],
  "limit_per_source": 25
}
```

## Ingestion pipeline

Pipeline stages:

1. Fetch from active/configured sources.
2. Normalize feed items to canonical `NewsArticle`.
3. Deduplicate and ingest into Postgres.
4. Record source-level and run-level metrics.

Scheduler:

- Uses `APScheduler` (`AsyncIOScheduler`) to run periodic ingestion.
- Controlled by env variables in `.env.example`.
- Optional startup controls:
  - `RUN_INGESTION_ON_STARTUP=true|false`
  - `INGESTION_STARTUP_TIMEOUT_SECONDS=20`
  - `INGESTION_STARTUP_LIMIT_PER_SOURCE=10`

If you are troubleshooting request timeouts, temporarily set:

- `RUN_INGESTION_ON_STARTUP=false`

This keeps API startup focused on DB/service readiness and skips boot-time provider pulls.

## Admin workflow note

Role assignment is intentionally server-side for now. Public `/users` routes no longer accept a client-provided role because that would let anyone self-elevate.

To test admin publishing locally, promote a known user in Postgres:

```sql
UPDATE users
SET role = 'admin'
WHERE email = 'you@example.com';
```

## Project layout

```text
app/
  api/
    deps.py
    router.py
    routers/
      categories.py
      health.py
      news.py
      polls.py
      users.py
  db/
    base.py
    models.py
    session.py
  core/
    config.py
  schemas/
    categories.py
    ingestion.py
    news.py
    polls.py
    users.py
  services/
    ingestion_pipeline_service.py
    news_service.py
    polls_service.py
    source_registry_service.py
    source_catalog.py
    users_service.py
  integrations/
    news_sources/
      base.py
      gnews_adapter.py
      newsapi_adapter.py
      rss_adapter.py
  main.py
alembic/
  env.py
  versions/
    20260305_0001_init_postgres_schema.py
    20260309_0002_add_poll_votes_table.py
    20260311_0003_add_categories_and_poll_creation_fields.py
    20260311_0004_add_users_and_relationship_tables.py
    20260311_0005_add_user_article_submission_and_subscription_tiers.py
```


## LiveKit Cloud

For development, the stream feature can use LiveKit Cloud for real camera/microphone publishing and viewer playback.

Add these values from your LiveKit Cloud project settings to `.env`:

- `LIVEKIT_URL=wss://your-project.livekit.cloud`
- `LIVEKIT_API_KEY=...`
- `LIVEKIT_API_SECRET=...`
- `LIVEKIT_TOKEN_TTL_SECONDS=3600`

Stream media flow:

1. The app creates or starts a stream through `/api/v1/streams`.
2. When the stream is live, the Flutter client requests `/api/v1/streams/{stream_id}/livekit-connection`.
3. The backend mints a short-lived participant token and returns the LiveKit WebSocket URL.
4. The host publishes camera/microphone. Viewers subscribe to the room.

LiveKit connection request body:

```json
{
  "viewer_id": "viewer-1742030400000"
}
```

LiveKit connection response body:

```json
{
  "ws_url": "wss://your-project.livekit.cloud",
  "token": "<jwt>",
  "room_name": "naijapulse-stream-abc123",
  "participant_identity": "host:user-123",
  "participant_name": "John Olawale",
  "can_publish": true,
  "can_subscribe": true
}
```
