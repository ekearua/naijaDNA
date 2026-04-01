import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/repository/polls_repository.dart';

class SubmitPollVote {
  final PollsRepository repository;

  const SubmitPollVote(this.repository);

  Future<Poll> call({required String pollId, required String optionId}) {
    return repository.submitVote(pollId: pollId, optionId: optionId);
  }
}
