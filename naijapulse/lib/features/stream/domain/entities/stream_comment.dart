import 'package:equatable/equatable.dart';

class StreamComment extends Equatable {
  const StreamComment({
    required this.id,
    required this.streamId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.userId,
  });

  final int id;
  final String streamId;
  final String? userId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, streamId, userId, authorName, body, createdAt];
}
