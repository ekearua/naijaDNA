import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';

class StreamSessionModel extends StreamSession {
  const StreamSessionModel({
    required super.id,
    required super.title,
    required super.category,
    required super.status,
    required super.viewerCount,
    required super.createdAt,
    required super.updatedAt,
    super.description,
    super.coverImageUrl,
    super.streamUrl,
    super.hostUserId,
    super.hostName,
    super.scheduledFor,
    super.startedAt,
    super.endedAt,
  });

  factory StreamSessionModel.fromJson(Map<String, dynamic> json) {
    return StreamSessionModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      category: (json['category'] ?? 'General').toString(),
      coverImageUrl:
          (json['coverImageUrl'] ?? json['cover_image_url']) as String?,
      streamUrl: (json['streamUrl'] ?? json['stream_url']) as String?,
      status: (json['status'] ?? 'scheduled').toString(),
      hostUserId: (json['hostUserId'] ?? json['host_user_id']) as String?,
      hostName: (json['hostName'] ?? json['host_name']) as String?,
      viewerCount:
          (json['viewerCount'] ?? json['viewer_count'] ?? 0) as int? ?? 0,
      scheduledFor: _parseDate(json['scheduledFor'] ?? json['scheduled_for']),
      startedAt: _parseDate(json['startedAt'] ?? json['started_at']),
      endedAt: _parseDate(json['endedAt'] ?? json['ended_at']),
      createdAt:
          _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt:
          _parseDate(json['updatedAt'] ?? json['updated_at']) ?? DateTime.now(),
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
