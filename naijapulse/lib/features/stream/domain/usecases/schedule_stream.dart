import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class ScheduleStream {
  const ScheduleStream(this._repository);

  final StreamRepository _repository;

  Future<StreamSession> call({
    required String title,
    required String category,
    required DateTime scheduledFor,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) {
    return _repository.scheduleStream(
      title: title,
      category: category,
      scheduledFor: scheduledFor,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
    );
  }
}
