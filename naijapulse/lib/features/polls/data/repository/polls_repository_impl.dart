import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/sync/poll_vote_outbox_local_data_source.dart';
import 'package:naijapulse/features/polls/data/datasource/local/polls_local_datasource.dart';
import 'package:naijapulse/features/polls/data/datasource/remote/polls_remote_datasource.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';
import 'package:naijapulse/features/polls/domain/repository/polls_repository.dart';

class PollsRepositoryImpl implements PollsRepository {
  final PollsRemoteDataSource remoteDataSource;
  final PollsLocalDataSource localDataSource;
  final PollVoteOutboxLocalDataSource outboxLocalDataSource;

  const PollsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.outboxLocalDataSource,
  });

  @override
  Future<List<Poll>> getActivePolls() async {
    if (!await _isNetworkAvailable()) {
      final cached = await localDataSource.getCachedActivePolls();
      if (cached.isNotEmpty) {
        return cached;
      }
      throw const NetworkException(
        'No internet connection and no cached polls available.',
      );
    }

    try {
      final polls = await remoteDataSource.fetchActivePolls();
      await localDataSource.cacheActivePolls(polls);
      return polls;
    } on AppException {
      // Polls page can still render from cache when the network is unavailable.
      try {
        final cached = await localDataSource.getCachedActivePolls();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (_) {
        throw const CacheException('Unable to read cached polls.');
      }
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to load polls: $error');
    }
  }

  @override
  Future<List<PollCategory>> getCategories() async {
    if (!await _isNetworkAvailable()) {
      return const [];
    }

    try {
      return await remoteDataSource.fetchCategories();
    } on AppException {
      return const [];
    } catch (error) {
      throw UnknownException('Failed to load categories: $error');
    }
  }

  @override
  Future<List<PollCategory>> getFeedTags() async {
    if (!await _isNetworkAvailable()) {
      return const [];
    }

    try {
      return await remoteDataSource.fetchFeedTags();
    } on AppException {
      return const [];
    } catch (error) {
      throw UnknownException('Failed to load feed tags: $error');
    }
  }

  @override
  Future<Poll> submitVote({
    required String pollId,
    required String optionId,
  }) async {
    final voteId = _newIdempotencyKey(pollId: pollId, optionId: optionId);
    if (!await _isNetworkAvailable()) {
      return _submitVoteLocallyOrThrow(
        pollId: pollId,
        optionId: optionId,
        voteId: voteId,
      );
    }

    try {
      final updated = await remoteDataSource.submitVote(
        pollId: pollId,
        optionId: optionId,
        idempotencyKey: voteId,
      );
      await localDataSource.cacheUpdatedPoll(updated);
      // Server has accepted a vote for this poll, so any pending local copy is obsolete.
      await outboxLocalDataSource.clearForPoll(pollId);
      return updated;
    } on NetworkException {
      // Optimistically patch local cache and queue replay when offline/unreachable.
      return _submitVoteLocallyOrThrow(
        pollId: pollId,
        optionId: optionId,
        voteId: voteId,
      );
    } on RequestTimeoutException {
      // Treat timeouts as transient connectivity issues for better UX.
      return _submitVoteLocallyOrThrow(
        pollId: pollId,
        optionId: optionId,
        voteId: voteId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw UnknownException('Failed to submit vote: $error');
    }
  }

  Future<Poll> _submitVoteLocallyOrThrow({
    required String pollId,
    required String optionId,
    required String voteId,
  }) async {
    final cached = await localDataSource.getCachedActivePolls();
    final hasPoll = cached.any((poll) => poll.id == pollId);
    if (!hasPoll) {
      throw const NetworkException(
        'Unable to submit vote offline because poll is not cached.',
      );
    }
    final existing = cached.firstWhere((poll) => poll.id == pollId);
    if (existing.hasVoted && existing.selectedOptionId != null) {
      return existing;
    }
    final updated = existing.copyWith(
      hasVoted: true,
      selectedOptionId: optionId,
      options: existing.options
          .map(
            (option) => option.id == optionId
                ? option.copyWith(votes: option.votes + 1)
                : option,
          )
          .toList(),
    );
    await outboxLocalDataSource.enqueueVote(
      pollId: pollId,
      optionId: optionId,
      voteId: voteId,
    );
    await localDataSource.cacheUpdatedPoll(PollModel.fromEntity(updated));
    return updated;
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _newIdempotencyKey({
    required String pollId,
    required String optionId,
  }) {
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'vote-$micros-${pollId.hashCode.abs()}-${optionId.hashCode.abs()}';
  }
}
