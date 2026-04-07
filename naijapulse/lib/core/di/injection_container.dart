import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/core/connectivity/connectivity_cubit.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/core/network/api_config.dart';
import 'package:naijapulse/core/services/article_tts_service.dart';
import 'package:naijapulse/core/storage/app_database.dart';
import 'package:naijapulse/core/sync/poll_vote_outbox_local_data_source.dart';
import 'package:naijapulse/core/sync/poll_vote_replay_service.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/auth/data/datasource/remote/auth_remote_datasource.dart';
import 'package:naijapulse/features/auth/data/repository/auth_repository_impl.dart';
import 'package:naijapulse/features/auth/domain/repository/auth_repository.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/login_user.dart';
import 'package:naijapulse/features/auth/domain/usecases/logout_user.dart';
import 'package:naijapulse/features/auth/domain/usecases/register_user.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:naijapulse/features/live_updates/data/datasource/remote/live_updates_remote_datasource.dart';
import 'package:naijapulse/features/news/data/datasource/local/news_local_datasource.dart';
import 'package:naijapulse/features/news/data/datasource/local/saved_story_local_datasource.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/data/repository/news_repository_impl.dart';
import 'package:naijapulse/features/news/domain/repository/news_repository.dart';
import 'package:naijapulse/features/news/domain/usecases/get_latest_stories.dart';
import 'package:naijapulse/features/news/domain/usecases/get_top_stories.dart';
import 'package:naijapulse/features/news/domain/usecases/record_story_opened.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/notifications/data/notification_action_service.dart';
import 'package:naijapulse/features/notifications/data/push_notifications_service.dart';
import 'package:naijapulse/features/notifications/data/notifications_inbox_controller.dart';
import 'package:naijapulse/features/notifications/data/datasource/remote/notifications_remote_datasource.dart';
import 'package:naijapulse/features/polls/data/datasource/local/polls_local_datasource.dart';
import 'package:naijapulse/features/polls/data/datasource/remote/polls_remote_datasource.dart';
import 'package:naijapulse/features/polls/data/repository/polls_repository_impl.dart';
import 'package:naijapulse/features/polls/domain/repository/polls_repository.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_active_polls.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_categories.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_feed_tags.dart';
import 'package:naijapulse/features/polls/domain/usecases/submit_poll_vote.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';
import 'package:naijapulse/features/stream/data/datasource/local/stream_local_datasource.dart';
import 'package:naijapulse/features/stream/data/datasource/remote/stream_remote_datasource.dart';
import 'package:naijapulse/features/stream/data/repository/stream_repository_impl.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';
import 'package:naijapulse/features/stream/domain/usecases/create_live_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/end_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_live_streams.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_livekit_connection.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_stream_comments.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_scheduled_streams.dart';
import 'package:naijapulse/features/stream/domain/usecases/get_stream_session.dart';
import 'package:naijapulse/features/stream/domain/usecases/schedule_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/send_stream_comment.dart';
import 'package:naijapulse/features/stream/domain/usecases/start_stream.dart';
import 'package:naijapulse/features/stream/domain/usecases/update_stream_presence.dart';
import 'package:naijapulse/features/stream/presentation/bloc/stream_bloc.dart';
import 'package:naijapulse/features/user/data/datasource/remote/user_preferences_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InjectionContainer {
  const InjectionContainer._();

  static final GetIt sl = GetIt.instance;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

    // Data sources
    sl.registerLazySingleton<AppDatabase>(
      AppDatabase.new,
      dispose: (db) => db.close(),
    );
    sl.registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: _buildDefaultHeaders(),
        ),
      ),
    );
    sl.registerLazySingleton<ApiClient>(() => ApiClient(dio: sl<Dio>()));
    sl.registerLazySingleton<ArticleTtsService>(
      ArticleTtsService.new,
      dispose: (service) => service.dispose(),
    );

    // Data sources - auth
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
    );
    sl.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
    );
    sl.registerLazySingleton<AuthSessionController>(
      () => AuthSessionController(
        localDataSource: sl<AuthLocalDataSource>(),
        remoteDataSource: sl<AuthRemoteDataSource>(),
      ),
    );

    // Repositories - auth
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl<AuthRemoteDataSource>(),
        localDataSource: sl<AuthLocalDataSource>(),
        authSessionController: sl<AuthSessionController>(),
      ),
    );

    // Use cases - auth
    sl.registerLazySingleton<GetCachedSession>(
      () => GetCachedSession(sl<AuthRepository>()),
    );
    sl.registerLazySingleton<LoginUser>(() => LoginUser(sl<AuthRepository>()));
    sl.registerLazySingleton<RegisterUser>(
      () => RegisterUser(sl<AuthRepository>()),
    );
    sl.registerLazySingleton<LogoutUser>(
      () => LogoutUser(sl<AuthRepository>()),
    );

    // Presentation - auth
    sl.registerFactory<AuthBloc>(
      () => AuthBloc(
        getCachedSession: sl<GetCachedSession>(),
        loginUser: sl<LoginUser>(),
        registerUser: sl<RegisterUser>(),
        logoutUser: sl<LogoutUser>(),
      ),
    );

    await sl<AuthSessionController>().initialize();

    sl.registerLazySingleton<NewsRemoteDataSource>(
      () => NewsRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
      ),
    );
    sl.registerLazySingleton<NewsLocalDataSource>(
      () => NewsLocalDataSourceImpl(database: sl<AppDatabase>()),
    );
    sl.registerLazySingleton<SavedStoryLocalDataSource>(
      SavedStoryLocalDataSource.new,
    );

    // Repositories
    sl.registerLazySingleton<NewsRepository>(
      () => NewsRepositoryImpl(
        remoteDataSource: sl<NewsRemoteDataSource>(),
        localDataSource: sl<NewsLocalDataSource>(),
      ),
    );

    // Use cases
    sl.registerLazySingleton<GetTopStories>(
      () => GetTopStories(sl<NewsRepository>()),
    );
    sl.registerLazySingleton<GetLatestStories>(
      () => GetLatestStories(sl<NewsRepository>()),
    );
    sl.registerLazySingleton<RecordStoryOpened>(
      () => RecordStoryOpened(sl<NewsRepository>()),
    );

    // Presentation
    sl.registerFactory<NewsBloc>(
      () => NewsBloc(
        getTopStories: sl<GetTopStories>(),
        getLatestStories: sl<GetLatestStories>(),
        recordStoryOpened: sl<RecordStoryOpened>(),
      ),
    );

    // Data sources - streams
    sl.registerLazySingleton<StreamLocalDataSource>(
      () =>
          StreamLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
    );
    sl.registerLazySingleton<StreamRemoteDataSource>(
      () => StreamRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
        localDataSource: sl<StreamLocalDataSource>(),
      ),
    );

    // Repositories - streams
    sl.registerLazySingleton<StreamRepository>(
      () =>
          StreamRepositoryImpl(remoteDataSource: sl<StreamRemoteDataSource>()),
    );

    // Use cases - streams
    sl.registerLazySingleton<GetLiveStreams>(
      () => GetLiveStreams(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<GetScheduledStreams>(
      () => GetScheduledStreams(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<GetStreamSession>(
      () => GetStreamSession(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<GetStreamComments>(
      () => GetStreamComments(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<SendStreamComment>(
      () => SendStreamComment(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<GetLiveKitConnection>(
      () => GetLiveKitConnection(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<CreateLiveStream>(
      () => CreateLiveStream(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<ScheduleStream>(
      () => ScheduleStream(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<StartStream>(
      () => StartStream(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<EndStream>(
      () => EndStream(sl<StreamRepository>()),
    );
    sl.registerLazySingleton<UpdateStreamPresence>(
      () => UpdateStreamPresence(sl<StreamRepository>()),
    );

    // Presentation - streams
    sl.registerFactory<StreamBloc>(
      () => StreamBloc(
        getLiveStreams: sl<GetLiveStreams>(),
        getScheduledStreams: sl<GetScheduledStreams>(),
        getStreamSession: sl<GetStreamSession>(),
        createLiveStream: sl<CreateLiveStream>(),
        scheduleStream: sl<ScheduleStream>(),
        startStream: sl<StartStream>(),
        endStream: sl<EndStream>(),
        updateStreamPresence: sl<UpdateStreamPresence>(),
      ),
    );

    // Data sources - polls
    sl.registerLazySingleton<PollsRemoteDataSource>(
      () => PollsRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
    );
    sl.registerLazySingleton<PollsLocalDataSource>(
      () => PollsLocalDataSourceImpl(database: sl<AppDatabase>()),
    );
    sl.registerLazySingleton<PollVoteOutboxLocalDataSource>(
      () => PollVoteOutboxLocalDataSourceImpl(database: sl<AppDatabase>()),
    );

    // Repositories - polls
    sl.registerLazySingleton<PollsRepository>(
      () => PollsRepositoryImpl(
        remoteDataSource: sl<PollsRemoteDataSource>(),
        localDataSource: sl<PollsLocalDataSource>(),
        outboxLocalDataSource: sl<PollVoteOutboxLocalDataSource>(),
      ),
    );
    sl.registerLazySingleton<PollVoteReplayService>(
      () => PollVoteReplayService(
        outboxLocalDataSource: sl<PollVoteOutboxLocalDataSource>(),
        remoteDataSource: sl<PollsRemoteDataSource>(),
        localDataSource: sl<PollsLocalDataSource>(),
      ),
    );

    // Use cases - polls
    sl.registerLazySingleton<GetActivePolls>(
      () => GetActivePolls(sl<PollsRepository>()),
    );
    sl.registerLazySingleton<GetCategories>(
      () => GetCategories(sl<PollsRepository>()),
    );
    sl.registerLazySingleton<GetFeedTags>(
      () => GetFeedTags(sl<PollsRepository>()),
    );
    sl.registerLazySingleton<SubmitPollVote>(
      () => SubmitPollVote(sl<PollsRepository>()),
    );

    // Presentation - polls
    sl.registerFactory<PollsBloc>(
      () => PollsBloc(
        getActivePolls: sl<GetActivePolls>(),
        getCategories: sl<GetCategories>(),
        getFeedTags: sl<GetFeedTags>(),
        submitPollVote: sl<SubmitPollVote>(),
      ),
    );
    sl.registerLazySingleton<UserPreferencesRemoteDataSource>(
      () => UserPreferencesRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
    );
    sl.registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
      ),
    );
    sl.registerLazySingleton<NotificationsInboxController>(
      () => NotificationsInboxController(
        remoteDataSource: sl<NotificationsRemoteDataSource>(),
        authSessionController: sl<AuthSessionController>(),
      ),
    );
    sl.registerLazySingleton<NotificationActionService>(
      () => NotificationActionService(
        remoteDataSource: sl<NotificationsRemoteDataSource>(),
        inboxController: sl<NotificationsInboxController>(),
        authSessionController: sl<AuthSessionController>(),
      ),
    );
    if (_supportsPushNotifications) {
      sl.registerLazySingleton<FirebaseMessaging>(
        () => FirebaseMessaging.instance,
      );
      sl.registerLazySingleton<PushNotificationsService>(
        () => PushNotificationsService(
          messaging: sl<FirebaseMessaging>(),
          remoteDataSource: sl<NotificationsRemoteDataSource>(),
          notificationsInboxController: sl<NotificationsInboxController>(),
          notificationActionService: sl<NotificationActionService>(),
          authSessionController: sl<AuthSessionController>(),
          sharedPreferences: sl<SharedPreferences>(),
        ),
        dispose: (service) => service.dispose(),
      );
    }
    sl.registerLazySingleton<AdminRemoteDataSource>(
      () => AdminRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
      ),
    );
    sl.registerLazySingleton<LiveUpdatesRemoteDataSource>(
      () => LiveUpdatesRemoteDataSourceImpl(
        apiClient: sl<ApiClient>(),
        authLocalDataSource: sl<AuthLocalDataSource>(),
      ),
    );
    sl.registerLazySingleton<ConnectivityCubit>(ConnectivityCubit.new);

    await sl<NotificationsInboxController>().initialize();
    if (_supportsPushNotifications) {
      await sl<PushNotificationsService>().initialize();
    }

    _isInitialized = true;
  }

  static Future<void> reset() async {
    await sl.reset();
    _isInitialized = false;
  }

  static Map<String, String> _buildDefaultHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      // Prevent ngrok warning page from hijacking JSON responses in dev.
      'ngrok-skip-browser-warning': '1',
    };
    final deviceId = ApiConfig.deviceId;
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      headers['X-Device-Id'] = deviceId.trim();
    }
    return headers;
  }

  static bool get _supportsPushNotifications {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
