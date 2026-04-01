import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class GetScheduledStreams {
  const GetScheduledStreams(this._repository);

  final StreamRepository _repository;

  Future<List<StreamSession>> call({String? category}) {
    return _repository.getScheduledStreams(category: category);
  }
}
