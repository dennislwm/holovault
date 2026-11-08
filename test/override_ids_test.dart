import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/custom_field_file.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';

import '../tool/generate_overrides_schema.dart';
import 'helpers.dart';

CustomColumn _col(int? id, String name) => (
      id: id,
      name: name,
      type: CustomColumnType.text,
      value: (r) => null,
      column: (t) => t.serialNo,
    );

void main() {
  group('REQ-055 ids in the generator', () {
    test('a missing, bad or repeated id or name fails before any output', () {
      Map<String, dynamic> e(Object? id, Object? name) => {
            if (id != null) 'id': id,
            if (name != null) 'name': name,
            'type': 'text',
          };
      final bad = <String, List<Map<String, dynamic>>>{
        'missing id': [e(null, 'a')],
        'non-integer id': [e(1.5, 'a')],
        'zero id': [e(0, 'a')],
        'negative id': [e(-2, 'a')],
        'duplicate id': [e(1, 'a'), e(1, 'b')],
        'missing name': [e(1, null)],
        'name that is not an identifier': [e(1, 'Serial No')],
        'duplicate name': [e(1, 'a'), e(2, 'a')],
      };
      bad.forEach((label, entries) {
        expect(
          () => generateOverridesSchema(entries),
          throwsArgumentError,
          reason: label,
        );
      });
    });

    test('a rename keeps the physical column: same id, new name, same cf<id>', () {
      final before = generateOverridesSchema([
        {'id': 1, 'name': 'serialNo', 'type': 'text'},
      ]);
      final after = generateOverridesSchema([
        {'id': 1, 'name': 'psaSerial', 'type': 'text'},
      ]);
      expect(before, contains("TextColumn get serialNo => text().named('cf1')"));
      expect(after, contains("TextColumn get psaSerial => text().named('cf1')"));
      expect(after, contains('(id: 1, name: \'psaSerial\''));
    });
  });

  group('REQ-055 ids in the list ids and the export file', () {
    test('a stored field is cf<id>, found by id after a rename; old name-keyed ids are skipped', () {
      expect(customIdFor(_col(3, 'a')), 'cf3');
      expect(customIdFor(_col(null, 'language')), 'cf.language');
      expect(customColumnFor('cf3', [_col(3, 'renamed')])?.name, 'renamed');
      expect(customColumnFor('cf.a', [_col(3, 'a')]), isNull);
      expect(customColumnFor('cf9', [_col(3, 'a')]), isNull);
      expect(customColumnFor('cf.language', [_col(null, 'language')]), isNotNull);
    });

    test('an export key is cf<id>, so a file written before a rename still imports', () {
      expect(customFileKey(_col(1, 'renamed')), 'cf1');
      final text = jsonEncode({
        'format': customFieldsFormat,
        'version': customFieldsVersion,
        'rows': [
          {'importedId': 'x', 'values': {'cf1': 'S1'}},
        ],
      });
      final p = parseCustomFieldsFile(text, [_col(1, 'renamed')]);
      expect(p.rows!.single.values, {'renamed': 'S1'});
    });
  });

  group('REQ-055 counter and recreate on a real store', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('holovault_ids');
      file = File('${dir.path}/t.sqlite');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    AppDatabase open() => AppDatabase.withExecutor(NativeDatabase(file));

    Future<List<Object?>> counter(AppDatabase db) async => [
          for (final r in await db.customSelect('SELECT value FROM override_counter').get())
            r.data['value'],
        ];

    Future<Set<String>> overrideColumns(AppDatabase db) async => {
          for (final r in await db.customSelect('PRAGMA table_info(collection_item_overrides)').get())
            r.read<String>('name'),
        };

    test('a fresh install writes the counter and has the id-keyed columns', () async {
      final db = open();
      expect(await counter(db), [overrideCounter]);
      expect(await overrideColumns(db), {
        'imported_id', 'cf1', 'cf2', 'cf3', 'cf4', 'cf5', 'cf6',
      });
      await db.close();
    });

    test('an install with a counter keeps its stored values across reopens', () async {
      var db = open();
      await seedItem(db, importedId: 'c1', name: 'X');
      await db.saveCustomFields('c1', {'serialNo': 'S1'});
      await db.close();
      db = open();
      expect((await db.mergedItemByImportedId('c1'))!.serialNo, 'S1');
      expect(await counter(db), [overrideCounter]);
      await db.close();
    });

    test('a stored counter above the generated one is left alone, values kept', () async {
      var db = open();
      await seedItem(db, importedId: 'c1', name: 'X');
      await db.saveCustomFields('c1', {'serialNo': 'S1'});
      await db.customStatement('UPDATE override_counter SET value = 99');
      await db.close();
      db = open();
      expect((await db.mergedItemByImportedId('c1'))!.serialNo, 'S1');
      expect(await counter(db), [99]);
      await db.close();
    });

    test('a name-keyed install with no counter is recreated once and keeps its imported ids', () async {
      var db = open();
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('DROP TABLE collection_item_overrides');
      await db.customStatement('DROP TABLE override_counter');
      await db.customStatement(
        'CREATE TABLE collection_item_overrides '
        '(imported_id TEXT NOT NULL UNIQUE, serial_no TEXT)',
      );
      await db.customStatement(
        "INSERT INTO collection_item_overrides VALUES ('a1', 'old')",
      );
      await db.close();

      db = open();
      expect(await counter(db), [overrideCounter]);
      expect(await overrideColumns(db), contains('cf1'));
      expect(await overrideColumns(db), isNot(contains('serial_no')));
      expect(
        (await db.customSelect('SELECT imported_id FROM collection_item_overrides').get())
            .single
            .data['imported_id'],
        'a1',
      );
      // A value typed after the recreate survives the next open: it ran once.
      await seedItem(db, importedId: 'a1', name: 'X');
      await db.saveCustomFields('a1', {'serialNo': 'S2'});
      await db.close();
      db = open();
      expect((await db.mergedItemByImportedId('a1'))!.serialNo, 'S2');
      await db.close();
    });

    test('an install at version 1 ends with id-keyed columns and the counter, once', () async {
      // The v1 shape: only the key, name and extra columns, no other table.
      var db = open();
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('DROP TABLE collection_item_overrides');
      await db.customStatement('DROP TABLE override_counter');
      await db.customStatement('DROP TABLE set_lookup_rows');
      await db.customStatement('DROP TABLE collection_items');
      await db.customStatement(
        'CREATE TABLE collection_items (id INTEGER NOT NULL PRIMARY KEY '
        'AUTOINCREMENT, imported_id TEXT NOT NULL UNIQUE, name TEXT NOT NULL, '
        'extra TEXT NULL)',
      );
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      db = open();
      expect(await counter(db), [overrideCounter]);
      expect(await overrideColumns(db), contains('cf1'));
      await seedItem(db, importedId: 'c1', name: 'X');
      await db.saveCustomFields('c1', {'serialNo': 'S1'});
      await db.close();
      db = open();
      expect((await db.mergedItemByImportedId('c1'))!.serialNo, 'S1');
      await db.close();
    });
  });
}
