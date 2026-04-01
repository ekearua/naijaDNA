import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class GetLiveStreams {
  const GetLiveStreams(this._repository);

  final StreamRepository _repository;

  Future<List<StreamSession>> call({String? category}) {
    return _repository.getLiveStreams(category: category);
  }
}
