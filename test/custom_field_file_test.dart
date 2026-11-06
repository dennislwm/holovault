import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/custom_field_file.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/screens/collection_list_screen.dart';

// REQ-047: a registry holding all six types (the real one has no int or bool).
// Callbacks are never called by the pure builder or parser.
final _all = <CustomColumn>[
  for (final t in CustomColumnType.values)
    CustomColumn(t.name, t, (r) => null, (tbl) => tbl.serialNo),
];

String _file(Object? rows, {Object? version = 1, Object? format = customFieldsFormat}) =>
    jsonEncode({'format': format, 'version': version, 'rows': rows});

Map<String, Object?> _row(String id, Object? values) =>
    {'importedId': id, 'values': values};

String? _refusal(String text, [List<CustomColumn>? reg]) =>
    parseCustomFieldsFile(text, reg ?? _all).refusal;

void main() {
  group('REQ-047 export builder (pure)', () {
    final when = DateTime(2026, 11, 6, 13, 30, 5);
    final rows = [
      (
        importedId: 'a',
        values: <String, Object?>{
          'text': 't',
          'choice': 'c',
          'int': 7,
          'real': 1.5,
          'bool': false,
          'date': when,
          'undeclared': 'ignored',
        },
      ),
      (importedId: 'b', values: <String, Object?>{}),
    ];

    test('every type, null for unset, declared columns only', () {
      final doc = jsonDecode(buildCustomFieldsFile(rows, _all)) as Map;
      expect(doc['format'], 'holovault-custom-fields');
      expect(doc['version'], 1);
      final out = doc['rows'] as List;
      expect(out[0], {
        'importedId': 'a',
        'values': {
          'text': 't',
          'choice': 'c',
          'int': 7,
          'real': 1.5,
          'bool': false,
          'date': '2026-11-06T13:30:05.000',
        },
      });
      expect((out[1] as Map)['values'], {
        for (final c in _all) c.name: null,
      });
    });

    test('output is stable and 2-space indented', () {
      final a = buildCustomFieldsFile(rows, _all);
      expect(buildCustomFieldsFile(rows, _all), a);
      expect(a, contains('\n  "format": "holovault-custom-fields",\n  "version": 1,'));
    });

    test('round trip through the parser', () {
      final parsed = parseCustomFieldsFile(buildCustomFieldsFile(rows, _all), _all);
      expect(parsed.refusal, isNull);
      expect(parsed.rows![0].values['date'], when);
      expect(parsed.rows![0].values['int'], 7);
      expect(parsed.rows![1].values['text'], isNull);
    });
  });

  group('REQ-047 import parser (pure)', () {
    test('every refusal names its reason', () {
      expect(_refusal('{nope'), contains('not valid JSON'));
      expect(_refusal('[]'), contains('not a $customFieldsFormat'));
      expect(_refusal(_file([], format: 'other')), contains('not a'));
      expect(_refusal(_file([], version: 2)), contains('version'));
      expect(_refusal(jsonEncode({'format': customFieldsFormat, 'version': 1})),
          contains('no rows list'));
      expect(_refusal(_file([5])), contains('row 1 is not an object'));
      expect(_refusal(_file([{'values': {}}])), contains('row 1 has no importedId'));
      expect(_refusal(_file([_row('', {})])), contains('no importedId'));
      expect(_refusal(_file([_row('a', {}), _row('a', {})])), contains('row 2 repeats'));
      expect(_refusal(_file([_row('a', [])])), contains('row 1 has no values'));
    });

    test('wrong-typed value refuses, naming row and field', () {
      for (final bad in <(String, Object?)>[
        ('text', 1),
        ('choice', true),
        ('int', 1.5),
        ('int', '1'),
        ('real', '1.5'),
        ('bool', 'true'),
        ('bool', 1),
        ('date', 'not a date'),
        ('date', 5),
      ]) {
        expect(
          _refusal(_file([_row('a', {'text': 'ok'}), _row('b', {bad.$1: bad.$2})])),
          contains('row 2 field ${bad.$1}'),
          reason: '$bad',
        );
      }
    });

    test('valid values and nulls pass; whole real-valued int accepted', () {
      final p = parseCustomFieldsFile(
        _file([
          _row('a', {'int': 3.0, 'real': 2, 'bool': true, 'date': '2026-01-02T03:04:05', 'text': null}),
        ]),
        _all,
      );
      expect(p.refusal, isNull);
      expect(p.rows!.single.values, {
        'int': 3,
        'real': 2.0,
        'bool': true,
        'date': DateTime(2026, 1, 2, 3, 4, 5),
        'text': null,
      });
    });

    test('undeclared key skipped; absent column absent, present null kept', () {
      final p = parseCustomFieldsFile(
        _file([_row('a', {'gone': 1, 'text': null})]),
        _all,
      );
      expect(p.rows!.single.values, {'text': null});
      expect(p.rows!.single.values.containsKey('real'), isFalse);
      expect(p.rows!.single.values.containsKey('gone'), isFalse);
    });
  });

  group('REQ-047 real store', () {
    late Directory dir;
    late AppDatabase db;
    final reg = [
      customColumns.firstWhere((c) => c.name == 'serialNo'),
      customColumns.firstWhere((c) => c.name == 'addCost'),
      customColumns.firstWhere((c) => c.name == 'eventDate'),
    ];

    Future<String> snapshot() async => buildCustomFieldsFile(await db.overrideRows());

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('holovault_cff_');
      db = AppDatabase.withExecutor(NativeDatabase(File('${dir.path}/t.sqlite')));
      await db.upsertItem(CollectionItemsCompanion.insert(importedId: 'c1', name: 'Charizard'));
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('export includes a dormant row (no collection item)', () async {
      await db.saveCustomFields('c1', {'serialNo': 'S1', 'eventDate': DateTime(2026, 2, 3, 4, 5)});
      await db.saveCustomFields('gone', {'addCost': 9.5});
      final doc = jsonDecode(buildCustomFieldsFile(await db.overrideRows(registry: reg), reg)) as Map;
      final rows = doc['rows'] as List;
      expect(rows.map((r) => (r as Map)['importedId']), ['c1', 'gone']);
      expect((rows[0] as Map)['values'], {
        'serialNo': 'S1',
        'addCost': null,
        'eventDate': '2026-02-03T04:05:00.000',
      });
      expect((rows[1] as Map)['values']['addCost'], 9.5);
    });

    test('import upserts, leaves item rows alone, twice is the same, absent keys keep, null clears', () async {
      await db.saveCustomFields('c1', {'serialNo': 'old', 'addCost': 1.0});
      final items = await db.select(db.collectionItems).get();
      final text = _file([
        _row('c1', {'serialNo': null, 'eventDate': '2026-02-03T04:05:00', 'junk': 1}),
        _row('dormant', {'addCost': 4.5}),
      ]);
      Future<void> doImport() async {
        final p = parseCustomFieldsFile(text, reg);
        await db.importCustomFieldRows(p.rows!, registry: reg);
      }

      await doImport();
      final once = await snapshot();
      await doImport();
      expect(await snapshot(), once);

      final c1 = (await db.overrideRows()).firstWhere((r) => r.importedId == 'c1');
      expect(c1.values['serialNo'], isNull); // present null clears
      expect(c1.values['addCost'], 1.0); // absent key untouched
      expect(c1.values['eventDate'], DateTime(2026, 2, 3, 4, 5));
      expect((await db.overrideRows()).map((r) => r.importedId), ['c1', 'dormant']);
      expect(await db.select(db.collectionItems).get(), items);
    });

    test('a refused file writes nothing', () async {
      await db.saveCustomFields('c1', {'serialNo': 'keep'});
      final before = await snapshot();
      final p = parseCustomFieldsFile(
        _file([_row('c1', {'serialNo': 'new'}), _row('x', {'addCost': 'bad'})]),
        reg,
      );
      expect(p.rows, isNull);
      expect(p.refusal, contains('row 2 field addCost'));
      // The screen only calls importCustomFieldRows when rows is non-null.
      expect(await snapshot(), before);
    });

    test('REQ-048 importCustomFieldsText: refusals write nothing, valid writes', () async {
      await db.saveCustomFields('c1', {'serialNo': 'keep'});
      final before = await snapshot();
      final refused = <(String, String)>[
        ('{nope', 'Custom field import refused: the file is not valid JSON'),
        (_file([], version: 2), 'Custom field import refused: unknown format version 2'),
        (
          _file([_row('c1', {'serialNo': 'new'}), _row('x', {'addCost': 'bad'})]),
          'Custom field import refused: row 2 field addCost does not fit its real type',
        ),
      ];
      for (final (text, msg) in refused) {
        expect(await importCustomFieldsText(db, text, reg), msg);
        expect(await snapshot(), before);
      }
      final ok = _file([_row('c1', {'serialNo': 'new'}), _row('x', {'addCost': 2.5})]);
      expect(await importCustomFieldsText(db, ok, reg), 'Imported 2 custom field row(s)');
      final rows = await db.overrideRows();
      expect(rows.map((r) => r.importedId), ['c1', 'x']);
      expect(rows[0].values['serialNo'], 'new');
      expect(rows[1].values['addCost'], 2.5);
    });

    test('REQ-048 round trip through two real stores gives the same file', () async {
      await db.saveCustomFields('c1', {
        'serialNo': 'S1',
        'addCost': null,
        'eventDate': DateTime(2026, 2, 3, 4, 5, 6),
      });
      await db.saveCustomFields('gone', {'serialNo': 'D', 'addCost': 9.5});
      final first = buildCustomFieldsFile(await db.overrideRows());
      final dir2 = Directory.systemTemp.createTempSync('holovault_cff2_');
      final db2 = AppDatabase.withExecutor(NativeDatabase(File('${dir2.path}/t.sqlite')));
      try {
        expect(await importCustomFieldsText(db2, first), 'Imported 2 custom field row(s)');
        expect(buildCustomFieldsFile(await db2.overrideRows()), first);
      } finally {
        await db2.close();
        dir2.deleteSync(recursive: true);
      }
    });

    test('importCustomFieldRows is one transaction: a failing row rolls back all', () async {
      await db.saveCustomFields('c1', {'serialNo': 'keep'});
      final before = await snapshot();
      // The second row holds a value SQLite cannot bind, so its write throws
      // after the first row's write succeeded.
      await expectLater(
        db.importCustomFieldRows([
          (importedId: 'c1', values: {'serialNo': 'changed'}),
          (importedId: 'c2', values: {'serialNo': Object()}),
        ], registry: reg),
        throwsA(anything),
      );
      expect(await snapshot(), before);
    });
  });

  testWidgets('REQ-047 wiring: overflow menu has both items, Import icon stays', (tester) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    await tester.pumpWidget(MaterialApp(home: CollectionListScreen(database: db)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.file_upload), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Export custom fields'), findsOneWidget);
    expect(find.text('Import custom fields'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(const Duration(minutes: 11));
    await db.close();
  });
}
