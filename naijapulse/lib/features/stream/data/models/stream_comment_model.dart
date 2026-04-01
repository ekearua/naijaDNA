import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';

class StreamCommentModel extends StreamComment {
  const StreamCommentModel({
    required super.id,
    required super.streamId,
    required super.authorName,
    required super.body,
    required super.createdAt,
    super.userId,
  });

  factory StreamCommentModel.fromJson(Map<String, dynamic> json) {
    return StreamCommentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      streamId: (json['streamId'] ?? json['stream_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id']) as String?,
      authorName: (json['authorName'] ?? json['author_name'] ?? 'User').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.toString().trim();
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
