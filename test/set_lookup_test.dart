import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/set_lookup.dart';
import 'package:holovault/set_lookup_file.dart';

import 'helpers.dart';

// REQ-052 (ADR-24 Option 3). Rows shaped like data/set_language.json.
Map<String, Object?> _alias(String name, {String app = 'shiny', Object? by = 'exact'}) => {
      'app': app,
      'name': name,
      'resolved': {'by': by},
    };

Map<String, Object?> _set({
  Object? language = 'ja',
  Object? id = const {'tcgdex': 'S8a'},
  Object? name = 'Official',
  Object? alias,
}) =>
    {'language': language, 'id': id, 'name': name, 'alias': alias ?? [_alias('Set A')]};

String _file(Object? sets) => jsonEncode(sets);

String? _refusal(Object? sets) => parseSetLookupFile(_file(sets)).refusal;

void main() {
  group('REQ-052 parser (pure)', () {
    test('keeps only shiny aliases the file resolved exact; reads id and name variants', () {
      final p = parseSetLookupFile(_file([
        _set(alias: [_alias('Set A'), _alias('Model pick', by: 'jev'), _alias('Other app', app: 'x')]),
        _set(language: 'en', id: {'artofpkm': 'S-P'}, name: {'artofpkm': 'Promo'}, alias: [_alias('Promo')]),
        _set(language: 'zh-cn', id: null, name: null, alias: [_alias('Bare')]),
      ]));
      expect(p.refusal, isNull);
      expect(p.rows, [
        (aliasName: 'Set A', language: 'ja', tcgdexId: 'S8a', officialName: 'Official'),
        (aliasName: 'Promo', language: 'en', tcgdexId: null, officialName: 'Promo'),
        (aliasName: 'Bare', language: 'zh-cn', tcgdexId: null, officialName: null),
      ]);
    });

    test('a name object prefers tcgdex over artofpkm', () {
      final p = parseSetLookupFile(_file([
        _set(name: {'artofpkm': 'B', 'tcgdex': 'A'}),
      ]));
      expect(p.rows!.single.officialName, 'A');
    });

    test('refuses the whole file, with a reason, on any structural error', () {
      final cases = <String, String?>{
        'not valid JSON': parseSetLookupFile('{nope').refusal,
        'not a list': parseSetLookupFile('{}').refusal,
        'set 1 is not an object': _refusal(['x']),
        'set 1 has no language': _refusal([_set(language: null)]),
        'set 1 has an id that is not an object': _refusal([_set(id: 'S8a')]),
        'tcgdex id that is not text': _refusal([_set(id: {'tcgdex': 5})]),
        'name that is not text, an object or null': _refusal([_set(name: 7)]),
        'name that is not text': _refusal([_set(name: {'tcgdex': 7})]),
        'set 1 has no alias list': _refusal([_set(alias: 'x')]),
        'alias 1 is not an object': _refusal([_set(alias: ['x'])]),
        'alias 1 has no resolved.by': _refusal([_set(alias: [{'app': 'shiny', 'name': 'A'}])]),
        'repeats the alias name': _refusal([_set(alias: [_alias('Set A'), _alias('Set A')])]),
        'no exact shiny aliases': _refusal([_set(alias: [_alias('Set A', by: 'jev')])]),
      };
      cases.forEach((expected, actual) {
        expect(actual, isNotNull, reason: expected);
        expect(actual, contains(expected), reason: expected);
      });
    });

    test('a refusal later in the file refuses everything before it too', () {
      final p = parseSetLookupFile(_file([_set(), 'x']));
      expect(p.rows, isNull);
      expect(p.refusal, contains('set 2'));
    });
  });

  group('REQ-052 lookup table (real store)', () {
    late Directory dir;
    late AppDatabase db;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('holovault_sl_');
      db = AppDatabase.withExecutor(NativeDatabase(File('${dir.path}/t.sqlite')));
    });

    tearDown(() async {
      setLookup = {};
      await db.close();
      dir.deleteSync(recursive: true);
    });

    Future<List<String>> snapshot() async => [
          for (final r in await db.allSetLookupRows())
            '${r.aliasName}|${r.language}|${r.tcgdexId}|${r.officialName}',
        ]..sort();

    final good = _file([
      _set(alias: [_alias('Set A')]),
      _set(language: 'en', id: null, name: null, alias: [_alias('Set B')]),
    ]);

    test('a good file is stored; importing the same file twice changes nothing', () async {
      expect(await importSetLookupText(db, good), 'Set lookup imported: 2 set(s)');
      final first = await snapshot();
      expect(first, ['Set A|ja|S8a|Official', 'Set B|en|null|null']);
      await importSetLookupText(db, good);
      expect(await snapshot(), first);
    });

    test('a refused file writes nothing and keeps the previous lookup', () async {
      await importSetLookupText(db, good);
      final before = await snapshot();
      final msg = await importSetLookupText(db, _file([_set(language: null)]));
      expect(msg, startsWith('Set lookup import refused:'));
      expect(await snapshot(), before);
    });

    test('an import replaces the whole lookup, it does not merge', () async {
      await importSetLookupText(db, good);
      await importSetLookupText(db, _file([_set(alias: [_alias('Only')])]));
      expect(await snapshot(), ['Only|ja|S8a|Official']);
    });

    test('collection import and the overrides path never write the lookup', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
      }, testName: 'overrides path leaves set lookup unchanged');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      await importSetLookupText(db, good);
      final before = await snapshot();
      await seedItem(db, importedId: 'c1', name: 'X');
      await db.saveCustomFields('c1', {text.column.name: text.value}, registry: [text.column]);
      expect(await snapshot(), before);
    });
  });

  group('REQ-052 derived columns', () {
    MergedItem item(String name, String? setName) =>
        MergedItem(id: 1, importedId: name, name: name, setName: setName);

    setUp(() {
      setLookup = {
        'Set A': const SetLookupRow(
          aliasName: 'Set A',
          language: 'ja',
          tcgdexId: 'S8a',
          officialName: 'Official',
        ),
      };
    });

    tearDown(() => setLookup = {});

    test('values come from the row\'s set name; no match or no set name is blank', () {
      final byName = {for (final c in derivedColumns) c.name: c};
      expect(byName['language']!.value(item('a', 'Set A')), 'ja');
      expect(byName['setId']!.value(item('a', 'Set A')), 'S8a');
      expect(byName['setOfficialName']!.value(item('a', 'Set A')), 'Official');
      expect(byName['language']!.value(item('b', 'Unknown')), isNull);
      expect(byName['language']!.value(item('c', null)), isNull);
    });

    test('derived columns are read-side only; the stored registry never holds them', () {
      final stored = customColumns.map((c) => c.name).toSet();
      for (final d in derivedColumns) {
        expect(stored.contains(d.name), isFalse);
        expect(readColumns.contains(d), isTrue);
      }
      expect(readColumns.length, customColumns.length + derivedColumns.length);
    });

    test('a language clause filters through the existing custom path', () async {
      final items = [item('a', 'Set A'), item('b', 'Unknown'), item('c', null)];
      final r = await filterCollectionItems(
        items,
        searchTerm: '',
        clauses: [
          SearchClause.custom(
            customFieldId: customId('language'),
            op: SearchOperator.equal,
            value: 'ja',
          ),
        ],
      );
      expect(r.map((i) => i.name), ['a']);
      expect(distinctValuesForId(customId('language'), items), ['ja']);
    });
  });

  group('REQ-052 v4 -> v5 migration on a real store', () {
    late Directory dir;
    late File dbFile;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('holovault_mig5');
      dbFile = File('${dir.path}/v4.sqlite');
      // Build the v4 shape: no lookup table, user_version 4, one item, one override.
      final db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await db.customStatement('DROP TABLE set_lookup_rows');
      // A real v4 install: name-keyed override column, no REQ-055 counter.
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('DROP TABLE collection_item_overrides');
      await db.customStatement('DROP TABLE override_counter');
      await db.customStatement(
        'CREATE TABLE collection_item_overrides '
        '(imported_id TEXT NOT NULL UNIQUE, legacy_value TEXT)',
      );
      await db.customStatement(
        "INSERT INTO collection_items (imported_id, name) VALUES ('a1', 'X')",
      );
      await db.customStatement(
        "INSERT INTO collection_item_overrides (imported_id, legacy_value) VALUES ('a1', 'S1')",
      );
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();
    });

    tearDown(() => dir.delete(recursive: true));

    test('creates the lookup table and keeps every existing row', () async {
      final db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final live = firstLiveFieldOrSkip(
        db,
        testName: 'v4 migration keeps every existing row',
      );
      if (live == null) {
        await db.close();
        return;
      }
      expect(await db.allSetLookupRows(), isEmpty);
      final items = await db.customSelect('SELECT name FROM collection_items').get();
      expect(items.single.data['name'], 'X');
      // REQ-055: the overrides table is recreated with id-keyed columns; the
      // row key is kept, the old name-keyed value is not migrated (no values
      // exist under the old schema, operator 2026-11-08).
      final ov = await db.customSelect('SELECT * FROM collection_item_overrides').get();
      expect(ov.single.data['imported_id'], 'a1');
      expect(ov.single.data.containsKey(live.sqlName), isTrue);
      expect(ov.single.data.containsKey('legacy_value'), isFalse);
      await db.close();
    });

    test('running it a second time changes nothing', () async {
      var db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await db.replaceSetLookup([
        (aliasName: 'Set A', language: 'ja', tcgdexId: null, officialName: null),
      ]);
      await db.close();
      db = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final rows = await db.allSetLookupRows();
      expect(rows.map((r) => r.aliasName), ['Set A']);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 5);
      await db.close();
    });
  });
}
