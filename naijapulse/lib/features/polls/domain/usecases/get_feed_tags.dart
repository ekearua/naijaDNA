import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';
import 'package:naijapulse/features/polls/domain/repository/polls_repository.dart';

class GetFeedTags {
  const GetFeedTags(this._repository);

  final PollsRepository _repository;

  Future<List<PollCategory>> call() {
    return _repository.getFeedTags();
  }
}
