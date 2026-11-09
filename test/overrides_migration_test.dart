import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';

import '../tool/generate_overrides_schema.dart';
import 'helpers.dart';

void main() {
  group('REQ-043 (a) registry generation', () {
    final choice = testCustomColumns.firstWhere((c) => c.type == CustomColumnType.choice);
    final date = testCustomColumns.firstWhere((c) => c.type == CustomColumnType.date);
    final out = generateOverridesSchema([
      {'id': 1, 'name': choice.name, 'type': 'choice'},
      {'id': 2, 'name': date.name, 'type': 'date'},
    ]);

    test('choice and date keep their type in the registry; storage differs', () {
      expect(out, contains('CustomColumnType.choice'));
      expect(out, contains('CustomColumnType.date'));
      expect(out, contains('TextColumn get ${choice.name}'));
      expect(out, contains('DateTimeColumn get ${date.name}'));
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
      if (customColumns.isEmpty) {
        await db.close();
        markTestSkipped('REQ-057 SKIP: migration registry assertions require a live field');
        return;
      }
      final rows = await overridesRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.data['imported_id'], 'a1');
      expect(rows.single.data.keys.toSet(), {
        for (final c in db.collectionItemOverrides.$columns) c.name,
      });
      for (final c in customColumns) {
        expect(rows.single.data.containsKey(
          c.column(db.collectionItemOverrides).$name), isTrue);
      }
      final merged = await db.select(db.mergedItems).get();
      expect(merged.single.name, 'X');
      for (final c in customColumns) {
        expect(c.value(merged.single), isNull, reason: c.name);
      }
      await db.close();
    });

    test('running the migration twice changes nothing', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await overridesRows(db);
      await db.close();
      db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final rows = await overridesRows(db);
      expect(rows, hasLength(1));
      expect(rows.single.data.length, db.collectionItemOverrides.$columns.length);
      await db.close();
    });
  });
}
