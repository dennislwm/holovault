import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/custom_field_logic.dart';
import 'package:holovault/database/database.dart';

void main() {
  test('REQ-055 fingerprint: a rename, retype or reorder changes it, never 0', () {
    final base = configFingerprint(['a:text', 'b:real']);
    expect(configFingerprint(['a:text', 'b:real']), base);
    expect(configFingerprint(['a:text', 'c:real']), isNot(base));
    expect(configFingerprint(['a:text', 'b:int']), isNot(base));
    expect(configFingerprint(['b:real', 'a:text']), isNot(base));
    expect(configFingerprint([]), isNot(0));
  });

  group('REQ-055 installed database follows a config change (real store)', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('holovault_cfgchg');
      file = File('${dir.path}/t.sqlite');
      final db = AppDatabase.withExecutor(NativeDatabase(file));
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'a1', name: 'X'),
      );
      await db.saveCustomFields('a1', {'serialNo': 'S1'});
      await db.close();
    });

    tearDown(() => dir.delete(recursive: true));

    Future<String?> serial(AppDatabase db) async =>
        (await db.mergedItemByImportedId('a1'))?.serialNo;

    test('an unchanged config keeps the stored values on every open', () async {
      for (var i = 0; i < 2; i++) {
        final db = AppDatabase.withExecutor(NativeDatabase(file));
        expect(await serial(db), 'S1');
        await db.close();
      }
    });

    test('a different stamp rebuilds the table, keeps items, then settles', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(file));
      await db.customStatement('PRAGMA application_id = 12345');
      await db.close();

      db = AppDatabase.withExecutor(NativeDatabase(file));
      final merged = await db.mergedItemByImportedId('a1');
      expect(merged?.name, 'X');
      expect(merged?.serialNo, isNull);
      await db.saveCustomFields('a1', {'serialNo': 'S2'});
      await db.close();

      db = AppDatabase.withExecutor(NativeDatabase(file));
      expect(await serial(db), 'S2');
      await db.close();
    });

    test('a missing column on an unstamped install is rebuilt in', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(file));
      await db.customStatement('DROP TABLE collection_item_overrides');
      await db.customStatement(
        'CREATE TABLE collection_item_overrides '
        '(imported_id TEXT NOT NULL UNIQUE)',
      );
      await db.customStatement('PRAGMA application_id = 0');
      await db.close();

      db = AppDatabase.withExecutor(NativeDatabase(file));
      await db.saveCustomFields('a1', {'serialNo': 'S3'});
      expect(await serial(db), 'S3');
      await db.close();
    });

    test('an extra column on an unstamped install is rebuilt away', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(file));
      await db.customStatement(
        'ALTER TABLE collection_item_overrides ADD COLUMN stale TEXT',
      );
      await db.customStatement('PRAGMA application_id = 0');
      await db.close();

      db = AppDatabase.withExecutor(NativeDatabase(file));
      final cols = await db
          .customSelect('PRAGMA table_info(collection_item_overrides)')
          .get();
      expect(cols.map((r) => r.data['name']), isNot(contains('stale')));
      expect(await serial(db), isNull);
      await db.close();
    });
  });
}
