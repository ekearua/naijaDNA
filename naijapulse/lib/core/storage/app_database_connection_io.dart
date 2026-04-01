import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbFile = File(path.join(appDir.path, 'naijapulse_cache.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}
