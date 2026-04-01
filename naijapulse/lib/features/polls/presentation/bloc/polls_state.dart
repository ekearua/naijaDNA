import 'package:equatable/equatable.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';
import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';

enum PollsStatus { initial, loading, loaded, submitting, error }

class PollsState extends Equatable {
  final PollsStatus status;
  final List<Poll> polls;
  final List<PollCategory> categories;
  final List<PollCategory> feedTags;
  final String? errorMessage;

  const PollsState({
    this.status = PollsStatus.initial,
    this.polls = const [],
    this.categories = const [],
    this.feedTags = const [],
    this.errorMessage,
  });

  PollsState copyWith({
    PollsStatus? status,
    List<Poll>? polls,
    List<PollCategory>? categories,
    List<PollCategory>? feedTags,
    String? errorMessage,
  }) {
    return PollsState(
      status: status ?? this.status,
      polls: polls ?? this.polls,
      categories: categories ?? this.categories,
      feedTags: feedTags ?? this.feedTags,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    polls,
    categories,
    feedTags,
    errorMessage,
  ];
}
