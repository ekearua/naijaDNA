import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/news/data/models/article_comment_model.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/data/models/reported_comment_model.dart';
import 'package:naijapulse/features/polls/data/models/poll_category_model.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

abstract class AdminRemoteDataSource {
  Future<AdminDashboardSummaryModel> fetchDashboardSummary();

  Future<AdminWorkflowActivityPageModel> fetchWorkflowActivityPage({
    String? actor,
    String? role,
    String? eventType,
    DateTime? dateFrom,
    DateTime? dateTo,
    int offset,
    int limit,
  });

  Future<AdminVerificationDeskModel> fetchVerificationDesk({
    String? verificationStatus,
    String? articleStatus,
    int limit,
  });

  Future<List<NewsArticleModel>> fetchAdminArticles({
    String? status,
    String? query,
    int limit,
  });

  Future<AdminArticleListPageModel> fetchAdminArticlesPage({
    String? status,
    List<String>? statuses,
    String? query,
    String? source,
    String? tag,
    DateTime? publishedFrom,
    DateTime? publishedTo,
    String? sort,
    int offset,
    int limit,
  });

  Future<AdminArticleQueueSettingsResponseModel> fetchArticleQueueSettings();

  Future<AdminArticleQueueSettingsResponseModel> updateArticleQueueSettings({
    required bool autoArchiveEnabled,
    required int archiveDraftAfterDays,
    required int archiveReviewAfterDays,
    required int archiveRejectedAfterDays,
  });

  Future<AdminArticleQueueArchiveRunResponseModel> runArticleQueueAutoArchive();

  Future<AdminArticleDetailModel> fetchAdminArticleDetail(String articleId);

  Future<NewsArticleModel> createAdminArticle({
    required String title,
    required String source,
    required String category,
    List<String> tags = const <String>[],
    String? summary,
    required String sourceUrl,
    String? imageUrl,
    required String status,
    required String verificationStatus,
    required bool isFeatured,
    String? reviewNotes,
  });

  Future<NewsArticleModel> updateAdminArticle({
    required String articleId,
    String? title,
    String? source,
    String? category,
    List<String>? tags,
    String? summary,
    String? sourceUrl,
    String? imageUrl,
    String? verificationStatus,
    bool? isFeatured,
    String? reviewNotes,
  });

  Future<NewsArticleModel> transitionAdminArticle({
    required String articleId,
    required String action,
    String? notes,
    String? targetStatus,
  });

  Future<List<ReportedCommentModel>> fetchReportedComments({int limit});

  Future<ArticleCommentModel> moderateComment({
    required int commentId,
    required String action,
    String? notes,
  });

  Future<List<AdminSourceModel>> fetchSources();

  Future<AdminSourceModel> createSource({
    required String id,
    required String name,
    required String type,
    String? country,
    bool enabled,
    String? feedUrl,
    String? apiBaseUrl,
    int pollIntervalSeconds,
    String? notes,
  });

  Future<AdminSourceModel> updateSource({
    required String sourceId,
    String? name,
    String? type,
    String? country,
    bool? enabled,
    bool? configured,
    String? feedUrl,
    String? apiBaseUrl,
    int? pollIntervalSeconds,
    String? notes,
  });

  Future<AdminIngestionRunModel> testSource(String sourceId);

  Future<AdminIngestionRunModel> runSource(String sourceId);

  Future<List<AdminUserModel>> fetchUsers({
    String? role,
    bool? isActive,
    int limit,
  });

  Future<AdminUserModel> updateUser({
    required String userId,
    String? displayName,
    String? avatarUrl,
    bool? isActive,
    String? role,
    bool? streamAccessGranted,
    bool? streamHostingGranted,
    bool? contributionAccessGranted,
  });

  Future<List<PollModel>> fetchActivePolls();

  Future<List<PollCategoryModel>> fetchPollCategories();

  Future<PollModel> createPoll({
    required String question,
    required DateTime endsAt,
    String? categoryId,
    required List<String> optionLabels,
  });

  Future<List<AdminUserAccessRequestModel>> fetchUserAccessRequests({
    String? status,
    int limit,
  });

  Future<List<AdminNewsroomAccessRequestModel>> fetchNewsroomAccessRequests({
    String? status,
    int limit,
  });

  Future<AdminUserAccessRequestModel> reviewUserAccessRequest({
    required String requestId,
    required String action,
    String? reviewNote,
  });

  Future<AdminNewsroomAccessRequestModel> reviewNewsroomAccessRequest({
    required String requestId,
    required String action,
    String? reviewNote,
  });

  Future<AdminIngestionStatusModel> fetchIngestionStatus();

  Future<AdminCacheDiagnosticsModel> fetchCacheDiagnostics();

  Future<AdminAnalyticsOverviewModel> fetchAnalyticsOverview({int days});

  Future<AdminHomepageConfigModel> fetchHomepageConfig();

  Future<AdminHomepageConfigModel> updateHomepageCategories(
    List<AdminHomepageCategoryConfigModel> items,
  );

  Future<AdminHomepageConfigModel> updateHomepageSecondaryChips(
    List<AdminHomepageSecondaryChipConfigModel> items,
  );

  Future<AdminHomepageConfigModel> updateHomepagePlacements(
    List<AdminHomepagePlacementItemModel> items,
  );

  Future<AdminHomepageConfigModel> updateHomepageSettings({
    required bool latestAutofillEnabled,
    required int latestItemLimit,
    required int latestWindowHours,
    required int latestFallbackWindowHours,
    required bool directGnewsTopPublishEnabled,
    required bool categoryAutofillEnabled,
    required int categoryWindowHours,
    required int staleGeneralHours,
    required int staleWorldHours,
    required int staleBusinessHours,
    required int staleTechnologyHours,
    required int staleEntertainmentHours,
    required int staleScienceHours,
    required int staleSportsHours,
    required int staleHealthHours,
    required int staleBreakingHours,
    required int staleOpinionHours,
  });
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  const AdminRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthLocalDataSource authLocalDataSource,
  }) : _apiClient = apiClient,
       _authLocalDataSource = authLocalDataSource;

  final ApiClient _apiClient;
  final AuthLocalDataSource _authLocalDataSource;

  @override
  Future<AdminDashboardSummaryModel> fetchDashboardSummary() async {
    final response = await _getAuthed('/admin/dashboard/summary');
    return AdminDashboardSummaryModel.fromJson(response);
  }

  @override
  Future<AdminWorkflowActivityPageModel> fetchWorkflowActivityPage({
    String? actor,
    String? role,
    String? eventType,
    DateTime? dateFrom,
    DateTime? dateTo,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _getAuthed(
      '/admin/workflow-activity',
      queryParameters: {
        'offset': offset,
        'limit': limit,
        if (actor != null && actor.trim().isNotEmpty) 'actor': actor.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
        if (eventType != null && eventType.trim().isNotEmpty)
          'event_type': eventType.trim(),
        if (dateFrom != null) 'date_from': dateFrom.toUtc().toIso8601String(),
        if (dateTo != null) 'date_to': dateTo.toUtc().toIso8601String(),
      },
    );
    return AdminWorkflowActivityPageModel.fromJson(response);
  }

  @override
  Future<AdminVerificationDeskModel> fetchVerificationDesk({
    String? verificationStatus,
    String? articleStatus,
    int limit = 50,
  }) async {
    final response = await _getAuthed(
      '/admin/verification/articles',
      queryParameters: {
        'limit': limit,
        if (verificationStatus?.trim().isNotEmpty ?? false)
          'verification_status': verificationStatus!.trim(),
        if (articleStatus?.trim().isNotEmpty ?? false)
          'status': articleStatus!.trim(),
      },
    );
    return AdminVerificationDeskModel.fromJson(response);
  }

  @override
  Future<List<NewsArticleModel>> fetchAdminArticles({
    String? status,
    String? query,
    int limit = 50,
  }) async {
    final response = await _getAuthed(
      '/admin/articles',
      queryParameters: {
        'limit': limit,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return _parseArticleItems(response);
  }

  @override
  Future<AdminArticleListPageModel> fetchAdminArticlesPage({
    String? status,
    List<String>? statuses,
    String? query,
    String? source,
    String? tag,
    DateTime? publishedFrom,
    DateTime? publishedTo,
    String? sort,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _getAuthed(
      '/admin/articles',
      queryParameters: {
        'offset': offset,
        'limit': limit,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (statuses != null && statuses.isNotEmpty)
          'statuses': statuses
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .join(','),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
        if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
        if (publishedFrom != null)
          'published_from': publishedFrom.toUtc().toIso8601String(),
        if (publishedTo != null)
          'published_to': publishedTo.toUtc().toIso8601String(),
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort.trim(),
      },
    );
    return AdminArticleListPageModel.fromJson(response);
  }

  @override
  Future<AdminArticleQueueSettingsResponseModel>
  fetchArticleQueueSettings() async {
    final response = await _getAuthed('/admin/article-queue/settings');
    return AdminArticleQueueSettingsResponseModel.fromJson(response);
  }

  @override
  Future<AdminArticleQueueSettingsResponseModel> updateArticleQueueSettings({
    required bool autoArchiveEnabled,
    required int archiveDraftAfterDays,
    required int archiveReviewAfterDays,
    required int archiveRejectedAfterDays,
  }) async {
    final response = await _patchAuthed(
      '/admin/article-queue/settings',
      data: {
        'auto_archive_enabled': autoArchiveEnabled,
        'archive_draft_after_days': archiveDraftAfterDays,
        'archive_review_after_days': archiveReviewAfterDays,
        'archive_rejected_after_days': archiveRejectedAfterDays,
      },
    );
    return AdminArticleQueueSettingsResponseModel.fromJson(response);
  }

  @override
  Future<AdminArticleQueueArchiveRunResponseModel>
  runArticleQueueAutoArchive() async {
    final response = await _postAuthed('/admin/article-queue/run-auto-archive');
    return AdminArticleQueueArchiveRunResponseModel.fromJson(response);
  }

  @override
  Future<AdminArticleDetailModel> fetchAdminArticleDetail(
    String articleId,
  ) async {
    final normalizedArticleId = articleId.trim();
    if (normalizedArticleId.isEmpty) {
      throw const ParseException('Article id is required.');
    }
    final response = await _getAuthed(
      '/admin/articles/$normalizedArticleId/detail',
    );
    return AdminArticleDetailModel.fromJson(response);
  }

  @override
  Future<NewsArticleModel> createAdminArticle({
    required String title,
    required String source,
    required String category,
    List<String> tags = const <String>[],
    String? summary,
    required String sourceUrl,
    String? imageUrl,
    required String status,
    required String verificationStatus,
    required bool isFeatured,
    String? reviewNotes,
  }) async {
    final response = await _postAuthed(
      '/admin/articles',
      data: {
        'title': title.trim(),
        'source': source.trim(),
        'category': category.trim(),
        'tags': tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        'summary': summary?.trim(),
        'source_url': sourceUrl.trim(),
        'image_url': imageUrl?.trim(),
        'status': status.trim(),
        'verification_status': verificationStatus.trim(),
        'is_featured': isFeatured,
        'review_notes': reviewNotes?.trim(),
      },
    );
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<NewsArticleModel> updateAdminArticle({
    required String articleId,
    String? title,
    String? source,
    String? category,
    List<String>? tags,
    String? summary,
    String? sourceUrl,
    String? imageUrl,
    String? verificationStatus,
    bool? isFeatured,
    String? reviewNotes,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title.trim();
    }
    if (source != null) {
      payload['source'] = source.trim();
    }
    if (category != null) {
      payload['category'] = category.trim();
    }
    if (tags != null) {
      payload['tags'] = tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }
    if (summary != null) {
      payload['summary'] = summary.trim();
    }
    if (sourceUrl != null) {
      payload['source_url'] = sourceUrl.trim();
    }
    if (imageUrl != null) {
      payload['image_url'] = imageUrl.trim();
    }
    if (verificationStatus != null) {
      payload['verification_status'] = verificationStatus.trim();
    }
    if (isFeatured != null) {
      payload['is_featured'] = isFeatured;
    }
    if (reviewNotes != null) {
      payload['review_notes'] = reviewNotes.trim();
    }
    final response = await _patchAuthed(
      '/admin/articles/${articleId.trim()}',
      data: payload,
    );
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<NewsArticleModel> transitionAdminArticle({
    required String articleId,
    required String action,
    String? notes,
    String? targetStatus,
  }) async {
    final normalizedArticleId = articleId.trim();
    final normalizedAction = action.trim().toLowerCase();
    if (normalizedArticleId.isEmpty || normalizedAction.isEmpty) {
      throw const ParseException('Article and action are required.');
    }
    final response = await _postAuthed(
      '/admin/articles/$normalizedArticleId/$normalizedAction',
      data: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (targetStatus != null && targetStatus.trim().isNotEmpty)
          'target_status': targetStatus.trim(),
      },
    );
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<List<ReportedCommentModel>> fetchReportedComments({
    int limit = 100,
  }) async {
    final response = await _getAuthed(
      '/admin/comments/reported',
      queryParameters: {'limit': limit},
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for reported comments.',
      );
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(ReportedCommentModel.fromJson)
        .toList();
  }

  @override
  Future<ArticleCommentModel> moderateComment({
    required int commentId,
    required String action,
    String? notes,
  }) async {
    final response = await _postAuthed(
      '/admin/comments/$commentId/${action.trim().toLowerCase()}',
      data: {if (notes?.trim().isNotEmpty ?? false) 'notes': notes!.trim()},
    );
    return ArticleCommentModel.fromJson(response);
  }

  @override
  Future<List<AdminSourceModel>> fetchSources() async {
    final response = await _getAuthed('/admin/sources');
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for sources.');
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AdminSourceModel.fromJson)
        .toList();
  }

  @override
  Future<AdminSourceModel> createSource({
    required String id,
    required String name,
    required String type,
    String? country,
    bool enabled = true,
    String? feedUrl,
    String? apiBaseUrl,
    int pollIntervalSeconds = 900,
    String? notes,
  }) async {
    final response = await _postAuthed(
      '/admin/sources',
      data: {
        'id': id.trim(),
        'name': name.trim(),
        'type': type.trim(),
        'country': country?.trim(),
        'enabled': enabled,
        'feed_url': feedUrl?.trim(),
        'api_base_url': apiBaseUrl?.trim(),
        'poll_interval_sec': pollIntervalSeconds,
        'notes': notes?.trim(),
      },
    );
    return AdminSourceModel.fromJson(response);
  }

  @override
  Future<AdminSourceModel> updateSource({
    required String sourceId,
    String? name,
    String? type,
    String? country,
    bool? enabled,
    bool? configured,
    String? feedUrl,
    String? apiBaseUrl,
    int? pollIntervalSeconds,
    String? notes,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) {
      payload['name'] = name.trim();
    }
    if (type != null) {
      payload['type'] = type.trim();
    }
    if (country != null) {
      payload['country'] = country.trim();
    }
    if (enabled != null) {
      payload['enabled'] = enabled;
    }
    if (configured != null) {
      payload['configured'] = configured;
    }
    if (feedUrl != null) {
      payload['feed_url'] = feedUrl.trim();
    }
    if (apiBaseUrl != null) {
      payload['api_base_url'] = apiBaseUrl.trim();
    }
    if (pollIntervalSeconds != null) {
      payload['poll_interval_sec'] = pollIntervalSeconds;
    }
    if (notes != null) {
      payload['notes'] = notes.trim();
    }
    final response = await _patchAuthed(
      '/admin/sources/${sourceId.trim()}',
      data: payload,
    );
    return AdminSourceModel.fromJson(response);
  }

  @override
  Future<AdminIngestionRunModel> testSource(String sourceId) async {
    final response = await _postAuthed(
      '/admin/sources/${sourceId.trim()}/test',
    );
    return AdminIngestionRunModel.fromJson(response);
  }

  @override
  Future<AdminIngestionRunModel> runSource(String sourceId) async {
    final response = await _postAuthed('/admin/sources/${sourceId.trim()}/run');
    return AdminIngestionRunModel.fromJson(response);
  }

  @override
  Future<List<AdminUserModel>> fetchUsers({
    String? role,
    bool? isActive,
    int limit = 100,
  }) async {
    final queryParameters = <String, dynamic>{'limit': limit};
    if (role?.trim().isNotEmpty ?? false) {
      queryParameters['role'] = role!.trim();
    }
    if (isActive != null) {
      queryParameters['is_active'] = isActive;
    }
    final response = await _getAuthed(
      '/admin/users',
      queryParameters: queryParameters,
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for users.');
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AdminUserModel.fromJson)
        .toList();
  }

  @override
  Future<AdminUserModel> updateUser({
    required String userId,
    String? displayName,
    String? avatarUrl,
    bool? isActive,
    String? role,
    bool? streamAccessGranted,
    bool? streamHostingGranted,
    bool? contributionAccessGranted,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) {
      payload['display_name'] = displayName.trim();
    }
    if (avatarUrl != null) {
      payload['avatar_url'] = avatarUrl.trim();
    }
    if (isActive != null) {
      payload['is_active'] = isActive;
    }
    if (role != null) {
      payload['role'] = role.trim();
    }
    if (streamAccessGranted != null) {
      payload['stream_access_granted'] = streamAccessGranted;
    }
    if (streamHostingGranted != null) {
      payload['stream_hosting_granted'] = streamHostingGranted;
    }
    if (contributionAccessGranted != null) {
      payload['contribution_access_granted'] = contributionAccessGranted;
    }
    final response = await _patchAuthed(
      '/admin/users/${userId.trim()}',
      data: payload,
    );
    return AdminUserModel.fromJson({'user': response});
  }

  @override
  Future<List<PollModel>> fetchActivePolls() async {
    final response = await _getAuthed('/polls/active');
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for polls.');
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(PollModel.fromJson)
        .toList();
  }

  @override
  Future<List<PollCategoryModel>> fetchPollCategories() async {
    final response = await _getAuthed('/categories');
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for poll categories.',
      );
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(PollCategoryModel.fromJson)
        .toList();
  }

  @override
  Future<PollModel> createPoll({
    required String question,
    required DateTime endsAt,
    String? categoryId,
    required List<String> optionLabels,
  }) async {
    final response = await _postAuthed(
      '/polls',
      data: {
        'question': question.trim(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        if (categoryId?.trim().isNotEmpty ?? false)
          'category_id': categoryId!.trim(),
        'options': _normalizePollOptions(optionLabels),
      },
    );
    return PollModel.fromJson(response);
  }

  @override
  Future<List<AdminUserAccessRequestModel>> fetchUserAccessRequests({
    String? status,
    int limit = 100,
  }) async {
    final response = await _getAuthed(
      '/admin/users/access-requests',
      queryParameters: {
        'limit': limit,
        if (status?.trim().isNotEmpty ?? false) 'status': status!.trim(),
      },
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for user access requests.',
      );
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AdminUserAccessRequestModel.fromJson)
        .toList();
  }

  @override
  Future<List<AdminNewsroomAccessRequestModel>> fetchNewsroomAccessRequests({
    String? status,
    int limit = 100,
  }) async {
    final response = await _getAuthed(
      '/admin/newsroom/access-requests',
      queryParameters: {
        'limit': limit,
        if (status?.trim().isNotEmpty ?? false) 'status': status!.trim(),
      },
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for newsroom access requests.',
      );
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AdminNewsroomAccessRequestModel.fromJson)
        .toList();
  }

  @override
  Future<AdminUserAccessRequestModel> reviewUserAccessRequest({
    required String requestId,
    required String action,
    String? reviewNote,
  }) async {
    final response = await _postAuthed(
      '/admin/users/access-requests/${requestId.trim()}/review',
      data: {
        'action': action.trim().toLowerCase(),
        if (reviewNote?.trim().isNotEmpty ?? false)
          'review_note': reviewNote!.trim(),
      },
    );
    return AdminUserAccessRequestModel.fromJson(response);
  }

  @override
  Future<AdminNewsroomAccessRequestModel> reviewNewsroomAccessRequest({
    required String requestId,
    required String action,
    String? reviewNote,
  }) async {
    final response = await _postAuthed(
      '/admin/newsroom/access-requests/${requestId.trim()}/review',
      data: {
        'action': action.trim().toLowerCase(),
        if (reviewNote?.trim().isNotEmpty ?? false)
          'review_note': reviewNote!.trim(),
      },
    );
    return AdminNewsroomAccessRequestModel.fromJson(response);
  }

  @override
  Future<AdminIngestionStatusModel> fetchIngestionStatus() async {
    final response = await _apiClient.get('/admin/ingestion/status');
    return AdminIngestionStatusModel.fromJson(response);
  }

  @override
  Future<AdminCacheDiagnosticsModel> fetchCacheDiagnostics() async {
    final response = await _getAuthed('/admin/cache/diagnostics');
    return AdminCacheDiagnosticsModel.fromJson(response);
  }

  @override
  Future<AdminAnalyticsOverviewModel> fetchAnalyticsOverview({
    int days = 30,
  }) async {
    final response = await _getAuthed(
      '/admin/analytics/overview',
      queryParameters: {'days': days},
    );
    return AdminAnalyticsOverviewModel.fromJson(response);
  }

  @override
  Future<AdminHomepageConfigModel> fetchHomepageConfig() async {
    final response = await _getAuthed('/admin/homepage');
    return AdminHomepageConfigModel.fromJson(response);
  }

  @override
  Future<AdminHomepageConfigModel> updateHomepageCategories(
    List<AdminHomepageCategoryConfigModel> items,
  ) async {
    final response = await _patchAuthed(
      '/admin/homepage/categories',
      data: {
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    return AdminHomepageConfigModel.fromJson(response);
  }

  @override
  Future<AdminHomepageConfigModel> updateHomepageSecondaryChips(
    List<AdminHomepageSecondaryChipConfigModel> items,
  ) async {
    final response = await _patchAuthed(
      '/admin/homepage/secondary-chips',
      data: {
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    return AdminHomepageConfigModel.fromJson(response);
  }

  @override
  Future<AdminHomepageConfigModel> updateHomepagePlacements(
    List<AdminHomepagePlacementItemModel> items,
  ) async {
    final response = await _patchAuthed(
      '/admin/homepage/placements',
      data: {
        'items': items.map((item) => item.toJson()).toList(growable: false),
      },
    );
    return AdminHomepageConfigModel.fromJson(response);
  }

  @override
  Future<AdminHomepageConfigModel> updateHomepageSettings({
    required bool latestAutofillEnabled,
    required int latestItemLimit,
    required int latestWindowHours,
    required int latestFallbackWindowHours,
    required bool directGnewsTopPublishEnabled,
    required bool categoryAutofillEnabled,
    required int categoryWindowHours,
    required int staleGeneralHours,
    required int staleWorldHours,
    required int staleBusinessHours,
    required int staleTechnologyHours,
    required int staleEntertainmentHours,
    required int staleScienceHours,
    required int staleSportsHours,
    required int staleHealthHours,
    required int staleBreakingHours,
    required int staleOpinionHours,
  }) async {
    final response = await _patchAuthed(
      '/admin/homepage/settings',
      data: {
        'latest_autofill_enabled': latestAutofillEnabled,
        'latest_item_limit': latestItemLimit,
        'latest_window_hours': latestWindowHours,
        'latest_fallback_window_hours': latestFallbackWindowHours,
        'direct_gnews_top_publish_enabled': directGnewsTopPublishEnabled,
        'category_autofill_enabled': categoryAutofillEnabled,
        'category_window_hours': categoryWindowHours,
        'stale_general_hours': staleGeneralHours,
        'stale_world_hours': staleWorldHours,
        'stale_business_hours': staleBusinessHours,
        'stale_technology_hours': staleTechnologyHours,
        'stale_entertainment_hours': staleEntertainmentHours,
        'stale_science_hours': staleScienceHours,
        'stale_sports_hours': staleSportsHours,
        'stale_health_hours': staleHealthHours,
        'stale_breaking_hours': staleBreakingHours,
        'stale_opinion_hours': staleOpinionHours,
      },
    );
    return AdminHomepageConfigModel.fromJson(response);
  }

  Future<Map<String, dynamic>> _getAuthed(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to access the admin dashboard.',
        statusCode: 401,
      );
    }
    return _apiClient.get(
      path,
      queryParameters: queryParameters,
      headers: {'x-user-id': userId},
    );
  }

  Future<Map<String, dynamic>> _postAuthed(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to access the admin dashboard.',
        statusCode: 401,
      );
    }
    return _apiClient.post(path, data: data, headers: {'x-user-id': userId});
  }

  Future<Map<String, dynamic>> _patchAuthed(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to access the admin dashboard.',
        statusCode: 401,
      );
    }
    return _apiClient.patch(path, data: data, headers: {'x-user-id': userId});
  }

  List<NewsArticleModel> _parseArticleItems(Map<String, dynamic> response) {
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for articles.');
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(NewsArticleModel.fromJson)
        .toList();
  }

  List<Map<String, String>> _normalizePollOptions(List<String> optionLabels) {
    final seen = <String>{};
    final items = <Map<String, String>>[];
    for (final raw in optionLabels) {
      final label = raw.trim();
      if (label.isEmpty) {
        continue;
      }
      var optionId = label
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      if (optionId.isEmpty) {
        optionId = 'option';
      }
      final baseId = optionId;
      var suffix = 2;
      while (seen.contains(optionId)) {
        optionId = '$baseId-$suffix';
        suffix += 1;
      }
      seen.add(optionId);
      items.add({'id': optionId, 'label': label});
    }
    return items;
  }

  Future<String?> _currentUserId() async {
    try {
      final session = await _authLocalDataSource.getCachedSession();
      final userId = session?.userId.trim();
      if (userId == null || userId.isEmpty) {
        return null;
      }
      return userId;
    } catch (_) {
      return null;
    }
  }
}
