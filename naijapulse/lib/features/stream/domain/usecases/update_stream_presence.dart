import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class UpdateStreamPresence {
  const UpdateStreamPresence(this._repository);

  final StreamRepository _repository;

  Future<StreamSession> call({
    required String streamId,
    required String action,
  }) {
    return _repository.updatePresence(streamId: streamId, action: action);
  }
}
