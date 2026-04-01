import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final storage = await DriftWebStorage.indexedDbIfSupported(
      'naijapulse_cache',
    );
    return WebDatabase.withStorage(storage);
  });
}
