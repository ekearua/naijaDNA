import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_active_polls.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_categories.dart';
import 'package:naijapulse/features/polls/domain/usecases/get_feed_tags.dart';
import 'package:naijapulse/features/polls/domain/usecases/submit_poll_vote.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_event.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_state.dart';

export 'polls_event.dart';
export 'polls_state.dart';

class PollsBloc extends Bloc<PollsEvent, PollsState> {
  PollsBloc({
    required GetActivePolls getActivePolls,
    required GetCategories getCategories,
    required GetFeedTags getFeedTags,
    required SubmitPollVote submitPollVote,
  }) : _getActivePolls = getActivePolls,
       _getCategories = getCategories,
       _getFeedTags = getFeedTags,
       _submitPollVote = submitPollVote,
       super(const PollsState()) {
    on<LoadPollsRequested>(_onLoadPollsRequested);
    on<VotePollRequested>(_onVotePollRequested);
  }

  final GetActivePolls _getActivePolls;
  final GetCategories _getCategories;
  final GetFeedTags _getFeedTags;
  final SubmitPollVote _submitPollVote;

  Future<void> _onLoadPollsRequested(
    LoadPollsRequested event,
    Emitter<PollsState> emit,
  ) async {
    emit(state.copyWith(status: PollsStatus.loading, errorMessage: null));
    try {
      final pollsFuture = _getActivePolls();
      final categoriesFuture = _getCategories();
      final tagsFuture = _getFeedTags();
      final polls = await pollsFuture;
      final categories = await categoriesFuture;
      final tags = await tagsFuture;
      emit(
        state.copyWith(
          status: PollsStatus.loaded,
          polls: polls,
          categories: categories,
          feedTags: tags,
        ),
      );
    } catch (error) {
      final failure = mapFailure(error);
      emit(
        state.copyWith(
          status: PollsStatus.error,
          errorMessage: failure.message,
        ),
      );
    }
  }

  Future<void> _onVotePollRequested(
    VotePollRequested event,
    Emitter<PollsState> emit,
  ) async {
    emit(state.copyWith(status: PollsStatus.submitting, errorMessage: null));
    try {
      final updated = await _submitPollVote(
        pollId: event.pollId,
        optionId: event.optionId,
      );
      final polls = state.polls
          .map((poll) => poll.id == updated.id ? updated : poll)
          .toList();
      emit(state.copyWith(status: PollsStatus.loaded, polls: polls));
    } catch (error) {
      final failure = mapFailure(error);
      emit(
        state.copyWith(
          status: PollsStatus.error,
          errorMessage: failure.message,
        ),
      );
    }
  }
}
