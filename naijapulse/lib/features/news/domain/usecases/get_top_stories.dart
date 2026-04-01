import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/domain/repository/news_repository.dart';

class GetTopStories {
  final NewsRepository repository;

  const GetTopStories(this.repository);

  Future<List<NewsArticle>> call() {
    return repository.getTopStories();
  }
}
