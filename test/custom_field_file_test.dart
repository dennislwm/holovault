import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/custom_field_file.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/screens/collection_list_screen.dart';

import 'helpers.dart';

final _all = testCustomColumns;

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
          'testText': 't',
          'testChoice': 'c',
          'testInteger': 7,
          'testReal': 1.5,
          'testBool': false,
          'testDate': when,
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
          'testText': 't',
          'testChoice': 'c',
          'testInteger': 7,
          'testReal': 1.5,
          'testBool': false,
          'testDate': '2026-11-06T13:30:05.000',
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
      expect(parsed.rows![0].values['testDate'], when);
      expect(parsed.rows![0].values['testInteger'], 7);
      expect(parsed.rows![1].values['testText'], isNull);
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
        ('testText', 1),
        ('testChoice', true),
        ('testInteger', 1.5),
        ('testInteger', '1'),
        ('testReal', '1.5'),
        ('testBool', 'true'),
        ('testBool', 1),
        ('testDate', 'not a date'),
        ('testDate', 5),
      ]) {
        expect(
          _refusal(_file([_row('a', {'testText': 'ok'}), _row('b', {bad.$1: bad.$2})])),
          contains('row 2 field ${bad.$1}'),
          reason: '$bad',
        );
      }
    });

    test('valid values and nulls pass; whole real-valued int accepted', () {
      final p = parseCustomFieldsFile(
        _file([
          _row('a', {'testInteger': 3.0, 'testReal': 2, 'testBool': true, 'testDate': '2026-01-02T03:04:05', 'testText': null}),
        ]),
        _all,
      );
      expect(p.refusal, isNull);
      expect(p.rows!.single.values, {
        'testInteger': 3,
        'testReal': 2.0,
        'testBool': true,
        'testDate': DateTime(2026, 1, 2, 3, 4, 5),
        'testText': null,
      });
    });

    test('undeclared key skipped; absent column absent, present null kept', () {
      final p = parseCustomFieldsFile(
        _file([_row('a', {'gone': 1, 'testText': null})]),
        _all,
      );
      expect(p.rows!.single.values, {'testText': null});
      expect(p.rows!.single.values.containsKey('testReal'), isFalse);
      expect(p.rows!.single.values.containsKey('gone'), isFalse);
    });
  });

  group('REQ-047 real store', () {
    late Directory dir;
    late AppDatabase db;
    final reg = [
      testCustomColumns.firstWhere((c) => c.name == 'testText'),
      testCustomColumns.firstWhere((c) => c.name == 'testReal'),
      testCustomColumns.firstWhere((c) => c.name == 'testDate'),
    ];

    Future<String> snapshot([List<CustomColumn>? registry]) async {
      final columns = registry ?? reg;
      return buildCustomFieldsFile(await db.overrideRows(registry: columns), columns);
    }

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('holovault_cff_');
      db = AppDatabase.withExecutor(NativeDatabase(File('${dir.path}/t.sqlite')));
      await seedItem(db, importedId: 'c1', name: 'Charizard');
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('export includes a dormant row (no collection item)', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
        CustomColumnType.date,
      }, testName: 'export includes a dormant row');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final date = fields[CustomColumnType.date]!;
      final liveReg = [text.column, real.column, date.column];
      await db.saveCustomFields('c1', {text.column.name: text.value, date.column.name: date.value}, registry: liveReg);
      await db.saveCustomFields('gone', {real.column.name: real.value}, registry: liveReg);
      final doc = jsonDecode(buildCustomFieldsFile(await db.overrideRows(registry: liveReg), liveReg)) as Map;
      final rows = doc['rows'] as List;
      expect(rows.map((r) => (r as Map)['importedId']), ['c1', 'gone']);
      expect((rows[0] as Map)['values'], {
        text.sqlName: text.value,
        real.sqlName: null,
        date.sqlName: (date.value as DateTime).toIso8601String(),
      });
      expect((rows[1] as Map)['values'][real.sqlName], real.value);
    });

    test('import upserts, leaves item rows alone, twice is the same, absent keys keep, null clears', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
        CustomColumnType.date,
      }, testName: 'import upserts and is idempotent');
      if (fields == null) return;
      final textField = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final date = fields[CustomColumnType.date]!;
      final liveReg = [textField.column, real.column, date.column];
      await db.saveCustomFields('c1', {textField.column.name: textField.value, real.column.name: real.value}, registry: liveReg);
      final items = await db.select(db.collectionItems).get();
      final text = _file([
        _row('c1', {textField.sqlName: null, date.sqlName: (date.value as DateTime).toIso8601String(), 'junk': 1}),
        _row('dormant', {real.sqlName: sampleCustomValue(CustomColumnType.real, variant: 1)}),
      ]);
      Future<void> doImport() async {
        final p = parseCustomFieldsFile(text, liveReg);
        await db.importCustomFieldRows(p.rows!, registry: liveReg);
      }

      await doImport();
      final once = await snapshot(liveReg);
      await doImport();
      expect(await snapshot(liveReg), once);

      final c1 = (await db.overrideRows(registry: liveReg)).firstWhere((r) => r.importedId == 'c1');
      expect(c1.values[textField.column.name], isNull); // present null clears
      expect(c1.values[real.column.name], real.value); // absent key untouched
      expect(c1.values[date.column.name], date.value);
      expect((await db.overrideRows(registry: liveReg)).map((r) => r.importedId), ['c1', 'dormant']);
      expect(await db.select(db.collectionItems).get(), items);
    });

    test('a refused file writes nothing', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
      }, testName: 'refused custom-field file writes nothing');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final liveReg = [text.column, real.column];
      await db.saveCustomFields('c1', {text.column.name: text.value}, registry: liveReg);
      final before = await snapshot(liveReg);
      final p = parseCustomFieldsFile(
        _file([_row('c1', {text.sqlName: sampleCustomValue(CustomColumnType.text, variant: 1)}), _row('x', {real.sqlName: 'bad'})]),
        liveReg,
      );
      expect(p.rows, isNull);
      expect(p.refusal, contains('row 2 field ${real.column.name}'));
      // The screen only calls importCustomFieldRows when rows is non-null.
      expect(await snapshot(liveReg), before);
    });

    test('REQ-048 importCustomFieldsText: refusals write nothing, valid writes', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
      }, testName: 'importCustomFieldsText writes only valid rows');
      if (fields == null) return;
      final textField = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final liveReg = [textField.column, real.column];
      await db.saveCustomFields('c1', {textField.column.name: textField.value}, registry: liveReg);
      final before = await snapshot(liveReg);
      final refused = <(String, String)>[
        ('{nope', 'Custom field import refused: the file is not valid JSON'),
        (_file([], version: 2), 'Custom field import refused: unknown format version 2'),
        (
          _file([_row('c1', {textField.sqlName: sampleCustomValue(CustomColumnType.text, variant: 1)}), _row('x', {real.sqlName: 'bad'})]),
          'Custom field import refused: row 2 field ${real.column.name} does not fit its real type',
        ),
      ];
      for (final (text, msg) in refused) {
        expect(await importCustomFieldsText(db, text, liveReg), msg);
        expect(await snapshot(liveReg), before);
      }
      final changedText = sampleCustomValue(CustomColumnType.text, variant: 1);
      final changedReal = sampleCustomValue(CustomColumnType.real, variant: 1);
      final ok = _file([_row('c1', {textField.sqlName: changedText}), _row('x', {real.sqlName: changedReal})]);
      expect(await importCustomFieldsText(db, ok, liveReg), 'Imported 2 custom field row(s)');
      final rows = await db.overrideRows(registry: liveReg);
      expect(rows.map((r) => r.importedId), ['c1', 'x']);
      expect(rows[0].values[textField.column.name], changedText);
      expect(rows[1].values[real.column.name], changedReal);
    });

    test('REQ-048 round trip through two real stores gives the same file', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
        CustomColumnType.date,
      }, testName: 'custom fields round trip through two stores');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final date = fields[CustomColumnType.date]!;
      final liveReg = [text.column, real.column, date.column];
      await db.saveCustomFields('c1', {
        text.column.name: text.value,
        real.column.name: null,
        date.column.name: date.value,
      }, registry: liveReg);
      await db.saveCustomFields('gone', {
        text.column.name: sampleCustomValue(CustomColumnType.text, variant: 1),
        real.column.name: sampleCustomValue(CustomColumnType.real, variant: 1),
      }, registry: liveReg);
      final first = buildCustomFieldsFile(await db.overrideRows(registry: liveReg), liveReg);
      final dir2 = Directory.systemTemp.createTempSync('holovault_cff2_');
      final db2 = AppDatabase.withExecutor(NativeDatabase(File('${dir2.path}/t.sqlite')));
      try {
        expect(await importCustomFieldsText(db2, first, liveReg), 'Imported 2 custom field row(s)');
        expect(buildCustomFieldsFile(await db2.overrideRows(registry: liveReg), liveReg), first);
      } finally {
        await db2.close();
        dir2.deleteSync(recursive: true);
      }
    });

    test('importCustomFieldRows is one transaction: a failing row rolls back all', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
      }, testName: 'custom-field row import transaction rollback');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final liveReg = [text.column];
      await db.saveCustomFields('c1', {text.column.name: text.value}, registry: liveReg);
      final before = await snapshot(liveReg);
      // The second row holds a value SQLite cannot bind, so its write throws
      // after the first row's write succeeded.
      await expectLater(
        db.importCustomFieldRows([
          (importedId: 'c1', values: {text.column.name: sampleCustomValue(CustomColumnType.text, variant: 1)}),
          (importedId: 'c2', values: {text.column.name: Object()}),
        ], registry: liveReg),
        throwsA(anything),
      );
      expect(await snapshot(liveReg), before);
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
