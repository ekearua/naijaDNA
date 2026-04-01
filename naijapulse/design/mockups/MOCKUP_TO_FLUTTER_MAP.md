# Mockup to Flutter Screen Map

This file maps the mockups in `design/mockups` to the current Flutter screens, routes, and supporting foundation files.

## Global foundation

Use these files as the shared implementation layer for all mapped mockups:

- `lib/core/theme/theme.dart`: shared color, typography, spacing, surfaces, and component defaults
- `lib/core/shell/app_shell_page.dart`: shared app bar, shell scaffold, and bottom navigation for tabbed pages
- `lib/core/routing/app_router.dart`: route ownership and which page class is currently wired into each path

## Direct screen mappings

| Mockup source | Mockup screen | Flutter target | Route | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| `stitch_nigerian_news_home_dark_mode.zip` | `sign_in_light_mode` | `lib/features/auth/presentation/pages/login_page.dart` | `/auth/login` | Exists | Light-mode auth screen already has the right product role. |
| `stitch_nigerian_news_home_dark_mode (1).zip` | `sign_in_dark_mode` | `lib/features/auth/presentation/pages/login_page.dart` | `/auth/login` | Exists | Same page as above; dark mode should come from theme tokens instead of a separate screen. |
| `stitch_nigerian_news_home_dark_mode.zip` | `register_light_mode` | `lib/features/auth/presentation/pages/register_page.dart` | `/auth/register` | Exists | Use the same layout structure as sign-in for consistency. |
| `stitch_nigerian_news_home_dark_mode (1).zip` | `register_dark_mode` | `lib/features/auth/presentation/pages/register_page.dart` | `/auth/register` | Exists | Dark-mode variant should be implemented through `AppTheme.dark`. |
| `stitch_nigerian_news_home_dark_mode.zip` | `forgot_password_light_mode` | Missing page | Missing route | Gap | Add `lib/features/auth/presentation/pages/forgot_password_page.dart` and a matching auth route if we want this flow in-app. |
| `stitch_nigerian_news_home_dark_mode (1).zip` | `forgot_password_dark_mode` | Missing page | Missing route | Gap | Same missing flow as above; dark mode should be theme-driven, not a second page. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `saved_light_mode_unified` | `lib/features/news/presentation/pages/saved_stories_page.dart` | `/saved` | Exists | Strong one-to-one match for the saved/bookmark tab. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `saved_dark_mode_unified` | `lib/features/news/presentation/pages/saved_stories_page.dart` | `/saved` | Exists | Same page; style through theme. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `streams_light_mode_unified` | `lib/features/stream/presentation/pages/stream_home_page.dart` | `/live` | Exists | Best match for the live/streams tab. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `streams_dark_mode_unified` | `lib/features/stream/presentation/pages/stream_home_page.dart` | `/live` | Exists | Same screen in dark mode. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `user_account_light_mode_unified` | `lib/features/user/presentation/pages/user_home_page.dart` | `/profile` | Exists | Maps to the profile/preferences area. |
| `stitch_nigerian_news_home_dark_mode (2).zip` | `user_account_dark_mode_unified` | `lib/features/user/presentation/pages/user_home_page.dart` | `/profile` | Exists | Same page; theme should drive the dark treatment. |
| `stitch_nigerian_news_home_dark_mode (3).zip` | `explore_light_mode` | `lib/features/search/presentation/pages/search_page.dart` | `/explore` and `/search` | Exists | The shell tab uses `/explore`; the standalone pushed search flow uses `/search`. |
| `stitch_nigerian_news_home_dark_mode (3).zip` | `explore_dark_mode_unified` | `lib/features/search/presentation/pages/search_page.dart` | `/explore` and `/search` | Exists | Same search/explore screen with dark tokens. |
| `stitch_nigerian_news_home_dark_mode (4).zip` | `nigerian_news_balanced_light_mode` | `lib/features/news/presentation/pages/news_home_page.dart` | `/home` | Exists | This is the main home feed mockup. |
| `stitch_nigerian_news_home_dark_mode (4).zip` | `nigerian_news_balanced_dark_mode` | `lib/features/news/presentation/pages/news_home_page.dart` | `/home` | Exists | Same home feed in dark mode. |
| `stitch_nigerian_news_home_dark_mode (5).zip` | `breaking_news_light_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Closest current screen for a category-first story list. If this mockup is meant to be a live timeline, `news_live_feed_page.dart` may be a better final target. |
| `stitch_nigerian_news_home_dark_mode (6).zip` | `breaking_news_dark_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Same note as above; current code does not have a dedicated breaking-news route. |
| `stitch_nigerian_news_home_dark_mode (5).zip` | `business_light_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Best implemented as a prefiltered category state inside `NewsAllPage`. |
| `stitch_nigerian_news_home_dark_mode (6).zip` | `business_dark_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Same page in dark mode. |
| `stitch_nigerian_news_home_dark_mode (5).zip` | `music_light_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | No dedicated music route yet; use category filtering or add a category route later. |
| `stitch_nigerian_news_home_dark_mode (6).zip` | `music_dark_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Same implementation target. |
| `stitch_nigerian_news_home_dark_mode (5).zip` | `sports_light_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Could also feed from tagged stories if sports becomes a live cluster. |
| `stitch_nigerian_news_home_dark_mode (6).zip` | `sports_dark_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Same implementation target. |
| `stitch_nigerian_news_home_dark_mode (5).zip` | `entertainment_lifestyle_light_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Fits the all-news/category page pattern. |
| `stitch_nigerian_news_home_dark_mode (6).zip` | `entertainment_lifestyle_dark_mode` | `lib/features/news/presentation/pages/news_all_page.dart` | `/home/all-news` | Partial | Same implementation target. |
| `news_article_detail_mockup.svg` | Article detail | `lib/features/news/presentation/pages/news_article_detail_page.dart` | `/news/:articleId` | Exists | Direct match for the article reading experience. |

## Screens that exist in Flutter but do not have a matching mockup yet

- `lib/features/news/presentation/pages/news_live_feed_page.dart`
- `lib/features/news/presentation/pages/news_submit_page.dart`
- `lib/features/stream/presentation/pages/live_session_page.dart`
- `lib/features/notifications/presentation/pages/notifications_home_page.dart`
- `lib/features/polls/presentation/pages/polls_page.dart`

## Recommended implementation order

1. Apply the mockup system globally in `lib/core/theme/theme.dart` so light/dark variants come from theme data instead of duplicate widget trees.
2. Align the shell-driven tabs first: `news_home_page.dart`, `stream_home_page.dart`, `search_page.dart`, `saved_stories_page.dart`, and `user_home_page.dart`.
3. Refresh the auth pages next: `login_page.dart` and `register_page.dart`, then add a missing forgot-password page if that flow matters for MVP.
4. Decide whether the category mockups should become:
   - one configurable `NewsAllPage` with category presets, or
   - separate named category routes backed by the same page scaffold.
5. Finish article reading polish in `news_article_detail_page.dart` to match `news_article_detail_mockup.svg`.

## Lowest-risk ownership map

- Home/editorial feed mockups: `lib/features/news/presentation/pages/news_home_page.dart`
- Category/story listing mockups: `lib/features/news/presentation/pages/news_all_page.dart`
- Article detail mockup: `lib/features/news/presentation/pages/news_article_detail_page.dart`
- Auth mockups: `lib/features/auth/presentation/pages/login_page.dart` and `lib/features/auth/presentation/pages/register_page.dart`
- Explore mockups: `lib/features/search/presentation/pages/search_page.dart`
- Saved mockups: `lib/features/news/presentation/pages/saved_stories_page.dart`
- Streams mockups: `lib/features/stream/presentation/pages/stream_home_page.dart`
- User account mockups: `lib/features/user/presentation/pages/user_home_page.dart`
