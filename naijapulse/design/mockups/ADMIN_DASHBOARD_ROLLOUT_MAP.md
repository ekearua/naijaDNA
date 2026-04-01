# Admin Dashboard Rollout Map

## Design Pack Reviewed

- Extracted archive:
  - `C:\Users\User\Mobile\News Full\admin dashboard designs\stitch_nigerian_news_home_dark_mode (8)`
- Screen root:
  - `C:\Users\User\Mobile\News Full\admin dashboard designs\stitch_nigerian_news_home_dark_mode (8)\stitch_nigerian_news_home_dark_mode`
- Design system:
  - `...\naija_ledger\DESIGN.md`

The pack is a coherent desktop-first editorial admin system with:

- warm paper background surfaces
- deep green newsroom branding
- serif display typography for authority
- low-border, high-spacing editorial layouts
- dedicated screens for moderation, workflow, ingestion, taxonomy, and auth

## Current Product Reality

We do **not** have a dedicated admin dashboard frontend yet.

What exists today:

- backend admin/article workflow APIs
- backend ingestion monitoring APIs
- backend notifications APIs
- backend comment moderation/report/like/reply APIs
- a lightweight in-app Flutter `Editorial Desk` page inside the consumer app

This means the design pack is ahead of the frontend implementation. The right use of this pack is to guide a **new dedicated admin web experience**, not to keep stretching the current mobile/editorial page.

## Existing Capability Map

### Already supported in backend

- Article workflow
  - list admin articles
  - create admin article
  - update admin article
  - workflow transitions: approve, publish, reject, archive
- Comment moderation
  - list reported comments
  - remove / restore / dismiss reports
  - deep-link into article discussion
- Notifications
  - list notifications
  - mark read / mark all read
  - reply notifications
  - comment-like notifications
  - editorial action notifications
- Ingestion operations
  - ingestion status
  - manual run
- Source visibility
  - list sources

### Already supported in Flutter, but only as a light operational surface

- `Editorial Desk`
  - article queue by status
  - create article shortcut
  - workflow actions
  - reported comments queue
- article discussion page
  - comments
  - replies
  - likes
  - report
  - moderator actions
- notifications inbox
  - unread badge in shell/profile/app bar

### Still missing or partial

- dedicated admin auth screens
- dashboard metrics aggregation
- article review detail screen matching the design pack
- source management actions
- tags/category management UI
- user/roles management UI
- scheduled articles UI
- analytics UI
- notification operations/monitoring UI
- cache/sync operations UI
- verification desk UI

## Screen-by-Screen Fit

### Ready to build immediately from current APIs

These screens already have enough backend support to be built now.

#### `articles_queue`

Status: `Backend-ready, frontend-partial`

Can support now:

- list articles by status
- create article
- workflow actions
- basic filtering by status

Still needed:

- richer filters
- table actions
- bulk actions
- assign editor support

#### `create_article`

Status: `Backend-ready, frontend-partial`

Can support now:

- manual admin article creation
- source URL workflow
- verification status
- featured/status metadata

Still needed:

- richer preview
- duplicate detection panel
- scheduled publish support in UI if already stored

#### `comment_moderation`

Status: `Backend-ready, frontend-partial`

Can support now:

- reported comments queue
- remove / restore / dismiss reports
- open discussion deep-link
- thread context through discussion page

Still needed:

- richer thread-side inspector
- filter tabs
- moderation history

#### `notifications_monitor`

Status: `Backend-ready, frontend-missing`

Can support now:

- notifications list
- unread/read state
- types and targets

Still needed:

- admin/operator-oriented filtering and event monitoring view

#### `ingestion_monitor`

Status: `Backend-ready, frontend-missing`

Can support now:

- last run
- recent runs
- per-source fetched/inserted/deduped/errors
- manual run

Still needed:

- dashboard cards
- source actions from UI

### Can be built with modest backend additions

#### `admin_dashboard`

Status: `Needs aggregation layer`

Needed additions:

- summary endpoint for:
  - draft/submitted/published counts
  - flagged comments count
  - source health counts
  - recent workflow activity

#### `article_review`

Status: `Mostly backed, detail payload needs improvement`

Needed additions:

- workflow history payload
- reviewer notes payload
- maybe article duplicate candidates
- maybe source preview metadata

#### `verification_desk_hub`

Status: `Partial backend foundation`

Already present:

- `verification_status` on articles

Needed additions:

- list/filter by verification status
- editorial notes/history endpoint
- trust/source confidence workflow

#### `published_articles_manager`

Status: `Mostly a filtered article queue`

Needed additions:

- engagement fields if desired
- quick archive/feature toggles in dedicated surface

#### `scheduled_articles_calendar`

Status: `Data shape likely partial`

Needed additions:

- scheduled publish semantics exposed clearly
- list endpoint optimized for scheduled content
- calendar-oriented grouping

### Require new backend functionality

#### `source_registry_manager`

Status: `Read-only today`

Missing:

- create/update source endpoints
- enable/disable source
- edit mapping/notes
- test source action

#### `tags_management`

Status: `Backend exists, admin UX missing`

Missing:

- complete admin CRUD UX
- ordering/visibility controls if desired

#### `categories_management`

Status: `Backend exists, admin UX missing`

Missing:

- complete admin CRUD UX
- ordering/color/mapping management

#### `user_management`

Status: `Backend partial`

Missing:

- user list/search endpoint for admin
- role update endpoint
- account state management

#### `roles_permissions`

Status: `Not modeled as a full permissions matrix`

Missing:

- role management API
- permission model beyond simple role checks

#### `reports_log`

Status: `Could be derived, but no dedicated API`

Missing:

- report log view
- grouped reports endpoint
- resolution history

#### `analytics_dashboard`

Status: `Not implemented`

Missing:

- article engagement metrics
- source performance metrics
- moderation/community metrics

#### `cache_sync_status`

Status: `Partial operational data only`

Missing:

- cache hit/miss introspection endpoint
- per-endpoint freshness diagnostics

## Recommended Frontend Architecture

## Recommendation

Build the admin dashboard as a **dedicated Flutter web/admin experience inside the existing `naijapulse` project**, but keep it clearly separated from the consumer shell.

Why this is the best fit right now:

- we already have Flutter in place
- the design pack is desktop-first and can map to Flutter web layouts
- we can reuse auth/session models, API client wiring, and routing infrastructure
- we avoid introducing a second frontend stack before the newsroom workflows stabilize

## Do not do this

- do not keep expanding the current mobile `Editorial Desk` as the main admin surface
- do not force the full admin IA into the bottom-nav consumer shell

That will create an awkward mixed product with desktop-style operations jammed into a consumer app architecture.

## Suggested structure

Add a separate admin module in Flutter:

- `lib/admin/app/`
- `lib/admin/core/`
- `lib/admin/features/dashboard/`
- `lib/admin/features/articles/`
- `lib/admin/features/moderation/`
- `lib/admin/features/notifications/`
- `lib/admin/features/ingestion/`
- `lib/admin/features/auth/`

Use a separate shell for admin:

- top app bar
- left rail/sidebar
- desktop/tablet responsive layout

## Recommended Build Order

### Phase 1: Operable newsroom core

Build first:

1. admin auth screens
2. admin shell layout
3. dashboard summary
4. articles queue
5. create/edit article
6. article review
7. comment moderation
8. ingestion monitor

This produces a usable newsroom console quickly.

### Phase 2: Taxonomy and trust

Build next:

1. verification desk
2. source registry
3. tags management
4. categories management

### Phase 3: People and operations

Build after that:

1. users
2. roles & permissions
3. notifications monitor
4. reports log
5. cache/sync status

### Phase 4: Analytics

Build last:

1. analytics dashboard
2. source performance
3. community performance

## Immediate Next Implementation Tasks

If we start using this design pack now, the most pragmatic first sprint is:

1. create a dedicated admin route tree and shell in Flutter web
2. build `admin_login_desktop` and `admin_forgot_password_desktop`
3. upgrade `AdminArticlesPage` into the full `articles_queue` layout
4. create a standalone `comment_moderation` page using the existing moderation APIs
5. create an `ingestion_monitor` page using `/admin/ingestion/status`
6. add a dashboard summary endpoint to support `admin_dashboard`

## API Gaps To Close Soon

For the design pack to be realized well, these backend additions should be prioritized:

- dashboard summary endpoint
- article workflow history endpoint
- admin user list / role update endpoints
- source registry mutation endpoints
- verification desk listing/filtering endpoint
- grouped reports endpoint
- cache/sync diagnostics endpoint

## Conclusion

The extracted pack is good enough to become the visual source of truth for a real admin platform.

The important constraint is architectural:

- consumer app editorial tools should stay lightweight
- the full admin platform should become a dedicated web/admin surface

That gives us the cleanest path to implement the designs without fighting the existing mobile UX model.
