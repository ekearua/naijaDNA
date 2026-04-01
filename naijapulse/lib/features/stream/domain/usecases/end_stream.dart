import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class EndStream {
  const EndStream(this._repository);

  final StreamRepository _repository;

  Future<StreamSession> call(String streamId) {
    return _repository.endStream(streamId);
  }
}
