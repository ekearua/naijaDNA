import 'package:equatable/equatable.dart';

class StreamSession extends Equatable {
  const StreamSession({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.viewerCount,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverImageUrl,
    this.streamUrl,
    this.hostUserId,
    this.hostName,
    this.scheduledFor,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final int viewerCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? coverImageUrl;
  final String? streamUrl;
  final String? hostUserId;
  final String? hostName;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isLive => status.toLowerCase() == 'live';
  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isEnded => status.toLowerCase() == 'ended';

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    status,
    viewerCount,
    createdAt,
    updatedAt,
    description,
    coverImageUrl,
    streamUrl,
    hostUserId,
    hostName,
    scheduledFor,
    startedAt,
    endedAt,
  ];
}
