import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';

import '../tool/generate_overrides_schema.dart';

void main() {
  group('REQ-043 (a) registry generation', () {
    final out = generateOverridesSchema([
      {'id': 1, 'name': 'preGrade', 'type': 'choice'},
      {'id': 2, 'name': 'seenOn', 'type': 'date'},
    ]);

    test('choice and date keep their type in the registry; storage differs', () {
      expect(out, contains('CustomColumnType.choice'));
      expect(out, contains('CustomColumnType.date'));
      expect(out, contains('TextColumn get preGrade'));
      expect(out, contains('DateTimeColumn get seenOn'));
    });

    test('an unknown type still fails loudly', () {
      expect(
        () => generateOverridesSchema([
          {'id': 1, 'name': 'x', 'type': 'money'},
        ]),
        throwsArgumentError,
      );
    });
  });

  group('REQ-043 (a) v3 -> v4 migration on a real store', () {
    late Directory dir;
    late File dbFile;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('holovault_mig');
      dbFile = File('${dir.path}/v3.sqlite');
      // Build the v3 shape: key-only overrides table, user_version 3.
      final db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('DROP TABLE collection_item_overrides');
      // A real v3 install predates the REQ-055 counter.
      await db.customStatement('DROP TABLE override_counter');
      await db.customStatement(
        'CREATE TABLE collection_item_overrides '
        '(imported_id TEXT NOT NULL UNIQUE)',
      );
      await db.customStatement(
        "INSERT INTO collection_item_overrides VALUES ('a1')",
      );
      await db.customStatement(
        "INSERT INTO collection_items (imported_id, name) VALUES ('a1', 'X')",
      );
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();
    });

    tearDown(() => dir.delete(recursive: true));

    Future<List<QueryRow>> overridesRows(AppDatabase db) =>
        db.customSelect('SELECT * FROM collection_item_overrides').get();

    test('keeps existing overrides rows and exposes the new columns', () async {
      final db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final rows = await overridesRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.data['imported_id'], 'a1');
      expect(customColumns.map((c) => c.name), [
        'serialNo', 'preGrade', 'addCost', 'releasePrice',
        'eventDate', 'eventName',
      ]);
      for (final c in customColumns) {
        expect(rows.single.data.containsKey(
          c.column(db.collectionItemOverrides).$name), isTrue);
      }
      final merged = await db.select(db.mergedItems).get();
      expect(merged.single.name, 'X');
      expect(merged.single.preGrade, isNull);
      await db.close();
    });

    test('running the migration twice changes nothing', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await overridesRows(db);
      await db.close();
      db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final rows = await overridesRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.data.length, 7);
      await db.close();
    });
  });
}
