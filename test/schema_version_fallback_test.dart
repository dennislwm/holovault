import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';

void main() {
  test(
    'REQ-017: onUpgrade throws UnsupportedSchemaVersionException for an '
    'unrecognized schema version (e.g. a rolled-back app build) instead of '
    'silently no-op-ing',
    () async {
      final dir = await Directory.systemTemp.createTemp('holovault_test');
      addTearDown(() => dir.delete(recursive: true));
      final dbFile = File('${dir.path}/stale.sqlite');

      // Seed a stored user_version (4) ahead of anything AppDatabase's
      // current migration.onUpgrade branches handle (from < 2, from < 3) --
      // the shape of a rollback to an older app build.
      final db = AppDatabase.withExecutor(
        NativeDatabase(
          dbFile,
          setup: (rawDb) => rawDb.execute('PRAGMA user_version = 4'),
        ),
      );

      await expectLater(
        db.select(db.collectionItems).get(),
        throwsA(isA<UnsupportedSchemaVersionException>()),
      );
      await db.close();
    },
  );
}
