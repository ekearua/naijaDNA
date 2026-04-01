import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class StartStream {
  const StartStream(this._repository);

  final StreamRepository _repository;

  Future<StreamSession> call(String streamId) {
    return _repository.startStream(streamId);
  }
}
