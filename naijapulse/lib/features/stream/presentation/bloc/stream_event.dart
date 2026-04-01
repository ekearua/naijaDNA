import 'package:equatable/equatable.dart';
import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';

abstract class StreamEvent extends Equatable {
  const StreamEvent();

  @override
  List<Object?> get props => [];
}

class LoadStreamsRequested extends StreamEvent {
  const LoadStreamsRequested({this.category, this.silent = false});

  final String? category;
  final bool silent;

  @override
  List<Object?> get props => [category, silent];
}

class LoadStreamSessionRequested extends StreamEvent {
  const LoadStreamSessionRequested(this.streamId, {this.initialSession});

  final String streamId;
  final StreamSession? initialSession;

  @override
  List<Object?> get props => [streamId, initialSession];
}

class CreateLiveStreamRequested extends StreamEvent {
  const CreateLiveStreamRequested({
    required this.title,
    required this.category,
    this.description,
    this.coverImageUrl,
    this.streamUrl,
  });

  final String title;
  final String category;
  final String? description;
  final String? coverImageUrl;
  final String? streamUrl;

  @override
  List<Object?> get props => [
    title,
    category,
    description,
    coverImageUrl,
    streamUrl,
  ];
}

class ScheduleStreamRequested extends StreamEvent {
  const ScheduleStreamRequested({
    required this.title,
    required this.category,
    required this.scheduledFor,
    this.description,
    this.coverImageUrl,
    this.streamUrl,
  });

  final String title;
  final String category;
  final DateTime scheduledFor;
  final String? description;
  final String? coverImageUrl;
  final String? streamUrl;

  @override
  List<Object?> get props => [
    title,
    category,
    scheduledFor,
    description,
    coverImageUrl,
    streamUrl,
  ];
}

class StartStreamRequested extends StreamEvent {
  const StartStreamRequested(this.streamId);

  final String streamId;

  @override
  List<Object?> get props => [streamId];
}

class EndStreamRequested extends StreamEvent {
  const EndStreamRequested(this.streamId);

  final String streamId;

  @override
  List<Object?> get props => [streamId];
}

class UpdateStreamPresenceRequested extends StreamEvent {
  const UpdateStreamPresenceRequested({
    required this.streamId,
    required this.action,
  });

  final String streamId;
  final String action;

  @override
  List<Object?> get props => [streamId, action];
}

class ClearStreamActionRequested extends StreamEvent {
  const ClearStreamActionRequested();
}
