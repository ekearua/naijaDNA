import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class GetStreamComments {
  const GetStreamComments(this._repository);

  final StreamRepository _repository;

  Future<List<StreamComment>> call(String streamId) {
    return _repository.getStreamComments(streamId);
  }
}
