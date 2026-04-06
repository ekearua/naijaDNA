import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/presentation/admin_shell_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_analytics_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_article_editor_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_article_detail_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_articles_management_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_forgot_password_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_homepage_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_login_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_moderation_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_operations_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_request_access_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_reset_password_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_sources_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_users_page.dart';
import 'package:naijapulse/admin/presentation/pages/admin_verification_page.dart';
import 'package:naijapulse/core/connectivity/connectivity_cubit.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/shell/app_shell_page.dart';
import 'package:naijapulse/core/shell/loading_page.dart';
import 'package:naijapulse/core/sync/poll_vote_replay_service.dart';
import 'package:naijapulse/core/sync/sync_cubit.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:naijapulse/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:naijapulse/features/auth/presentation/pages/login_page.dart';
import 'package:naijapulse/features/auth/presentation/pages/register_page.dart';
import 'package:naijapulse/features/auth/presentation/pages/reset_password_page.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/pages/article_discussion_page.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/pages/news_article_detail_page.dart';
import 'package:naijapulse/features/news/presentation/pages/news_all_page.dart';
import 'package:naijapulse/features/news/presentation/pages/news_live_feed_page.dart';
import 'package:naijapulse/features/news/presentation/pages/news_home_page.dart';
import 'package:naijapulse/features/news/presentation/pages/news_submit_page.dart';
import 'package:naijapulse/features/news/presentation/pages/admin_articles_page.dart';
import 'package:naijapulse/features/news/presentation/pages/saved_stories_page.dart';
import 'package:naijapulse/features/notifications/presentation/pages/notifications_home_page.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';
import 'package:naijapulse/features/polls/presentation/pages/polls_page.dart';
import 'package:naijapulse/features/search/presentation/pages/search_page.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_bloc.dart';
import 'package:naijapulse/features/stream/presentation/pages/live_session_page.dart';
import 'package:naijapulse/features/stream/presentation/pages/stream_home_page.dart';
import 'package:naijapulse/features/user/presentation/pages/user_home_page.dart';

class AppRouter {
  const AppRouter._();

  static const String loadingPath = '/';
  static const String homePath = '/home';
  static const String livePath = '/live';
  static const String homeLiveFeedPath = '/home/live-feed';
  static const String newsAllPath = '/home/all-news';
  static const String explorePath = '/explore';
  static const String savedPath = '/saved';
  static const String pollsPath = '/polls';
  static const String alertsPath = '/alerts';
  static const String profilePath = '/profile';
  static const String searchPath = '/search';
  static const String newsSubmitPath = '/news/submit';
  static const String adminEntryPath = '/admin';
  static const String legacyAdminArticlesPath = '/news/admin';
  static const String adminLoginPath = '/admin/login';
  static const String adminForgotPasswordPath = '/admin/forgot-password';
  static const String adminResetPasswordPath = '/admin/reset-password';
  static const String adminRequestAccessPath = '/admin/request-access';
  static const String adminDashboardPath = '/admin/dashboard';
  static const String adminArticlesPath = '/admin/articles';
  static const String adminArticleCreatePath = '/admin/articles/new';
  static const String adminModerationPath = '/admin/moderation';
  static const String adminOperationsPath = '/admin/operations';
  static const String adminAnalyticsPath = '/admin/analytics';
  static const String adminVerificationPath = '/admin/verification';
  static const String adminHomepagePath = '/admin/homepage';
  static const String adminSourcesPath = '/admin/sources';
  static const String adminUsersPath = '/admin/users';
  static const String adminArticleDetailPathTemplate =
      '/admin/articles/:articleId';
  static const String adminArticleEditPathTemplate =
      '/admin/articles/:articleId/edit';
  static const String articleDiscussionPathTemplate =
      '/news/:articleId/discussion';
  static const String loginPath = '/auth/login';
  static const String registerPath = '/auth/register';
  static const String forgotPasswordPath = '/auth/forgot-password';
  static const String resetPasswordPath = '/auth/reset-password';
  static const String newsDetailPathTemplate = '/news/:articleId';
  static const String liveSessionPathTemplate = '/live/session/:sessionId';

  static String newsDetailPath(String articleId) => '/news/$articleId';
  static String adminArticleDetailPath(String articleId) =>
      '/admin/articles/${Uri.encodeComponent(articleId)}';
  static String adminArticleEditPath(String articleId) =>
      '/admin/articles/${Uri.encodeComponent(articleId)}/edit';
  static String articleDiscussionPath(String articleId, {int? commentId}) {
    final encodedArticleId = Uri.encodeComponent(articleId);
    final basePath = '/news/$encodedArticleId/discussion';
    if (commentId == null) {
      return basePath;
    }
    final query = Uri(queryParameters: {'comment': '$commentId'}).query;
    return '$basePath?$query';
  }

  static String liveSessionPath(String sessionId) => '/live/session/$sessionId';
  static String liveFeedPath({required String tagId, String? label}) {
    final tagParam = Uri.encodeQueryComponent(tagId);
    if (label == null || label.trim().isEmpty) {
      return '$homeLiveFeedPath?tag=$tagParam';
    }
    final labelParam = Uri.encodeQueryComponent(label.trim());
    return '$homeLiveFeedPath?tag=$tagParam&label=$labelParam';
  }

  static final GoRouter clientRouter = GoRouter(
    initialLocation: loadingPath,
    routes: _clientRoutes(),
    errorBuilder: _errorBuilder,
  );

  static final GoRouter adminRouter = GoRouter(
    initialLocation: loadingPath,
    routes: _adminRoutes(),
    errorBuilder: _errorBuilder,
  );

  static Widget _errorBuilder(BuildContext context, GoRouterState state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Not Found')),
      body: Center(child: Text('No route defined for ${state.uri.path}.')),
    );
  }

  static List<RouteBase> _clientRoutes() => [
    GoRoute(
      path: loadingPath,
      builder: (context, state) => const LoadingPage(),
    ),
    GoRoute(
      path: searchPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: SearchPage()),
    ),
    GoRoute(
      path: newsSubmitPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: NewsSubmitPage()),
    ),
    GoRoute(
      path: legacyAdminArticlesPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: AdminArticlesPage()),
    ),
    GoRoute(
      path: loginPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: LoginPage()),
    ),
    GoRoute(
      path: registerPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: RegisterPage()),
    ),
    GoRoute(
      path: forgotPasswordPath,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: resetPasswordPath,
      builder: (context, state) =>
          ResetPasswordPage(initialToken: state.uri.queryParameters['token']),
    ),
    GoRoute(
      path: alertsPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: NotificationsHomePage()),
    ),
    GoRoute(
      path: pollsPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: PollsPage()),
    ),
    GoRoute(
      path: homeLiveFeedPath,
      builder: (context, state) {
        final tagId = state.uri.queryParameters['tag'] ?? '';
        final tagLabel = state.uri.queryParameters['label'];
        return _StandaloneFeedScope(
          child: NewsLiveFeedPage(tagId: tagId, tagLabel: tagLabel),
        );
      },
    ),
    _newsDetailRoute(),
    _articleDiscussionRoute(),
    _liveSessionRoute(),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ShellProviders(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: homePath,
              builder: (context, state) =>
                  const NewsHomePage(showScaffold: false),
              routes: [
                GoRoute(
                  path: 'all-news',
                  builder: (context, state) =>
                      const NewsAllPage(showScaffold: false),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: livePath,
              builder: (context, state) => const StreamHomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: explorePath,
              builder: (context, state) =>
                  const SearchPage(showScaffold: false),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: savedPath,
              builder: (context, state) =>
                  const SavedStoriesPage(showScaffold: false),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: profilePath,
              builder: (context, state) => const UserHomePage(),
            ),
          ],
        ),
      ],
    ),
  ];

  static List<RouteBase> _adminRoutes() => [
    GoRoute(path: loadingPath, redirect: (context, state) => adminLoginPath),
    GoRoute(path: homePath, redirect: (context, state) => adminDashboardPath),
    GoRoute(path: adminEntryPath, redirect: (context, state) => adminLoginPath),
    GoRoute(
      path: adminLoginPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: AdminLoginPage()),
    ),
    GoRoute(
      path: adminForgotPasswordPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: AdminForgotPasswordPage()),
    ),
    GoRoute(
      path: adminRequestAccessPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: AdminRequestAccessPage()),
    ),
    GoRoute(
      path: adminResetPasswordPath,
      builder: (context, state) => _StandaloneAuthScope(
        child: AdminResetPasswordPage(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: loginPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: LoginPage()),
    ),
    GoRoute(
      path: forgotPasswordPath,
      builder: (context, state) =>
          const _StandaloneAuthScope(child: ForgotPasswordPage()),
    ),
    GoRoute(
      path: resetPasswordPath,
      builder: (context, state) => _StandaloneAuthScope(
        child: ResetPasswordPage(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: alertsPath,
      builder: (context, state) =>
          const _StandaloneFeedScope(child: NotificationsHomePage()),
    ),
    _newsDetailRoute(),
    _articleDiscussionRoute(),
    ShellRoute(
      builder: (context, state, child) =>
          AdminShellPage(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: adminDashboardPath,
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: adminArticlesPath,
          builder: (context, state) => const AdminArticlesManagementPage(),
        ),
        GoRoute(
          path: adminArticleCreatePath,
          builder: (context, state) => const AdminArticleEditorPage(),
        ),
        GoRoute(
          path: adminArticleDetailPathTemplate,
          builder: (context, state) {
            final articleId = state.pathParameters['articleId'] ?? '';
            return AdminArticleDetailPage(articleId: articleId);
          },
        ),
        GoRoute(
          path: adminArticleEditPathTemplate,
          builder: (context, state) {
            final articleId = state.pathParameters['articleId'] ?? '';
            return AdminArticleEditorPage(articleId: articleId);
          },
        ),
        GoRoute(
          path: adminModerationPath,
          builder: (context, state) => const AdminModerationPage(),
        ),
        GoRoute(
          path: adminOperationsPath,
          builder: (context, state) => const AdminOperationsPage(),
        ),
        GoRoute(
          path: adminAnalyticsPath,
          builder: (context, state) => const AdminAnalyticsPage(),
        ),
        GoRoute(
          path: adminVerificationPath,
          builder: (context, state) => const AdminVerificationPage(),
        ),
        GoRoute(
          path: adminHomepagePath,
          builder: (context, state) => const AdminHomepagePage(),
        ),
        GoRoute(
          path: adminSourcesPath,
          builder: (context, state) => const AdminSourcesPage(),
        ),
        GoRoute(
          path: adminUsersPath,
          builder: (context, state) => const AdminUsersPage(),
        ),
      ],
    ),
  ];

  static GoRoute _newsDetailRoute() {
    return GoRoute(
      path: newsDetailPathTemplate,
      builder: (context, state) {
        final articleId = state.pathParameters['articleId'] ?? '';
        final article = state.extra is NewsArticle
            ? state.extra as NewsArticle
            : null;
        return _StandaloneFeedScope(
          child: NewsArticleDetailPage(articleId: articleId, article: article),
        );
      },
    );
  }

  static GoRoute _articleDiscussionRoute() {
    return GoRoute(
      path: articleDiscussionPathTemplate,
      builder: (context, state) {
        final articleId = state.pathParameters['articleId'] ?? '';
        final focusCommentId = int.tryParse(
          state.uri.queryParameters['comment'] ?? '',
        );
        final article = state.extra is NewsArticle
            ? state.extra as NewsArticle
            : null;
        return _StandaloneFeedScope(
          child: ArticleDiscussionPage(
            articleId: articleId,
            article: article,
            focusCommentId: focusCommentId,
          ),
        );
      },
    );
  }

  static GoRoute _liveSessionRoute() {
    return GoRoute(
      path: liveSessionPathTemplate,
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId'] ?? '';
        final session = state.extra is StreamSession
            ? state.extra as StreamSession
            : null;
        return _StandaloneFeedScope(
          child: LiveSessionPage(sessionId: sessionId, session: session),
        );
      },
    );
  }
}

class _ShellProviders extends StatefulWidget {
  const _ShellProviders({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_ShellProviders> createState() => _ShellProvidersState();
}

class _ShellProvidersState extends State<_ShellProviders> {
  late final NewsBloc _newsBloc;
  late final PollsBloc _pollsBloc;
  late final ConnectivityCubit _connectivityCubit;
  late final SyncCubit _syncCubit;
  late final PollVoteReplayService _pollVoteReplayService;
  late final StreamBloc _streamBloc;

  @override
  void initState() {
    super.initState();
    _connectivityCubit = InjectionContainer.sl<ConnectivityCubit>()..start();
    _newsBloc = InjectionContainer.sl<NewsBloc>()
      ..add(const LoadNewsRequested());
    _pollsBloc = InjectionContainer.sl<PollsBloc>()
      ..add(const LoadPollsRequested());
    _streamBloc = InjectionContainer.sl<StreamBloc>()
      ..add(const LoadStreamsRequested());
    _pollVoteReplayService = InjectionContainer.sl<PollVoteReplayService>();
    _syncCubit = SyncCubit(
      connectivityCubit: _connectivityCubit,
      syncAction: _syncFeeds,
    )..start();
  }

  Future<void> _syncFeeds() async {
    // Flush pending offline poll votes before refreshing polls/news snapshots.
    await _pollVoteReplayService.replayPendingVotes();

    // Wait until both blocs settle so sync status reflects combined feed freshness.
    final newsSettled = _newsBloc.stream
        .firstWhere(
          (state) =>
              state.status == NewsStatus.loaded ||
              state.status == NewsStatus.error,
        )
        .timeout(const Duration(seconds: 30), onTimeout: () => _newsBloc.state);
    final pollsSettled = _pollsBloc.stream
        .firstWhere(
          (state) =>
              state.status == PollsStatus.loaded ||
              state.status == PollsStatus.error,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => _pollsBloc.state,
        );
    final streamsSettled = _streamBloc.stream
        .firstWhere(
          (state) =>
              state.status == StreamStatus.loaded ||
              state.status == StreamStatus.error,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => _streamBloc.state,
        );

    _newsBloc.add(const LoadNewsRequested());
    _pollsBloc.add(const LoadPollsRequested());
    _streamBloc.add(const LoadStreamsRequested(silent: true));

    final settled = await Future.wait([
      newsSettled,
      pollsSettled,
      streamsSettled,
    ]);
    final newsState = settled[0] as NewsState;
    final pollsState = settled[1] as PollsState;
    final streamState = settled[2] as StreamState;

    if (newsState.status == NewsStatus.error &&
        pollsState.status == PollsStatus.error &&
        streamState.status == StreamStatus.error) {
      throw UnknownException(
        '${newsState.error ?? 'News sync failed.'} ${pollsState.errorMessage ?? 'Poll sync failed.'} ${streamState.errorMessage ?? 'Stream sync failed.'}',
      );
    }
    if (newsState.status == NewsStatus.error) {
      throw UnknownException(newsState.error ?? 'News sync failed.');
    }
    if (pollsState.status == PollsStatus.error) {
      throw UnknownException(pollsState.errorMessage ?? 'Poll sync failed.');
    }
    if (streamState.status == StreamStatus.error) {
      throw UnknownException(streamState.errorMessage ?? 'Stream sync failed.');
    }
  }

  @override
  void dispose() {
    _syncCubit.close();
    _connectivityCubit.close();
    _newsBloc.close();
    _pollsBloc.close();
    _streamBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NewsBloc>.value(value: _newsBloc),
        BlocProvider<PollsBloc>.value(value: _pollsBloc),
        BlocProvider<StreamBloc>.value(value: _streamBloc),
        BlocProvider<ConnectivityCubit>.value(value: _connectivityCubit),
        BlocProvider<SyncCubit>.value(value: _syncCubit),
      ],
      child: AppShellPage(navigationShell: widget.navigationShell),
    );
  }
}

class _StandaloneFeedScope extends StatefulWidget {
  const _StandaloneFeedScope({required this.child});

  final Widget child;

  @override
  State<_StandaloneFeedScope> createState() => _StandaloneFeedScopeState();
}

class _StandaloneFeedScopeState extends State<_StandaloneFeedScope> {
  late final NewsBloc _newsBloc;
  late final PollsBloc _pollsBloc;
  late final StreamBloc _streamBloc;

  @override
  void initState() {
    super.initState();
    _newsBloc = InjectionContainer.sl<NewsBloc>()
      ..add(const LoadNewsRequested());
    _pollsBloc = InjectionContainer.sl<PollsBloc>()
      ..add(const LoadPollsRequested());
    _streamBloc = InjectionContainer.sl<StreamBloc>()
      ..add(const LoadStreamsRequested());
  }

  @override
  void dispose() {
    _newsBloc.close();
    _pollsBloc.close();
    _streamBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NewsBloc>.value(value: _newsBloc),
        BlocProvider<PollsBloc>.value(value: _pollsBloc),
        BlocProvider<StreamBloc>.value(value: _streamBloc),
      ],
      child: widget.child,
    );
  }
}

class _StandaloneAuthScope extends StatefulWidget {
  const _StandaloneAuthScope({required this.child});

  final Widget child;

  @override
  State<_StandaloneAuthScope> createState() => _StandaloneAuthScopeState();
}

class _StandaloneAuthScopeState extends State<_StandaloneAuthScope> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = InjectionContainer.sl<AuthBloc>()
      ..add(const AuthSessionCheckedRequested());
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(value: _authBloc, child: widget.child);
  }
}
