import 'package:equatable/equatable.dart';

abstract class PollsEvent extends Equatable {
  const PollsEvent();

  @override
  List<Object?> get props => [];
}

class LoadPollsRequested extends PollsEvent {
  const LoadPollsRequested();
}

class VotePollRequested extends PollsEvent {
  final String pollId;
  final String optionId;

  const VotePollRequested({required this.pollId, required this.optionId});

  @override
  List<Object?> get props => [pollId, optionId];
}
