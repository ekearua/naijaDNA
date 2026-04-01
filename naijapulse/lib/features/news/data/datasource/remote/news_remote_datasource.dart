import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/auth/data/datasource/local/auth_local_datasource.dart';
import 'package:naijapulse/features/news/data/models/article_comment_model.dart';
import 'package:naijapulse/features/news/data/models/comment_reaction_result_model.dart';
import 'package:naijapulse/features/news/data/models/homepage_content_model.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/data/models/news_readable_text_model.dart';
import 'package:naijapulse/features/news/data/models/reported_comment_model.dart';

abstract class NewsRemoteDataSource {
  Future<HomepageContentModel> fetchHomepageContent();

  Future<List<NewsArticleModel>> fetchPersonalizedStories({
    int limit,
    String? category,
  });

  Future<List<NewsArticleModel>> fetchTopStories();

  Future<List<NewsArticleModel>> fetchLatestStories({String? category});

  Future<List<NewsArticleModel>> searchStories({
    required String query,
    int limit,
    String? category,
  });

  Future<NewsArticleModel> fetchStoryById(String articleId);

  Future<NewsReadableTextModel> fetchReadableText(String articleId);

  Future<List<ArticleCommentModel>> fetchArticleComments(String articleId);

  Future<ArticleCommentModel> createArticleComment({
    required String articleId,
    required String body,
  });

  Future<ArticleCommentModel> replyToComment({
    required int commentId,
    required String body,
  });

  Future<void> reportComment({required int commentId, String? reason});

  Future<CommentReactionResultModel> toggleCommentLike({
    required int commentId,
  });

  Future<List<ReportedCommentModel>> fetchReportedComments({int limit});

  Future<ArticleCommentModel> moderateComment({
    required int commentId,
    required String action,
    String? notes,
  });

  Future<void> recordStoryOpened(String articleId);

  Future<bool> recordFeedEvent({
    required String articleId,
    required String eventType,
    int? dwellMs,
  });

  Future<bool> applyFeedFeedback({
    required String action,
    String? articleId,
    String? source,
    String? categoryId,
    String? topic,
  });

  Future<NewsArticleModel> createUserArticle({
    required String title,
    required String category,
    String? summary,
    String? contentUrl,
    String? imageUrl,
  });

  Future<NewsArticleModel> createAdminArticle({
    required String title,
    required String source,
    required String category,
    required String sourceUrl,
    String? summary,
    String? imageUrl,
    required String status,
    required String verificationStatus,
    bool isFeatured,
    String? reviewNotes,
  });

  Future<List<NewsArticleModel>> fetchAdminArticles({
    String? status,
    int limit,
  });

  Future<NewsArticleModel> transitionAdminArticle({
    required String articleId,
    required String action,
    String? notes,
  });
}

class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  final ApiClient _apiClient;
  final AuthLocalDataSource _authLocalDataSource;

  const NewsRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthLocalDataSource authLocalDataSource,
  }) : _apiClient = apiClient,
       _authLocalDataSource = authLocalDataSource;

  @override
  Future<HomepageContentModel> fetchHomepageContent() async {
    try {
      final response = await _apiClient.get('/news/homepage');
      return HomepageContentModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse homepage response: $error');
    }
  }

  @override
  Future<List<NewsArticleModel>> fetchPersonalizedStories({
    int limit = 10,
    String? category,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return const <NewsArticleModel>[];
    }

    try {
      final queryParameters = <String, dynamic>{'limit': limit};
      if (category != null && category.trim().isNotEmpty) {
        queryParameters['category'] = category.trim();
      }
      final response = await _apiClient.get(
        '/feed/personalized',
        queryParameters: queryParameters,
        headers: {'x-user-id': userId},
      );
      return _parseItems(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException(
        'Could not parse personalized feed response: $error',
      );
    }
  }

  @override
  Future<List<NewsArticleModel>> fetchTopStories() async {
    try {
      // Mirrors backend default top-stories behavior for home hero content.
      final response = await _apiClient.get(
        '/news/top',
        queryParameters: const {'limit': 10},
      );
      return _parseItems(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse top stories response: $error');
    }
  }

  @override
  Future<List<NewsArticleModel>> fetchLatestStories({String? category}) async {
    try {
      final userId = await _currentUserId();
      if (userId != null) {
        final queryParameters = <String, dynamic>{'limit': 25};
        if (category != null && category.trim().isNotEmpty) {
          queryParameters['category'] = category.trim();
        }
        final response = await _apiClient.get(
          '/feed/personalized',
          queryParameters: queryParameters,
          headers: {'x-user-id': userId},
        );
        return _parseItems(response);
      }

      final queryParameters = <String, dynamic>{'limit': 25};
      queryParameters['diversify_sources'] = true;
      if (category != null && category.trim().isNotEmpty) {
        queryParameters['category'] = category.trim();
      }

      final response = await _apiClient.get(
        '/news/latest',
        queryParameters: queryParameters,
      );
      return _parseItems(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse latest stories response: $error');
    }
  }

  @override
  Future<List<NewsArticleModel>> searchStories({
    required String query,
    int limit = 25,
    String? category,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      return const <NewsArticleModel>[];
    }

    try {
      final queryParameters = <String, dynamic>{
        'q': normalizedQuery,
        'limit': limit,
      };
      if (category != null && category.trim().isNotEmpty) {
        queryParameters['category'] = category.trim();
      }
      final response = await _apiClient.get(
        '/news/search',
        queryParameters: queryParameters,
      );
      return _parseItems(response);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse search response: $error');
    }
  }

  @override
  Future<NewsArticleModel> fetchStoryById(String articleId) async {
    final normalizedArticleId = articleId.trim();
    if (normalizedArticleId.isEmpty) {
      throw const ParseException('Article id is required.');
    }
    final response = await _apiClient.get('/news/$normalizedArticleId');
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<NewsReadableTextModel> fetchReadableText(String articleId) async {
    final normalizedArticleId = articleId.trim();
    if (normalizedArticleId.isEmpty) {
      throw const ParseException('Article id is required.');
    }
    final response = await _apiClient.get(
      '/news/$normalizedArticleId/readable-text',
    );
    return NewsReadableTextModel.fromJson(response);
  }

  @override
  Future<List<ArticleCommentModel>> fetchArticleComments(
    String articleId,
  ) async {
    final normalizedArticleId = articleId.trim();
    if (normalizedArticleId.isEmpty) {
      throw const ParseException('Article id is required.');
    }
    final userId = await _currentUserId();
    final headers = userId == null
        ? null
        : <String, String>{'x-user-id': userId};
    final response = await _apiClient.get(
      '/news/$normalizedArticleId/comments',
      headers: headers,
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for article comments.',
      );
    }
    return rawItems
        .map(
          (item) => ArticleCommentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<ArticleCommentModel> createArticleComment({
    required String articleId,
    required String body,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to comment on an article.',
        statusCode: 401,
      );
    }
    final response = await _apiClient.post(
      '/news/${articleId.trim()}/comments',
      headers: {'x-user-id': userId},
      data: {'body': body.trim()},
    );
    return ArticleCommentModel.fromJson(response);
  }

  @override
  Future<ArticleCommentModel> replyToComment({
    required int commentId,
    required String body,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to reply to a comment.',
        statusCode: 401,
      );
    }
    final response = await _apiClient.post(
      '/comments/$commentId/reply',
      headers: {'x-user-id': userId},
      data: {'body': body.trim()},
    );
    return ArticleCommentModel.fromJson(response);
  }

  @override
  Future<void> reportComment({required int commentId, String? reason}) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to report a comment.',
        statusCode: 401,
      );
    }
    await _apiClient.post(
      '/comments/$commentId/report',
      headers: {'x-user-id': userId},
      data: {if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim()},
    );
  }

  @override
  Future<CommentReactionResultModel> toggleCommentLike({
    required int commentId,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to react to a comment.',
        statusCode: 401,
      );
    }
    final response = await _apiClient.post(
      '/comments/$commentId/reactions/like',
      headers: {'x-user-id': userId},
    );
    return CommentReactionResultModel.fromJson(response);
  }

  @override
  Future<List<ReportedCommentModel>> fetchReportedComments({
    int limit = 100,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to access comment moderation.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.get(
      '/admin/comments/reported',
      headers: {'x-user-id': userId},
      queryParameters: {'limit': limit},
    );
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException(
        'Invalid response format for reported comments.',
      );
    }
    return rawItems
        .map(
          (item) => ReportedCommentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<ArticleCommentModel> moderateComment({
    required int commentId,
    required String action,
    String? notes,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to moderate comments.',
        statusCode: 401,
      );
    }
    final response = await _apiClient.post(
      '/admin/comments/$commentId/${action.trim().toLowerCase()}',
      headers: {'x-user-id': userId},
      data: {if (notes?.trim().isNotEmpty ?? false) 'notes': notes!.trim()},
    );
    return ArticleCommentModel.fromJson(response);
  }

  @override
  Future<void> recordStoryOpened(String articleId) async {
    final normalizedArticleId = articleId.trim();
    if (normalizedArticleId.isEmpty) {
      return;
    }

    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }

    try {
      await _apiClient.post(
        '/feed/events',
        headers: {'x-user-id': userId},
        data: {
          'article_id': normalizedArticleId,
          'event_type': 'click',
          'idempotency_key':
              'click-${DateTime.now().toUtc().microsecondsSinceEpoch}-$normalizedArticleId',
        },
      );
    } on AppException {
      // Non-blocking telemetry call; ignore failures.
    } catch (_) {
      // Non-blocking telemetry call; ignore failures.
    }
  }

  @override
  Future<bool> recordFeedEvent({
    required String articleId,
    required String eventType,
    int? dwellMs,
  }) async {
    final normalizedArticleId = articleId.trim();
    final normalizedEventType = eventType.trim().toLowerCase();
    if (normalizedArticleId.isEmpty || normalizedEventType.isEmpty) {
      return false;
    }

    final userId = await _currentUserId();
    if (userId == null) {
      return false;
    }

    await _apiClient.post(
      '/feed/events',
      headers: {'x-user-id': userId},
      data: {
        'article_id': normalizedArticleId,
        'event_type': normalizedEventType,
        'dwell_ms': dwellMs,
        'idempotency_key':
            '$normalizedEventType-${DateTime.now().toUtc().microsecondsSinceEpoch}-$normalizedArticleId',
      },
    );
    return true;
  }

  @override
  Future<bool> applyFeedFeedback({
    required String action,
    String? articleId,
    String? source,
    String? categoryId,
    String? topic,
  }) async {
    final normalizedAction = action.trim().toLowerCase();
    if (normalizedAction.isEmpty) {
      return false;
    }

    final userId = await _currentUserId();
    if (userId == null) {
      return false;
    }

    await _apiClient.post(
      '/feed/feedback',
      headers: {'x-user-id': userId},
      data: {
        'action': normalizedAction,
        if (articleId != null && articleId.trim().isNotEmpty)
          'article_id': articleId.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
        if (categoryId != null && categoryId.trim().isNotEmpty)
          'category_id': categoryId.trim(),
        if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      },
    );
    return true;
  }

  @override
  Future<NewsArticleModel> createUserArticle({
    required String title,
    required String category,
    String? summary,
    String? contentUrl,
    String? imageUrl,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedCategory = category.trim();
    if (normalizedTitle.length < 5) {
      throw const ParseException('Title must be at least 5 characters.');
    }
    if (normalizedCategory.length < 2) {
      throw const ParseException('Category must be at least 2 characters.');
    }

    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to submit an article.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.post(
      '/news',
      headers: {'x-user-id': userId},
      data: {
        'title': normalizedTitle,
        'category': normalizedCategory,
        if (summary?.trim().isNotEmpty ?? false) 'summary': summary!.trim(),
        if (contentUrl?.trim().isNotEmpty ?? false)
          'content_url': contentUrl!.trim(),
        if (imageUrl?.trim().isNotEmpty ?? false) 'image_url': imageUrl!.trim(),
      },
    );
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<NewsArticleModel> createAdminArticle({
    required String title,
    required String source,
    required String category,
    required String sourceUrl,
    String? summary,
    String? imageUrl,
    required String status,
    required String verificationStatus,
    bool isFeatured = false,
    String? reviewNotes,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedSource = source.trim();
    final normalizedCategory = category.trim();
    final normalizedSourceUrl = sourceUrl.trim();
    if (normalizedTitle.length < 5) {
      throw const ParseException('Title must be at least 5 characters.');
    }
    if (normalizedSource.length < 2) {
      throw const ParseException('Source must be at least 2 characters.');
    }
    if (normalizedCategory.length < 2) {
      throw const ParseException('Category must be at least 2 characters.');
    }
    if (normalizedSourceUrl.isEmpty) {
      throw const ParseException('Source URL is required.');
    }

    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to publish an article.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.post(
      '/admin/articles',
      headers: {'x-user-id': userId},
      data: {
        'title': normalizedTitle,
        'source': normalizedSource,
        'category': normalizedCategory,
        'source_url': normalizedSourceUrl,
        'status': status.trim(),
        'verification_status': verificationStatus.trim(),
        'is_featured': isFeatured,
        if (summary?.trim().isNotEmpty ?? false) 'summary': summary!.trim(),
        if (imageUrl?.trim().isNotEmpty ?? false) 'image_url': imageUrl!.trim(),
        if (reviewNotes?.trim().isNotEmpty ?? false)
          'review_notes': reviewNotes!.trim(),
      },
    );
    return NewsArticleModel.fromJson(response);
  }

  @override
  Future<List<NewsArticleModel>> fetchAdminArticles({
    String? status,
    int limit = 50,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to access the editorial desk.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.get(
      '/admin/articles',
      headers: {'x-user-id': userId},
      queryParameters: {
        'limit': limit,
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    return _parseItems(response);
  }

  @override
  Future<NewsArticleModel> transitionAdminArticle({
    required String articleId,
    required String action,
    String? notes,
  }) async {
    final normalizedArticleId = articleId.trim();
    final normalizedAction = action.trim().toLowerCase();
    if (normalizedArticleId.isEmpty || normalizedAction.isEmpty) {
      throw const ParseException('Article and action are required.');
    }

    final userId = await _currentUserId();
    if (userId == null) {
      throw const ServerException(
        'Sign in is required to update article workflow.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.post(
      '/admin/articles/$normalizedArticleId/$normalizedAction',
      headers: {'x-user-id': userId},
      data: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return NewsArticleModel.fromJson(response);
  }

  List<NewsArticleModel> _parseItems(Map<String, dynamic> response) {
    // Backend wraps list payloads with metadata: { items, total }.
    final rawItems = response['items'];
    if (rawItems is! List<dynamic>) {
      throw const ParseException('Invalid response format for news list.');
    }

    return rawItems
        .map((item) => NewsArticleModel.fromJson(item as Map<String, dynamic>))
        .toList();
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
