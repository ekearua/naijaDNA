import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/live_updates/data/models/live_update_models.dart';

abstract class LiveUpdatesRemoteDataSource {
  Future<List<LiveUpdatePageSummaryModel>> fetchPublicPages({String? status});

  Future<LiveUpdatePageDetailModel> fetchPublicPage({
    required String slug,
    DateTime? after,
  });

  Future<List<LiveUpdatePageSummaryModel>> fetchAdminPages({String? status});

  Future<LiveUpdatePageDetailModel> fetchAdminPage(String pageId);

  Future<LiveUpdatePageDetailModel> createAdminPage({
    required String title,
    required String summary,
    required String category,
    String? slug,
    String? heroKicker,
    String? coverImageUrl,
    required String status,
    required bool isFeatured,
    required bool isBreaking,
  });

  Future<LiveUpdatePageDetailModel> updateAdminPage({
    required String pageId,
    String? title,
    String? summary,
    String? category,
    String? slug,
    String? heroKicker,
    String? coverImageUrl,
    String? status,
    bool? isFeatured,
    bool? isBreaking,
  });

  Future<LiveUpdatePageDetailModel> createAdminEntry({
    required String pageId,
    required String blockType,
    String? headline,
    String? body,
    String? imageUrl,
    String? imageCaption,
    String? linkedArticleId,
    String? linkedPollId,
    bool isPinned,
    bool isVisible,
  });

  Future<LiveUpdatePageDetailModel> updateAdminEntry({
    required String entryId,
    String? headline,
    String? body,
    String? imageUrl,
    String? imageCaption,
    String? linkedArticleId,
    String? linkedPollId,
    bool? isPinned,
    bool? isVisible,
  });
}

class LiveUpdatesRemoteDataSourceImpl implements LiveUpdatesRemoteDataSource {
  const LiveUpdatesRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthLocalDataSource authLocalDataSource,
  }) : _apiClient = apiClient,
       _authLocalDataSource = authLocalDataSource;

  final ApiClient _apiClient;
  final AuthLocalDataSource _authLocalDataSource;

  @override
  Future<List<LiveUpdatePageSummaryModel>> fetchPublicPages({
    String? status,
  }) async {
    final response = await _apiClient.get(
      '/live-updates',
      queryParameters: {
        if (status?.trim().isNotEmpty ?? false) 'status': status!.trim(),
      },
    );
    return _parsePageItems(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> fetchPublicPage({
    required String slug,
    DateTime? after,
  }) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      throw const ParseException('Live update slug is required.');
    }
    final response = await _apiClient.get(
      '/live-updates/$normalizedSlug',
      queryParameters: {
        if (after != null) 'after': after.toUtc().toIso8601String(),
      },
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  @override
  Future<List<LiveUpdatePageSummaryModel>> fetchAdminPages({
    String? status,
  }) async {
    final response = await _getAuthed(
      '/admin/live-updates/pages',
      queryParameters: {
        if (status?.trim().isNotEmpty ?? false) 'status': status!.trim(),
      },
    );
    return _parsePageItems(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> fetchAdminPage(String pageId) async {
    final normalizedPageId = pageId.trim();
    if (normalizedPageId.isEmpty) {
      throw const ParseException('Live update page id is required.');
    }
    final response = await _getAuthed(
      '/admin/live-updates/pages/$normalizedPageId',
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> createAdminPage({
    required String title,
    required String summary,
    required String category,
    String? slug,
    String? heroKicker,
    String? coverImageUrl,
    required String status,
    required bool isFeatured,
    required bool isBreaking,
  }) async {
    final response = await _postAuthed(
      '/admin/live-updates/pages',
      data: {
        'title': title.trim(),
        'summary': summary.trim(),
        'category': category.trim(),
        if (slug?.trim().isNotEmpty ?? false) 'slug': slug!.trim(),
        if (heroKicker?.trim().isNotEmpty ?? false)
          'hero_kicker': heroKicker!.trim(),
        if (coverImageUrl?.trim().isNotEmpty ?? false)
          'cover_image_url': coverImageUrl!.trim(),
        'status': status.trim(),
        'is_featured': isFeatured,
        'is_breaking': isBreaking,
      },
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> updateAdminPage({
    required String pageId,
    String? title,
    String? summary,
    String? category,
    String? slug,
    String? heroKicker,
    String? coverImageUrl,
    String? status,
    bool? isFeatured,
    bool? isBreaking,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title.trim();
    }
    if (summary != null) {
      payload['summary'] = summary.trim();
    }
    if (category != null) {
      payload['category'] = category.trim();
    }
    if (slug != null) {
      payload['slug'] = slug.trim();
    }
    if (heroKicker != null) {
      payload['hero_kicker'] = heroKicker.trim();
    }
    if (coverImageUrl != null) {
      payload['cover_image_url'] = coverImageUrl.trim();
    }
    if (status != null) {
      payload['status'] = status.trim();
    }
    if (isFeatured != null) {
      payload['is_featured'] = isFeatured;
    }
    if (isBreaking != null) {
      payload['is_breaking'] = isBreaking;
    }
    final response = await _patchAuthed(
      '/admin/live-updates/pages/${pageId.trim()}',
      data: payload,
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> createAdminEntry({
    required String pageId,
    required String blockType,
    String? headline,
    String? body,
    String? imageUrl,
    String? imageCaption,
    String? linkedArticleId,
    String? linkedPollId,
    bool isPinned = false,
    bool isVisible = true,
  }) async {
    final response = await _postAuthed(
      '/admin/live-updates/pages/${pageId.trim()}/entries',
      data: {
        'block_type': blockType.trim(),
        if (headline?.trim().isNotEmpty ?? false) 'headline': headline!.trim(),
        if (body?.trim().isNotEmpty ?? false) 'body': body!.trim(),
        if (imageUrl?.trim().isNotEmpty ?? false) 'image_url': imageUrl!.trim(),
        if (imageCaption?.trim().isNotEmpty ?? false)
          'image_caption': imageCaption!.trim(),
        if (linkedArticleId?.trim().isNotEmpty ?? false)
          'linked_article_id': linkedArticleId!.trim(),
        if (linkedPollId?.trim().isNotEmpty ?? false)
          'linked_poll_id': linkedPollId!.trim(),
        'is_pinned': isPinned,
        'is_visible': isVisible,
      },
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  @override
  Future<LiveUpdatePageDetailModel> updateAdminEntry({
    required String entryId,
    String? headline,
    String? body,
    String? imageUrl,
    String? imageCaption,
    String? linkedArticleId,
    String? linkedPollId,
    bool? isPinned,
    bool? isVisible,
  }) async {
    final payload = <String, dynamic>{};
    if (headline != null) {
      payload['headline'] = headline.trim();
    }
    if (body != null) {
      payload['body'] = body.trim();
    }
    if (imageUrl != null) {
      payload['image_url'] = imageUrl.trim();
    }
    if (imageCaption != null) {
      payload['image_caption'] = imageCaption.trim();
    }
    if (linkedArticleId != null) {
      payload['linked_article_id'] = linkedArticleId.trim();
    }
    if (linkedPollId != null) {
      payload['linked_poll_id'] = linkedPollId.trim();
    }
    if (isPinned != null) {
      payload['is_pinned'] = isPinned;
    }
    if (isVisible != null) {
      payload['is_visible'] = isVisible;
    }
    final response = await _patchAuthed(
      '/admin/live-updates/entries/${entryId.trim()}',
      data: payload,
    );
    return LiveUpdatePageDetailModel.fromJson(response);
  }

  List<LiveUpdatePageSummaryModel> _parsePageItems(
    Map<String, dynamic> response,
  ) {
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for live update pages.',
      );
    }
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(LiveUpdatePageSummaryModel.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getAuthed(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _apiClient.get(
      path,
      queryParameters: queryParameters,
      headers: await _authHeaders(),
    );
  }

  Future<Map<String, dynamic>> _postAuthed(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.post(path, data: data, headers: await _authHeaders());
  }

  Future<Map<String, dynamic>> _patchAuthed(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.patch(path, data: data, headers: await _authHeaders());
  }

  Future<Map<String, String>> _authHeaders() async {
    try {
      final session = await _authLocalDataSource.getCachedSession();
      if (session == null || session.userId.trim().isEmpty) {
        throw const ServerException(
          'Admin session is required.',
          statusCode: 401,
        );
      }
      return <String, String>{'x-user-id': session.userId.trim()};
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not resolve admin auth headers: $error');
    }
  }
}
