import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/sync/poll_vote_outbox_local_data_source.dart';
import 'package:naijapulse/features/polls/data/datasource/local/polls_local_datasource.dart';
import 'package:naijapulse/features/polls/data/datasource/remote/polls_remote_datasource.dart';

class PollVoteReplayService {
  PollVoteReplayService({
    required PollVoteOutboxLocalDataSource outboxLocalDataSource,
    required PollsRemoteDataSource remoteDataSource,
    required PollsLocalDataSource localDataSource,
  }) : _outboxLocalDataSource = outboxLocalDataSource,
       _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  static const int _maxAttempts = 8;

  final PollVoteOutboxLocalDataSource _outboxLocalDataSource;
  final PollsRemoteDataSource _remoteDataSource;
  final PollsLocalDataSource _localDataSource;

  Future<void> replayPendingVotes({int batchSize = 25}) async {
    final pendingVotes = await _outboxLocalDataSource.getPendingVotes(
      limit: batchSize,
    );

    for (final pending in pendingVotes) {
      try {
        final updated = await _remoteDataSource.submitVote(
          pollId: pending.pollId,
          optionId: pending.optionId,
          idempotencyKey: pending.voteId,
        );
        await _localDataSource.cacheUpdatedPoll(updated);
        await _outboxLocalDataSource.removeVoteById(pending.id);
      } on NetworkException catch (error) {
        await _outboxLocalDataSource.incrementAttempts(
          id: pending.id,
          errorMessage: error.message,
        );
        // Stop replay until connectivity is restored.
        rethrow;
      } on RequestTimeoutException catch (error) {
        await _outboxLocalDataSource.incrementAttempts(
          id: pending.id,
          errorMessage: error.message,
        );
        rethrow;
      } on ServerException catch (error) {
        final attempts = pending.attempts + 1;
        if (_isConflictLikeStatus(error.statusCode) ||
            attempts >= _maxAttempts) {
          // Drop poisoned/outdated entries to prevent permanent replay loops.
          await _outboxLocalDataSource.removeVoteById(pending.id);
          continue;
        }
        await _outboxLocalDataSource.incrementAttempts(
          id: pending.id,
          errorMessage: error.message,
        );
      } on AppException catch (error) {
        final attempts = pending.attempts + 1;
        if (attempts >= _maxAttempts) {
          await _outboxLocalDataSource.removeVoteById(pending.id);
          continue;
        }
        await _outboxLocalDataSource.incrementAttempts(
          id: pending.id,
          errorMessage: error.message,
        );
      } catch (error) {
        final attempts = pending.attempts + 1;
        if (attempts >= _maxAttempts) {
          await _outboxLocalDataSource.removeVoteById(pending.id);
          continue;
        }
        await _outboxLocalDataSource.incrementAttempts(
          id: pending.id,
          errorMessage: error.toString(),
        );
      }
    }
  }

  bool _isConflictLikeStatus(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return statusCode == 400 ||
        statusCode == 404 ||
        statusCode == 409 ||
        statusCode == 410;
  }
}
