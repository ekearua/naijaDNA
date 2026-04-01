# Features Architecture

Use feature-first clean architecture:

- `data`: remote/local sources, DTO models, repository implementations.
- `domain`: entities, repository contracts, use cases.
- `presentation`: state management + UI (`bloc`, `pages`, `widgets`).

## Current Features

- `auth`: sign in/up, token/session refresh, onboarding auth gate.
- `user`: profile, preferences, following topics, saved settings.
- `news`: feed, categories, article detail, bookmarks, search.
- `polls`: public pulse polls, vote submission, poll summaries.
- `notifications`: push permissions, notification inbox, deep-link handling.
- `stream`: live updates, live event pages, real-time timeline.

## Suggested Boundaries

- Keep `auth` focused on identity/session only.
- Keep `user` focused on profile/preferences; do not mix with auth.
- Keep `news` as editorial content and article interactions.
- Keep `polls` scoped to community polling and civic participation features.
- Keep `stream` as real-time/live-event logic; avoid mixing with normal feed.
- Let `notifications` orchestrate routing to `news` and `stream`.

## Next Recommended Folders

Inside each feature, add:

- `domain/usecases/`
- `domain/entities/`
- `domain/repositories/`
- `data/datasources/`
- `data/models/`
- `data/repositories/`
- `presentation/bloc/` (or `cubit/`, if preferred)
- `presentation/pages/`
- `presentation/widgets/`
