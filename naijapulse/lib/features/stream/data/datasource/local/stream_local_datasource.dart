import 'package:naijapulse/core/error/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StreamLocalDataSource {
  Future<String> getOrCreateViewerId();
}

class StreamLocalDataSourceImpl implements StreamLocalDataSource {
  const StreamLocalDataSourceImpl({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  static const _viewerIdKey = 'stream_viewer_id_v1';

  final SharedPreferences _sharedPreferences;

  @override
  Future<String> getOrCreateViewerId() async {
    final cached = _sharedPreferences.getString(_viewerIdKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    final generated = 'viewer-${DateTime.now().microsecondsSinceEpoch}';
    final ok = await _sharedPreferences.setString(_viewerIdKey, generated);
    if (!ok) {
      throw const CacheException('Failed to persist stream viewer identity.');
    }
    return generated;
  }
}
