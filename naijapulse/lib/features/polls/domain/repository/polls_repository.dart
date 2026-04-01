import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';

abstract class PollsRepository {
  Future<List<Poll>> getActivePolls();

  Future<List<PollCategory>> getCategories();

  Future<List<PollCategory>> getFeedTags();

  Future<Poll> submitVote({required String pollId, required String optionId});
}
