import 'package:naijapulse/features/stream/domain/entities/stream_comment.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class SendStreamComment {
  const SendStreamComment(this._repository);

  final StreamRepository _repository;

  Future<StreamComment> call({
    required String streamId,
    required String body,
  }) {
    return _repository.sendStreamComment(streamId: streamId, body: body);
  }
}
