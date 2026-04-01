import 'package:naijapulse/features/news/domain/entities/news_article.dart';

abstract class NewsRepository {
  Future<List<NewsArticle>> getTopStories();

  Future<List<NewsArticle>> getLatestStories({String? category});

  Future<void> recordStoryOpened(String articleId);
}
