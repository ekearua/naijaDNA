import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/repository/polls_repository.dart';

class GetActivePolls {
  final PollsRepository repository;

  const GetActivePolls(this.repository);

  Future<List<Poll>> call() {
    return repository.getActivePolls();
  }
}
