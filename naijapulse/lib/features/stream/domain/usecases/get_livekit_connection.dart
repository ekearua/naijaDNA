import 'package:naijapulse/features/stream/domain/entities/stream_livekit_connection.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class GetLiveKitConnection {
  const GetLiveKitConnection(this._repository);

  final StreamRepository _repository;

  Future<StreamLiveKitConnection> call(String streamId) {
    return _repository.getLiveKitConnection(streamId);
  }
}
