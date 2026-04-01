import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/domain/repository/news_repository.dart';

class GetLatestStories {
  final NewsRepository repository;

  const GetLatestStories(this.repository);

  Future<List<NewsArticle>> call({String? category}) {
    return repository.getLatestStories(category: category);
  }
}
