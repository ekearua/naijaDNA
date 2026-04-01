import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/features/news/data/datasource/local/news_local_datasource.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/domain/repository/news_repository.dart';

class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource remoteDataSource;
  final NewsLocalDataSource localDataSource;

  const NewsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<NewsArticle>> getTopStories() async {
    if (!await _isNetworkAvailable()) {
      final cached = await localDataSource.getCachedTopStories();
      if (cached.isNotEmpty) {
        return cached;
      }
      throw const NetworkException(
        'No internet connection and no cached top stories available.',
      );
    }

    try {
      final remoteStories = await remoteDataSource.fetchTopStories();
      await localDataSource.cacheTopStories(remoteStories);
      return remoteStories;
    } on AppException {
      // Fallback to cache only when remote fetch fails.
      try {
        final cached = await localDataSource.getCachedTopStories();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {
        throw const CacheException('Unable to read cached top stories.');
      }
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to load top stories: $error');
    }
  }

  @override
  Future<List<NewsArticle>> getLatestStories({String? category}) async {
    if (!await _isNetworkAvailable()) {
      final cached = await localDataSource.getCachedLatestStories(
        category: category,
      );
      if (cached.isNotEmpty) {
        return cached;
      }
      throw const NetworkException(
        'No internet connection and no cached latest stories available.',
      );
    }

    try {
      final remoteStories = await remoteDataSource.fetchLatestStories(
        category: category,
      );
      await localDataSource.cacheLatestStories(
        remoteStories,
        category: category,
      );
      return remoteStories;
    } on AppException {
      // Preserve usability offline by serving per-category cached snapshots.
      try {
        final cached = await localDataSource.getCachedLatestStories(
          category: category,
        );
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {
        throw const CacheException('Unable to read cached latest stories.');
      }
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to load latest stories: $error');
    }
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Future<void> recordStoryOpened(String articleId) async {
    try {
      await remoteDataSource.recordStoryOpened(articleId);
    } catch (_) {
      // Telemetry should not break navigation or feed rendering.
    }
  }
}
