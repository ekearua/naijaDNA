import 'package:drift/drift.dart';
import 'package:naijapulse/core/storage/app_database.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';

abstract class NewsLocalDataSource {
  Future<void> cacheTopStories(List<NewsArticleModel> stories);

  Future<List<NewsArticleModel>> getCachedTopStories();

  Future<void> cacheLatestStories(
    List<NewsArticleModel> stories, {
    String? category,
  });

  Future<List<NewsArticleModel>> getCachedLatestStories({String? category});
}

class NewsLocalDataSourceImpl implements NewsLocalDataSource {
  static const String _topBucket = 'top';
  static const String _latestBucket = 'latest';

  final AppDatabase _database;

  NewsLocalDataSourceImpl({required AppDatabase database})
    : _database = database;

  @override
  Future<void> cacheTopStories(List<NewsArticleModel> stories) async {
    await _replaceCache(bucket: _topBucket, stories: stories);
  }

  @override
  Future<List<NewsArticleModel>> getCachedTopStories() async {
    return _readCache(bucket: _topBucket);
  }

  @override
  Future<void> cacheLatestStories(
    List<NewsArticleModel> stories, {
    String? category,
  }) async {
    await _replaceCache(
      bucket: _latestBucket,
      requestCategory: _normalizeCategory(category),
      stories: stories,
    );
  }

  @override
  Future<List<NewsArticleModel>> getCachedLatestStories({
    String? category,
  }) async {
    return _readCache(
      bucket: _latestBucket,
      requestCategory: _normalizeCategory(category),
    );
  }

  Future<void> _replaceCache({
    required String bucket,
    String? requestCategory,
    required List<NewsArticleModel> stories,
  }) async {
    await _database.transaction(() async {
      // Replace the entire bucket/category slice so cache ordering stays deterministic.
      final deleteStatement = _database.delete(_database.newsCacheEntries)
        ..where((tbl) {
          final categoryFilter = requestCategory == null
              ? tbl.requestCategory.isNull()
              : tbl.requestCategory.equals(requestCategory);
          return tbl.bucket.equals(bucket) & categoryFilter;
        });
      await deleteStatement.go();

      await _database.batch((batch) {
        for (var index = 0; index < stories.length; index++) {
          final story = stories[index];
          batch.insert(
            _database.newsCacheEntries,
            NewsCacheEntriesCompanion.insert(
              bucket: bucket,
              requestCategory: Value(requestCategory),
              sortOrder: index,
              articleId: story.id,
              title: story.title,
              source: story.source,
              articleCategory: story.category,
              summary: Value(story.summary),
              imageUrl: Value(story.imageUrl),
              articleUrl: Value(story.articleUrl),
              publishedAt: story.publishedAt,
              isFactChecked: Value(story.isFactChecked),
            ),
          );
        }
      });
    });
  }

  Future<List<NewsArticleModel>> _readCache({
    required String bucket,
    String? requestCategory,
  }) async {
    // Read back in stored order to preserve feed presentation consistency.
    final query = _database.select(_database.newsCacheEntries)
      ..where((tbl) {
        final categoryFilter = requestCategory == null
            ? tbl.requestCategory.isNull()
            : tbl.requestCategory.equals(requestCategory);
        return tbl.bucket.equals(bucket) & categoryFilter;
      })
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]);

    final rows = await query.get();
    return rows
        .map(
          (row) => NewsArticleModel(
            id: row.articleId,
            title: row.title,
            source: row.source,
            category: row.articleCategory,
            summary: row.summary,
            imageUrl: row.imageUrl,
            articleUrl: row.articleUrl,
            publishedAt: row.publishedAt,
            isFactChecked: row.isFactChecked,
          ),
        )
        .toList();
  }

  String? _normalizeCategory(String? category) {
    final normalized = category?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
