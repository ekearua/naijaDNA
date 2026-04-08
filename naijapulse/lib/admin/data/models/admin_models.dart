import 'package:naijapulse/core/utils/backend_time.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/data/models/homepage_content_model.dart';
import 'package:naijapulse/features/news/data/models/reported_comment_model.dart';
import 'package:naijapulse/features/notifications/data/models/app_notification_model.dart';

class AdminSourceModel {
  const AdminSourceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.enabled,
    required this.requiresApiKey,
    required this.configured,
    required this.pollIntervalSeconds,
    this.country,
    this.feedUrl,
    this.apiBaseUrl,
    this.lastRunAt,
    this.notes,
  });

  final String id;
  final String name;
  final String type;
  final String? country;
  final bool enabled;
  final bool requiresApiKey;
  final bool configured;
  final String? feedUrl;
  final String? apiBaseUrl;
  final int pollIntervalSeconds;
  final DateTime? lastRunAt;
  final String? notes;

  factory AdminSourceModel.fromJson(Map<String, dynamic> json) =>
      AdminSourceModel(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        country: json['country'] as String?,
        enabled: json['enabled'] == true,
        requiresApiKey: json['requires_api_key'] == true,
        configured: json['configured'] == true,
        feedUrl: json['feed_url'] as String?,
        apiBaseUrl: json['api_base_url'] as String?,
        pollIntervalSeconds: ((json['poll_interval_sec'] as num?) ?? 900)
            .toInt(),
        lastRunAt: parseBackendDateTimeOrNull(json['last_run_at']),
        notes: json['notes'] as String?,
      );
}

class AdminArticleListPageModel {
  const AdminArticleListPageModel({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<NewsArticleModel> items;
  final int total;
  final int offset;
  final int limit;

  factory AdminArticleListPageModel.fromJson(Map<String, dynamic> json) =>
      AdminArticleListPageModel(
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(NewsArticleModel.fromJson)
            .toList(),
        total: ((json['total'] as num?) ?? 0).toInt(),
        offset: ((json['offset'] as num?) ?? 0).toInt(),
        limit: ((json['limit'] as num?) ?? 0).toInt(),
      );
}

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.isActive,
    required this.role,
    required this.streamAccessGranted,
    required this.streamHostingGranted,
    required this.contributionAccessGranted,
    required this.createdAt,
    required this.updatedAt,
    required this.submittedArticleCount,
    required this.publishedArticleCount,
    required this.commentCount,
    required this.reportCount,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool isActive;
  final String role;
  final bool streamAccessGranted;
  final bool streamHostingGranted;
  final bool contributionAccessGranted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int submittedArticleCount;
  final int publishedArticleCount;
  final int commentCount;
  final int reportCount;

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final user =
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AdminUserModel(
      id: (user['id'] as String?) ?? '',
      email: user['email'] as String?,
      displayName: user['display_name'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      isActive: user['is_active'] == true,
      role: (user['role'] as String?) ?? 'user',
      streamAccessGranted: user['stream_access_granted'] == true,
      streamHostingGranted: user['stream_hosting_granted'] == true,
      contributionAccessGranted: user['contribution_access_granted'] == true,
      createdAt: parseBackendDateTime(user['created_at']),
      updatedAt: parseBackendDateTime(user['updated_at']),
      submittedArticleCount: ((json['submitted_article_count'] as num?) ?? 0)
          .toInt(),
      publishedArticleCount: ((json['published_article_count'] as num?) ?? 0)
          .toInt(),
      commentCount: ((json['comment_count'] as num?) ?? 0).toInt(),
      reportCount: ((json['report_count'] as num?) ?? 0).toInt(),
    );
  }
}

class AdminUserAccessRequestModel {
  const AdminUserAccessRequestModel({
    required this.id,
    required this.userId,
    required this.accessType,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    this.userEmail,
    this.userDisplayName,
    this.reviewNote,
    this.reviewedByUserId,
  });

  final String id;
  final String userId;
  final String? userEmail;
  final String? userDisplayName;
  final String accessType;
  final String status;
  final String reason;
  final String? reviewNote;
  final String? reviewedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminUserAccessRequestModel.fromJson(Map<String, dynamic> json) =>
      AdminUserAccessRequestModel(
        id: (json['id'] as String?) ?? '',
        userId: (json['user_id'] as String?) ?? '',
        userEmail: json['user_email'] as String?,
        userDisplayName: json['user_display_name'] as String?,
        accessType: (json['access_type'] as String?) ?? 'stream_access',
        status: (json['status'] as String?) ?? 'pending',
        reason: (json['reason'] as String?) ?? '',
        reviewNote: json['review_note'] as String?,
        reviewedByUserId: json['reviewed_by_user_id'] as String?,
        createdAt: parseBackendDateTime(json['created_at']),
        updatedAt: parseBackendDateTime(json['updated_at']),
      );
}

class AdminNewsroomAccessRequestModel {
  const AdminNewsroomAccessRequestModel({
    required this.id,
    required this.fullName,
    required this.workEmail,
    required this.requestedRole,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    this.bureau,
    this.reviewNote,
    this.reviewedByUserId,
    this.grantedUserId,
  });

  final String id;
  final String fullName;
  final String workEmail;
  final String requestedRole;
  final String? bureau;
  final String status;
  final String reason;
  final String? reviewNote;
  final String? reviewedByUserId;
  final String? grantedUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminNewsroomAccessRequestModel.fromJson(Map<String, dynamic> json) =>
      AdminNewsroomAccessRequestModel(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        workEmail: (json['work_email'] as String?) ?? '',
        requestedRole: (json['requested_role'] as String?) ?? '',
        bureau: json['bureau'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        reason: (json['reason'] as String?) ?? '',
        reviewNote: json['review_note'] as String?,
        reviewedByUserId: json['reviewed_by_user_id'] as String?,
        grantedUserId: json['granted_user_id'] as String?,
        createdAt: parseBackendDateTime(json['created_at']),
        updatedAt: parseBackendDateTime(json['updated_at']),
      );
}

class AdminVerificationDeskModel {
  const AdminVerificationDeskModel({
    required this.items,
    required this.total,
    required this.unverifiedCount,
    required this.developingCount,
    required this.verifiedCount,
    required this.factCheckedCount,
    required this.opinionCount,
    required this.sponsoredCount,
  });

  final List<NewsArticleModel> items;
  final int total;
  final int unverifiedCount;
  final int developingCount;
  final int verifiedCount;
  final int factCheckedCount;
  final int opinionCount;
  final int sponsoredCount;

  factory AdminVerificationDeskModel.fromJson(Map<String, dynamic> json) {
    final counts =
        (json['counts'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AdminVerificationDeskModel(
      items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(NewsArticleModel.fromJson)
          .toList(),
      total: ((json['total'] as num?) ?? 0).toInt(),
      unverifiedCount: ((counts['unverified'] as num?) ?? 0).toInt(),
      developingCount: ((counts['developing'] as num?) ?? 0).toInt(),
      verifiedCount: ((counts['verified'] as num?) ?? 0).toInt(),
      factCheckedCount: ((counts['fact_checked'] as num?) ?? 0).toInt(),
      opinionCount: ((counts['opinion'] as num?) ?? 0).toInt(),
      sponsoredCount: ((counts['sponsored'] as num?) ?? 0).toInt(),
    );
  }
}

class AdminKpiModel {
  const AdminKpiModel({
    required this.key,
    required this.label,
    required this.value,
    required this.tone,
  });

  final String key;
  final String label;
  final int value;
  final String tone;

  factory AdminKpiModel.fromJson(Map<String, dynamic> json) => AdminKpiModel(
    key: (json['key'] as String?) ?? '',
    label: (json['label'] as String?) ?? '',
    value: ((json['value'] as num?) ?? 0).toInt(),
    tone: (json['tone'] as String?) ?? 'neutral',
  );
}

class AdminEditorialQueueModel {
  const AdminEditorialQueueModel({
    required this.submitted,
    required this.approved,
    required this.rejected,
    required this.scheduled,
  });

  final int submitted;
  final int approved;
  final int rejected;
  final int scheduled;

  factory AdminEditorialQueueModel.fromJson(Map<String, dynamic> json) =>
      AdminEditorialQueueModel(
        submitted: ((json['submitted'] as num?) ?? 0).toInt(),
        approved: ((json['approved'] as num?) ?? 0).toInt(),
        rejected: ((json['rejected'] as num?) ?? 0).toInt(),
        scheduled: ((json['scheduled'] as num?) ?? 0).toInt(),
      );
}

class AdminWorkflowActivityModel {
  const AdminWorkflowActivityModel({
    required this.eventId,
    required this.articleId,
    required this.articleTitle,
    required this.actorName,
    required this.eventType,
    required this.createdAt,
    this.actorUserId,
    this.fromStatus,
    this.toStatus,
    this.notes,
  });

  final int eventId;
  final String articleId;
  final String articleTitle;
  final String actorName;
  final String eventType;
  final DateTime createdAt;
  final String? actorUserId;
  final String? fromStatus;
  final String? toStatus;
  final String? notes;

  factory AdminWorkflowActivityModel.fromJson(Map<String, dynamic> json) =>
      AdminWorkflowActivityModel(
        eventId: ((json['event_id'] as num?) ?? 0).toInt(),
        articleId: (json['article_id'] as String?) ?? '',
        articleTitle: (json['article_title'] as String?) ?? '',
        actorName: (json['actor_name'] as String?) ?? 'System',
        eventType: (json['event_type'] as String?) ?? '',
        createdAt: parseBackendDateTime(json['created_at']),
        actorUserId: json['actor_user_id'] as String?,
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        notes: json['notes'] as String?,
      );
}

class AdminSourceHealthModel {
  const AdminSourceHealthModel({
    required this.sourceId,
    required this.sourceName,
    required this.status,
    required this.configured,
    required this.enabled,
    required this.fetched,
    required this.inserted,
    required this.deduped,
    this.lastRunAt,
    this.lastError,
  });

  final String sourceId;
  final String sourceName;
  final String status;
  final bool configured;
  final bool enabled;
  final int fetched;
  final int inserted;
  final int deduped;
  final DateTime? lastRunAt;
  final String? lastError;

  factory AdminSourceHealthModel.fromJson(Map<String, dynamic> json) =>
      AdminSourceHealthModel(
        sourceId: (json['source_id'] as String?) ?? '',
        sourceName: (json['source_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'idle',
        configured: json['configured'] == true,
        enabled: json['enabled'] == true,
        fetched: ((json['fetched'] as num?) ?? 0).toInt(),
        inserted: ((json['inserted'] as num?) ?? 0).toInt(),
        deduped: ((json['deduped'] as num?) ?? 0).toInt(),
        lastRunAt: parseBackendDateTimeOrNull(json['last_run_at']),
        lastError: json['last_error'] as String?,
      );
}

class AdminDashboardSummaryModel {
  const AdminDashboardSummaryModel({
    required this.generatedAt,
    required this.kpis,
    required this.editorialQueue,
    required this.recentWorkflowActivity,
    required this.reportedComments,
    required this.sourceHealth,
  });

  final DateTime generatedAt;
  final List<AdminKpiModel> kpis;
  final AdminEditorialQueueModel editorialQueue;
  final List<AdminWorkflowActivityModel> recentWorkflowActivity;
  final List<ReportedCommentModel> reportedComments;
  final List<AdminSourceHealthModel> sourceHealth;

  factory AdminDashboardSummaryModel.fromJson(Map<String, dynamic> json) =>
      AdminDashboardSummaryModel(
        generatedAt: parseBackendDateTime(json['generated_at']),
        kpis: ((json['kpis'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminKpiModel.fromJson)
            .toList(),
        editorialQueue: AdminEditorialQueueModel.fromJson(
          (json['editorial_queue'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        ),
        recentWorkflowActivity:
            ((json['recent_workflow_activity'] as List<dynamic>?) ??
                    const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(AdminWorkflowActivityModel.fromJson)
                .toList(),
        reportedComments:
            ((json['reported_comments'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(ReportedCommentModel.fromJson)
                .toList(),
        sourceHealth:
            ((json['source_health'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(AdminSourceHealthModel.fromJson)
                .toList(),
      );
}

class AdminArticleDetailModel {
  const AdminArticleDetailModel({
    required this.article,
    required this.workflowEvents,
    required this.relatedNotifications,
    required this.reportedCommentCount,
    required this.totalCommentCount,
  });

  final NewsArticleModel article;
  final List<AdminWorkflowActivityModel> workflowEvents;
  final List<AppNotificationModel> relatedNotifications;
  final int reportedCommentCount;
  final int totalCommentCount;

  factory AdminArticleDetailModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminArticleDetailModel(
    article: NewsArticleModel.fromJson(
      (json['article'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    workflowEvents:
        ((json['workflow_events'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminWorkflowActivityModel.fromJson)
            .toList(),
    relatedNotifications:
        ((json['related_notifications'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AppNotificationModel.fromJson)
            .toList(),
    reportedCommentCount: ((json['reported_comment_count'] as num?) ?? 0)
        .toInt(),
    totalCommentCount: ((json['total_comment_count'] as num?) ?? 0).toInt(),
  );
}

class AdminIngestionRunSourceModel {
  const AdminIngestionRunSourceModel({
    required this.sourceId,
    required this.sourceName,
    required this.status,
    required this.fetched,
    required this.inserted,
    required this.deduped,
    required this.errors,
  });

  final String sourceId;
  final String sourceName;
  final String status;
  final int fetched;
  final int inserted;
  final int deduped;
  final List<String> errors;

  factory AdminIngestionRunSourceModel.fromJson(Map<String, dynamic> json) =>
      AdminIngestionRunSourceModel(
        sourceId: (json['source_id'] as String?) ?? '',
        sourceName: (json['source_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? '',
        fetched: ((json['fetched'] as num?) ?? 0).toInt(),
        inserted: ((json['inserted'] as num?) ?? 0).toInt(),
        deduped: ((json['deduped'] as num?) ?? 0).toInt(),
        errors: ((json['errors'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => '$item')
            .toList(),
      );
}

class AdminIngestionRunModel {
  const AdminIngestionRunModel({
    required this.runId,
    required this.triggeredBy,
    required this.startedAt,
    required this.status,
    required this.fetchedCount,
    required this.insertedCount,
    required this.dedupedCount,
    required this.errorCount,
    required this.sources,
    this.finishedAt,
  });

  final String runId;
  final String triggeredBy;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  final int fetchedCount;
  final int insertedCount;
  final int dedupedCount;
  final int errorCount;
  final List<AdminIngestionRunSourceModel> sources;

  factory AdminIngestionRunModel.fromJson(Map<String, dynamic> json) =>
      AdminIngestionRunModel(
        runId: (json['run_id'] as String?) ?? '',
        triggeredBy: (json['triggered_by'] as String?) ?? '',
        startedAt: parseBackendDateTime(json['started_at']),
        finishedAt: parseBackendDateTimeOrNull(json['finished_at']),
        status: (json['status'] as String?) ?? '',
        fetchedCount: ((json['fetched_count'] as num?) ?? 0).toInt(),
        insertedCount: ((json['inserted_count'] as num?) ?? 0).toInt(),
        dedupedCount: ((json['deduped_count'] as num?) ?? 0).toInt(),
        errorCount: ((json['error_count'] as num?) ?? 0).toInt(),
        sources: ((json['sources'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminIngestionRunSourceModel.fromJson)
            .toList(),
      );
}

class AdminIngestionStatusModel {
  const AdminIngestionStatusModel({
    required this.running,
    required this.totalSources,
    required this.activeSources,
    required this.recentRuns,
    this.lastRun,
  });

  final bool running;
  final int totalSources;
  final int activeSources;
  final AdminIngestionRunModel? lastRun;
  final List<AdminIngestionRunModel> recentRuns;

  factory AdminIngestionStatusModel.fromJson(Map<String, dynamic> json) =>
      AdminIngestionStatusModel(
        running: json['running'] == true,
        totalSources: ((json['total_sources'] as num?) ?? 0).toInt(),
        activeSources: ((json['active_sources'] as num?) ?? 0).toInt(),
        lastRun: json['last_run'] is Map<String, dynamic>
            ? AdminIngestionRunModel.fromJson(
                json['last_run'] as Map<String, dynamic>,
              )
            : null,
        recentRuns:
            ((json['recent_runs'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(AdminIngestionRunModel.fromJson)
                .toList(),
      );
}

class AdminCacheNamespaceModel {
  const AdminCacheNamespaceModel({
    required this.namespace,
    required this.version,
  });

  final String namespace;
  final int version;

  factory AdminCacheNamespaceModel.fromJson(Map<String, dynamic> json) =>
      AdminCacheNamespaceModel(
        namespace: (json['namespace'] as String?) ?? '',
        version: ((json['version'] as num?) ?? 1).toInt(),
      );
}

class AdminCacheDiagnosticsModel {
  const AdminCacheDiagnosticsModel({
    required this.generatedAt,
    required this.enabled,
    required this.configured,
    required this.clientReady,
    required this.newsTopTtlSeconds,
    required this.newsLatestTtlSeconds,
    required this.pollsActiveTtlSeconds,
    required this.categoriesTtlSeconds,
    required this.tagsTtlSeconds,
    required this.readCount,
    required this.hitCount,
    required this.missCount,
    required this.writeCount,
    required this.errorCount,
    required this.namespaces,
    required this.ingestion,
    required this.schedulerEnabled,
    required this.ingestionIntervalSeconds,
    required this.startupIngestionEnabled,
    this.lastErrorAt,
    this.lastErrorMessage,
  });

  final DateTime generatedAt;
  final bool enabled;
  final bool configured;
  final bool clientReady;
  final int newsTopTtlSeconds;
  final int newsLatestTtlSeconds;
  final int pollsActiveTtlSeconds;
  final int categoriesTtlSeconds;
  final int tagsTtlSeconds;
  final int readCount;
  final int hitCount;
  final int missCount;
  final int writeCount;
  final int errorCount;
  final DateTime? lastErrorAt;
  final String? lastErrorMessage;
  final List<AdminCacheNamespaceModel> namespaces;
  final AdminIngestionStatusModel ingestion;
  final bool schedulerEnabled;
  final int ingestionIntervalSeconds;
  final bool startupIngestionEnabled;

  factory AdminCacheDiagnosticsModel.fromJson(Map<String, dynamic> json) {
    final cache =
        (json['cache'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return AdminCacheDiagnosticsModel(
      generatedAt: parseBackendDateTime(json['generated_at']),
      enabled: cache['enabled'] == true,
      configured: cache['configured'] == true,
      clientReady: cache['client_ready'] == true,
      newsTopTtlSeconds: ((cache['news_top_ttl_seconds'] as num?) ?? 0).toInt(),
      newsLatestTtlSeconds: ((cache['news_latest_ttl_seconds'] as num?) ?? 0)
          .toInt(),
      pollsActiveTtlSeconds: ((cache['polls_active_ttl_seconds'] as num?) ?? 0)
          .toInt(),
      categoriesTtlSeconds: ((cache['categories_ttl_seconds'] as num?) ?? 0)
          .toInt(),
      tagsTtlSeconds: ((cache['tags_ttl_seconds'] as num?) ?? 0).toInt(),
      readCount: ((cache['read_count'] as num?) ?? 0).toInt(),
      hitCount: ((cache['hit_count'] as num?) ?? 0).toInt(),
      missCount: ((cache['miss_count'] as num?) ?? 0).toInt(),
      writeCount: ((cache['write_count'] as num?) ?? 0).toInt(),
      errorCount: ((cache['error_count'] as num?) ?? 0).toInt(),
      lastErrorAt: parseBackendDateTimeOrNull(cache['last_error_at']),
      lastErrorMessage: cache['last_error_message'] as String?,
      namespaces: ((cache['namespaces'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AdminCacheNamespaceModel.fromJson)
          .toList(),
      ingestion: AdminIngestionStatusModel.fromJson(
        (json['ingestion'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      schedulerEnabled: json['scheduler_enabled'] == true,
      ingestionIntervalSeconds:
          ((json['ingestion_interval_seconds'] as num?) ?? 0).toInt(),
      startupIngestionEnabled: json['startup_ingestion_enabled'] == true,
    );
  }
}

class AdminAnalyticsMetricModel {
  const AdminAnalyticsMetricModel({required this.label, required this.value});

  final String label;
  final int value;

  factory AdminAnalyticsMetricModel.fromJson(Map<String, dynamic> json) =>
      AdminAnalyticsMetricModel(
        label: (json['label'] as String?) ?? '',
        value: ((json['value'] as num?) ?? 0).toInt(),
      );
}

class AdminAnalyticsArticleModel {
  const AdminAnalyticsArticleModel({
    required this.articleId,
    required this.title,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.engagementCount,
    required this.commentCount,
  });

  final String articleId;
  final String title;
  final String source;
  final String category;
  final DateTime publishedAt;
  final int engagementCount;
  final int commentCount;

  factory AdminAnalyticsArticleModel.fromJson(Map<String, dynamic> json) =>
      AdminAnalyticsArticleModel(
        articleId: (json['article_id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        source: (json['source'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        publishedAt: parseBackendDateTime(json['published_at']),
        engagementCount: ((json['engagement_count'] as num?) ?? 0).toInt(),
        commentCount: ((json['comment_count'] as num?) ?? 0).toInt(),
      );
}

class AdminAnalyticsSourceModel {
  const AdminAnalyticsSourceModel({
    required this.source,
    required this.articleCount,
    required this.publishedCount,
    required this.commentCount,
  });

  final String source;
  final int articleCount;
  final int publishedCount;
  final int commentCount;

  factory AdminAnalyticsSourceModel.fromJson(Map<String, dynamic> json) =>
      AdminAnalyticsSourceModel(
        source: (json['source'] as String?) ?? '',
        articleCount: ((json['article_count'] as num?) ?? 0).toInt(),
        publishedCount: ((json['published_count'] as num?) ?? 0).toInt(),
        commentCount: ((json['comment_count'] as num?) ?? 0).toInt(),
      );
}

class AdminAnalyticsOverviewModel {
  const AdminAnalyticsOverviewModel({
    required this.generatedAt,
    required this.windowDays,
    required this.headlineMetrics,
    required this.articleStatusBreakdown,
    required this.verificationBreakdown,
    required this.topArticles,
    required this.topSources,
  });

  final DateTime generatedAt;
  final int windowDays;
  final List<AdminAnalyticsMetricModel> headlineMetrics;
  final List<AdminAnalyticsMetricModel> articleStatusBreakdown;
  final List<AdminAnalyticsMetricModel> verificationBreakdown;
  final List<AdminAnalyticsArticleModel> topArticles;
  final List<AdminAnalyticsSourceModel> topSources;

  factory AdminAnalyticsOverviewModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminAnalyticsOverviewModel(
    generatedAt: parseBackendDateTime(json['generated_at']),
    windowDays: ((json['window_days'] as num?) ?? 30).toInt(),
    headlineMetrics:
        ((json['headline_metrics'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminAnalyticsMetricModel.fromJson)
            .toList(),
    articleStatusBreakdown:
        ((json['article_status_breakdown'] as List<dynamic>?) ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminAnalyticsMetricModel.fromJson)
            .toList(),
    verificationBreakdown:
        ((json['verification_breakdown'] as List<dynamic>?) ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminAnalyticsMetricModel.fromJson)
            .toList(),
    topArticles: ((json['top_articles'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminAnalyticsArticleModel.fromJson)
        .toList(),
    topSources: ((json['top_sources'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminAnalyticsSourceModel.fromJson)
        .toList(),
  );
}

class AdminHomepageCategoryConfigModel {
  const AdminHomepageCategoryConfigModel({
    required this.key,
    required this.label,
    required this.position,
    required this.enabled,
    this.colorHex,
  });

  final String key;
  final String label;
  final String? colorHex;
  final int position;
  final bool enabled;

  factory AdminHomepageCategoryConfigModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminHomepageCategoryConfigModel(
    key: (json['key'] as String?) ?? '',
    label: (json['label'] as String?) ?? '',
    colorHex: json['color_hex'] as String?,
    position: ((json['position'] as num?) ?? 0).toInt(),
    enabled: json['enabled'] != false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'color_hex': colorHex,
    'position': position,
    'enabled': enabled,
  };

  AdminHomepageCategoryConfigModel copyWith({
    String? key,
    String? label,
    String? colorHex,
    int? position,
    bool? enabled,
  }) => AdminHomepageCategoryConfigModel(
    key: key ?? this.key,
    label: label ?? this.label,
    colorHex: colorHex ?? this.colorHex,
    position: position ?? this.position,
    enabled: enabled ?? this.enabled,
  );
}

class AdminHomepageSecondaryChipConfigModel {
  const AdminHomepageSecondaryChipConfigModel({
    required this.key,
    required this.label,
    required this.chipType,
    required this.position,
    required this.enabled,
    this.colorHex,
  });

  final String key;
  final String label;
  final String chipType;
  final String? colorHex;
  final int position;
  final bool enabled;

  factory AdminHomepageSecondaryChipConfigModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminHomepageSecondaryChipConfigModel(
    key: (json['key'] as String?) ?? '',
    label: (json['label'] as String?) ?? '',
    chipType: (json['chip_type'] as String?) ?? 'tag',
    colorHex: json['color_hex'] as String?,
    position: ((json['position'] as num?) ?? 0).toInt(),
    enabled: json['enabled'] != false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
    'chip_type': chipType,
    'color_hex': colorHex,
    'position': position,
    'enabled': enabled,
  };

  AdminHomepageSecondaryChipConfigModel copyWith({
    String? key,
    String? label,
    String? chipType,
    String? colorHex,
    int? position,
    bool? enabled,
  }) => AdminHomepageSecondaryChipConfigModel(
    key: key ?? this.key,
    label: label ?? this.label,
    chipType: chipType ?? this.chipType,
    colorHex: colorHex ?? this.colorHex,
    position: position ?? this.position,
    enabled: enabled ?? this.enabled,
  );
}

class AdminHomepagePlacementItemModel {
  const AdminHomepagePlacementItemModel({
    required this.articleId,
    required this.section,
    required this.position,
    required this.enabled,
    this.targetKey,
  });

  final String articleId;
  final String section;
  final String? targetKey;
  final int position;
  final bool enabled;

  factory AdminHomepagePlacementItemModel.fromJson(Map<String, dynamic> json) =>
      AdminHomepagePlacementItemModel(
        articleId: (json['article_id'] as String?) ?? '',
        section: (json['section'] as String?) ?? '',
        targetKey: json['target_key'] as String?,
        position: ((json['position'] as num?) ?? 0).toInt(),
        enabled: json['enabled'] != false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'article_id': articleId,
    'section': section,
    'target_key': targetKey,
    'position': position,
    'enabled': enabled,
  };

  AdminHomepagePlacementItemModel copyWith({
    String? articleId,
    String? section,
    String? targetKey,
    int? position,
    bool? enabled,
  }) => AdminHomepagePlacementItemModel(
    articleId: articleId ?? this.articleId,
    section: section ?? this.section,
    targetKey: targetKey ?? this.targetKey,
    position: position ?? this.position,
    enabled: enabled ?? this.enabled,
  );
}

class AdminHomepagePlacementDetailModel {
  const AdminHomepagePlacementDetailModel({
    required this.article,
    required this.section,
    required this.position,
    required this.enabled,
    this.targetKey,
  });

  final NewsArticleModel article;
  final String section;
  final String? targetKey;
  final int position;
  final bool enabled;

  factory AdminHomepagePlacementDetailModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminHomepagePlacementDetailModel(
    article: NewsArticleModel.fromJson(
      (json['article'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    section: (json['section'] as String?) ?? '',
    targetKey: json['target_key'] as String?,
    position: ((json['position'] as num?) ?? 0).toInt(),
    enabled: json['enabled'] != false,
  );

  AdminHomepagePlacementItemModel toPatchItem({int? positionOverride}) =>
      AdminHomepagePlacementItemModel(
        articleId: article.id,
        section: section,
        targetKey: targetKey,
        position: positionOverride ?? position,
        enabled: enabled,
      );
}

class AdminHomepageSettingsModel {
  const AdminHomepageSettingsModel({
    required this.latestAutofillEnabled,
    required this.latestItemLimit,
    required this.latestWindowHours,
    required this.latestFallbackWindowHours,
    required this.directGnewsTopPublishEnabled,
    required this.categoryAutofillEnabled,
    required this.categoryWindowHours,
  });

  final bool latestAutofillEnabled;
  final int latestItemLimit;
  final int latestWindowHours;
  final int latestFallbackWindowHours;
  final bool directGnewsTopPublishEnabled;
  final bool categoryAutofillEnabled;
  final int categoryWindowHours;

  factory AdminHomepageSettingsModel.fromJson(Map<String, dynamic> json) =>
      AdminHomepageSettingsModel(
        latestAutofillEnabled: json['latest_autofill_enabled'] != false,
        latestItemLimit: ((json['latest_item_limit'] as num?) ?? 20).toInt(),
        latestWindowHours: ((json['latest_window_hours'] as num?) ?? 6).toInt(),
        latestFallbackWindowHours:
            ((json['latest_fallback_window_hours'] as num?) ?? 24).toInt(),
        directGnewsTopPublishEnabled:
            json['direct_gnews_top_publish_enabled'] == true,
        categoryAutofillEnabled: json['category_autofill_enabled'] == true,
        categoryWindowHours:
            ((json['category_window_hours'] as num?) ?? 12).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'latest_autofill_enabled': latestAutofillEnabled,
    'latest_item_limit': latestItemLimit,
    'latest_window_hours': latestWindowHours,
    'latest_fallback_window_hours': latestFallbackWindowHours,
    'direct_gnews_top_publish_enabled': directGnewsTopPublishEnabled,
    'category_autofill_enabled': categoryAutofillEnabled,
    'category_window_hours': categoryWindowHours,
  };
}

class AdminHomepageConfigModel {
  const AdminHomepageConfigModel({
    required this.generatedAt,
    required this.settings,
    required this.categories,
    required this.secondaryChips,
    required this.topStories,
    required this.latestStories,
    required this.categorySections,
    required this.secondaryChipSections,
  });

  final DateTime generatedAt;
  final AdminHomepageSettingsModel settings;
  final List<AdminHomepageCategoryConfigModel> categories;
  final List<AdminHomepageSecondaryChipConfigModel> secondaryChips;
  final List<AdminHomepagePlacementDetailModel> topStories;
  final List<AdminHomepagePlacementDetailModel> latestStories;
  final List<HomepageCategoryFeedModel> categorySections;
  final List<HomepageSecondaryChipFeedModel> secondaryChipSections;

  factory AdminHomepageConfigModel.fromJson(
    Map<String, dynamic> json,
  ) => AdminHomepageConfigModel(
    generatedAt: parseBackendDateTime(json['generated_at']),
    settings: AdminHomepageSettingsModel.fromJson(
      (json['settings'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    categories: ((json['categories'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminHomepageCategoryConfigModel.fromJson)
        .toList(),
    secondaryChips:
        ((json['secondary_chips'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminHomepageSecondaryChipConfigModel.fromJson)
            .toList(),
    topStories: ((json['top_stories'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdminHomepagePlacementDetailModel.fromJson)
        .toList(),
    latestStories:
        ((json['latest_stories'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AdminHomepagePlacementDetailModel.fromJson)
            .toList(),
    categorySections:
        ((json['category_sections'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(HomepageCategoryFeedModel.fromJson)
            .toList(),
    secondaryChipSections:
        ((json['secondary_chip_sections'] as List<dynamic>?) ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(HomepageSecondaryChipFeedModel.fromJson)
            .toList(),
  );
}
