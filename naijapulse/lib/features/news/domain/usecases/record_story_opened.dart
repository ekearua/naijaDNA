import 'package:naijapulse/features/news/domain/repository/news_repository.dart';

class RecordStoryOpened {
  const RecordStoryOpened(this._repository);

  final NewsRepository _repository;

  Future<void> call(String articleId) {
    return _repository.recordStoryOpened(articleId);
  }
}
