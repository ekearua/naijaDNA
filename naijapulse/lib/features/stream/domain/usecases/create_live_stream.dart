import 'package:naijapulse/features/stream/domain/entities/stream_session.dart';
import 'package:naijapulse/features/stream/domain/repository/stream_repository.dart';

class CreateLiveStream {
  const CreateLiveStream(this._repository);

  final StreamRepository _repository;

  Future<StreamSession> call({
    required String title,
    required String category,
    String? description,
    String? coverImageUrl,
    String? streamUrl,
  }) {
    return _repository.createLiveStream(
      title: title,
      category: category,
      description: description,
      coverImageUrl: coverImageUrl,
      streamUrl: streamUrl,
    );
  }
}
