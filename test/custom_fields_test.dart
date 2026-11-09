import 'dart:io';

import 'package:drift/drift.dart' show DriftSqlType, GeneratedColumn, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/custom_field_logic.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/screens/custom_fields_section.dart';
import 'package:holovault/screens/item_detail_screen.dart';

import 'helpers.dart';

final _allTypes = testCustomColumns;
Future<Object?> _storedValue(
  AppDatabase db,
  String importedId,
  String name, {
  List<CustomColumn>? registry,
}) async =>
    (await db.overrideRows(registry: registry ?? testCustomColumns))
        .firstWhere((r) => r.importedId == importedId)
        .values[name];

void main() {
  group('REQ-045: collectCustomValues', () {
    test('a column whose form key is absent is left out of the save map', () {
      final out = collectCustomValues(_allTypes, {'cf.testText': 'x'});
      expect(out, {'testText': 'x'});
      expect(collectCustomValues(_allTypes, {}), isEmpty);
    });

    test('every type: empties null, int parsed, bool and date pass through', () {
      final when = DateTime(2026, 11, 6);
      final out = collectCustomValues(_allTypes, {
        'cf.testText': '',
        'cf.testChoice': '',
        'cf.testReal': '1.5',
        'cf.testInteger': '7',
        'cf.testBool': false,
        'cf.testDate': when,
      });
      expect(out, {
        'testText': null,
        'testChoice': null,
        'testReal': 1.5,
        'testInteger': 7,
        'testBool': false,
        'testDate': when,
      });
      final kept = collectCustomValues(_allTypes, {
        'cf.testText': 'a',
        'cf.testChoice': 'b',
        'cf.testReal': '',
        'cf.testInteger': '',
        'cf.testBool': null,
        'cf.testDate': null,
      });
      expect(kept, {
        'testText': 'a',
        'testChoice': 'b',
        'testReal': null,
        'testInteger': null,
        'testBool': null,
        'testDate': null,
      });
    });
  });

  group('REQ-043 b: pure logic', () {
    test('validateNumber: dot-decimal or whole only, empty ok', () {
      expect(validateNumber('', whole: false), isNull);
      expect(validateNumber(null, whole: true), isNull);
      expect(validateNumber('12.5', whole: false), isNull);
      expect(validateNumber('-3', whole: false), isNull);
      expect(validateNumber('12,5', whole: false), isNotNull);
      expect(validateNumber('abc', whole: false), isNotNull);
      expect(validateNumber('7', whole: true), isNull);
      expect(validateNumber('7.5', whole: true), isNotNull);
      expect(parseNumber('', whole: true), isNull);
      expect(parseNumber('7', whole: true), 7);
      expect(parseNumber('1.5', whole: false), 1.5);
    });

    test('suggestionList: distinct, non-empty, sorted, case-sensitive', () {
      expect(suggestionList(['b', null, '', 'a', 'b', 'A']), ['A', 'a', 'b']);
    });
  });

  group('REQ-043 b: real store', () {
    late Directory dir;
    late AppDatabase db;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('holovault_cf_');
      db = AppDatabase.withExecutor(NativeDatabase(File('${dir.path}/t.sqlite')));
      await seedItem(db, importedId: 'c1', name: 'Charizard');
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('upsert writes only overrides, is idempotent, empty stores null', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
        CustomColumnType.choice,
      }, testName: 'custom field upsert and clear');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final choice = fields[CustomColumnType.choice]!;
      final liveReg = [text.column, real.column, choice.column];
      final before = await db.select(db.collectionItems).get();
      final vals = {text.column.name: text.value, real.column.name: real.value, choice.column.name: null};
      await db.saveCustomFields('c1', vals, registry: liveReg);
      await db.saveCustomFields('c1', vals, registry: liveReg);

      final o = await db.overrideRows(registry: liveReg);
      expect(o, hasLength(1));
      expect(o.single.values[text.column.name], text.value);
      expect(o.single.values[real.column.name], real.value);
      expect(o.single.values[choice.column.name], isNull);
      expect(await db.select(db.collectionItems).get(), before);

      final merged = await db.mergedItemByImportedId('c1');
      expect(merged, isNotNull);
      expect(await _storedValue(db, 'c1', text.column.name, registry: liveReg), text.value);

      await db.saveCustomFields('c1', {text.column.name: null}, registry: liveReg);
      final cleared = await db.mergedItemByImportedId('c1');
      expect(cleared, isNotNull);
      expect(await _storedValue(db, 'c1', text.column.name, registry: liveReg), isNull);
      expect(await _storedValue(db, 'c1', real.column.name, registry: liveReg), real.value);
    });

    test('REQ-045: a column absent from the save map keeps its stored value', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.choice,
        CustomColumnType.text,
        CustomColumnType.date,
      }, testName: 'absent custom-field save key preserves value');
      if (fields == null) return;
      final choice = fields[CustomColumnType.choice]!;
      final text = fields[CustomColumnType.text]!;
      final date = fields[CustomColumnType.date]!;
      final liveReg = [choice.column, text.column, date.column];
      await db.saveCustomFields('c1', {
        choice.column.name: choice.value,
        text.column.name: text.value,
        date.column.name: date.value,
      }, registry: liveReg);
      final changedText = sampleCustomValue(CustomColumnType.text, variant: 1);
      await db.saveCustomFields('c1', {text.column.name: changedText}, registry: liveReg);
      final m = (await db.mergedItemByImportedId('c1'))!;
      expect(m, isNotNull);
      expect(await _storedValue(db, 'c1', text.column.name, registry: liveReg), changedText);
      expect(await _storedValue(db, 'c1', choice.column.name, registry: liveReg), choice.value);
      expect(await _storedValue(db, 'c1', date.column.name, registry: liveReg), date.value);
    });

    test('REQ-045 (iii): one transaction; a failing custom write rolls the item back', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
      }, testName: 'item and custom-field transaction rollback');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final liveReg = [text.column];
      final ok = {text.column.name: text.value};
      final item = CollectionItemsCompanion.insert(
        importedId: 'c1',
        name: 'Renamed',
        extra: const Value('e1'),
      );
      await db.saveItemAndCustomFields(item, 'c1', ok, registry: liveReg);
      var row = (await db.mergedItemByImportedId('c1'))!;
      expect([row.name, row.extra, await _storedValue(db, 'c1', text.column.name, registry: liveReg)], ['Renamed', 'e1', text.value]);

      // A column that does not exist in the overrides table: a real SQL error.
      final bad = (
        id: null,
        name: 'nope',
        type: CustomColumnType.text,
        value: (r) => null,
        column: (t) => GeneratedColumn<String>(
          'no_such_col',
          't',
          true,
          type: DriftSqlType.string,
        ),
      );
      await expectLater(
        db.saveItemAndCustomFields(
          CollectionItemsCompanion.insert(
            importedId: 'c1',
            name: 'Lost',
            extra: const Value('e2'),
          ),
          'c1',
          {text.column.name: sampleCustomValue(CustomColumnType.text, variant: 1), 'nope': 'v'},
          registry: [text.column, bad],
        ),
        throwsA(anything),
      );
      row = (await db.mergedItemByImportedId('c1'))!;
      expect([row.name, row.extra, await _storedValue(db, 'c1', text.column.name, registry: liveReg)], ['Renamed', 'e1', text.value]);
    });

    test('REQ-044: date and choice fields round-trip through the merged view', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.date,
        CustomColumnType.choice,
      }, testName: 'date and choice round trip');
      if (fields == null) return;
      final date = fields[CustomColumnType.date]!;
      final choice = fields[CustomColumnType.choice]!;
      final liveReg = [date.column, choice.column];
      expect(date.column.type, CustomColumnType.date);
      expect(choice.column.type, CustomColumnType.choice);
      expect(date.column.column(db.collectionItemOverrides).type, DriftSqlType.dateTime);

      final before = await db.select(db.collectionItems).get();
      final when = date.value as DateTime; // local, whole seconds
      final vals = {date.column.name: when, choice.column.name: choice.value};
      await db.saveCustomFields('c1', vals, registry: liveReg);
      await db.saveCustomFields('c1', vals, registry: liveReg);

      expect(await db.select(db.collectionItemOverrides).get(), hasLength(1));
      final merged = (await db.mergedItemByImportedId('c1'))!;
      final read = await _storedValue(db, 'c1', date.column.name, registry: liveReg);
      expect(read, isA<DateTime>());
      expect(read, when);
      expect((read as DateTime).isUtc, isFalse);
      expect(choice.column.value(merged), choice.value);
      final mergedRaw = await db.customSelect(
        "SELECT ${date.sqlName}, ${choice.sqlName} FROM merged_items WHERE imported_id = 'c1'",
      ).getSingle();
      expect(mergedRaw.data[date.sqlName], isNotNull);
      expect(mergedRaw.data[choice.sqlName], choice.value);
      expect(await db.select(db.collectionItems).get(), before);

      await db.saveCustomFields('c1', {date.column.name: null}, registry: liveReg);
      final cleared = (await db.mergedItemByImportedId('c1'))!;
      expect(await _storedValue(db, 'c1', date.column.name, registry: liveReg), isNull);
      expect(await _storedValue(db, 'c1', choice.column.name, registry: liveReg), choice.value);
      expect(choice.column.value(cleared), choice.value);
      expect(await db.select(db.collectionItems).get(), before);
    });

    test('REQ-043 c: merged stream carries custom values, null without overrides, omits hidden rows', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
      }, testName: 'merged stream carries custom values');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final liveReg = [text.column];
      await seedItem(db, importedId: 'c2', name: 'Blastoise');
      await db.saveCustomFields('c1', {text.column.name: text.value}, registry: liveReg);
      await db.saveCustomFields('gone', {text.column.name: sampleCustomValue(CustomColumnType.text, variant: 1)}, registry: liveReg);

      final items = await db.watchMergedItems().first;
      final byId = {for (final i in items) i.importedId: i};

      expect(byId.keys.toSet(), {'c1', 'c2'});
      expect(text.column.value(byId['c1']!), text.value);
      expect(text.column.value(byId['c2']!), isNull);
      expect(byId['c2']!.toJson().values, isNot(contains(text.value)));
      expect(await _storedValue(db, 'c1', text.column.name, registry: liveReg), text.value);
      final c2 = await db.customSelect(
        "SELECT * FROM merged_items WHERE imported_id = 'c2'",
      ).getSingle();
      expect(c2.data.containsKey(text.sqlName), isTrue);
      expect(c2.data[text.sqlName], isNull);
    });

    test('suggestions include a value held only by a hidden row', () async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.choice,
      }, testName: 'suggestions include a hidden-row value');
      if (fields == null) return;
      final choice = fields[CustomColumnType.choice]!;
      final secondChoice = sampleCustomValue(CustomColumnType.choice, variant: 1) as String;
      await db.saveCustomFields('c1', {choice.column.name: choice.value}, registry: [choice.column]);
      await db.saveCustomFields('gone', {choice.column.name: secondChoice}, registry: [choice.column]);
      final s = suggestionList(await db.storedValues(choice.column));
      expect(s, [secondChoice, choice.value]);
    });

    testWidgets('REQ-045: the date clear control empties the field and saves null', (
      tester,
    ) async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.date,
        CustomColumnType.choice,
      }, testName: 'date clear control saves null');
      if (fields == null) return;
      final date = fields[CustomColumnType.date]!;
      final choice = fields[CustomColumnType.choice]!;
      final liveReg = [date.column, choice.column];
      await tester.runAsync(
        () => db.saveCustomFields('c1', {
          date.column.name: date.value,
          choice.column.name: choice.value,
        }, registry: liveReg),
      );
      final item = (await tester.runAsync(() => db.select(db.mergedItems).get()))!.single;
      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(
            database: db,
            items: [item],
            initialIndex: 0,
            registry: [date.column],
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      await tester.ensureVisible(find.byIcon(Icons.clear));
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      final row = await tester.runAsync(() => db.mergedItemByImportedId('c1'));
      expect(row, isNotNull);
      expect(await _storedValue(db, 'c1', date.column.name, registry: liveReg), isNull);
      expect(await _storedValue(db, 'c1', choice.column.name, registry: liveReg), choice.value);
    });

    testWidgets('invalid input saves nothing; valid input saves the override', (
      tester,
    ) async {
      final fields = liveFieldsOrSkip(db, {
        CustomColumnType.text,
        CustomColumnType.real,
      }, testName: 'invalid numeric input saves nothing');
      if (fields == null) return;
      final text = fields[CustomColumnType.text]!;
      final real = fields[CustomColumnType.real]!;
      final liveReg = [text.column, real.column];
      await tester.runAsync(
        () => db.saveCustomFields('c1', {real.column.name: real.value}, registry: liveReg),
      );
      final item = (await tester.runAsync(() => db.select(db.mergedItems).get()))!.single;
      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(
            database: db,
            items: [item],
            initialIndex: 0,
            registry: liveReg,
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      // Name, Extra, the selected text field, the selected real field.
      final cost = find.byType(TextField).at(3);
      expect(find.byType(TextField), findsNWidgets(4));
      await tester.enterText(cost, 'abc');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a number'), findsOneWidget);
      expect(find.text('Fix the highlighted fields'), findsOneWidget);
      var row = await tester.runAsync(() => db.mergedItemByImportedId('c1'));
      expect(row, isNotNull);
      expect(await _storedValue(db, 'c1', real.column.name, registry: liveReg), real.value);

      final changedReal = sampleCustomValue(CustomColumnType.real, variant: 1) as double;
      await tester.enterText(cost, '$changedReal');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Fix the highlighted fields'), findsNothing);
      final savedRow = await tester.runAsync(() => db.mergedItemByImportedId('c1'));
      expect(savedRow, isNotNull);
      expect(await _storedValue(db, 'c1', real.column.name, registry: liveReg), changedReal);
      expect(await _storedValue(db, 'c1', text.column.name, registry: liveReg), isNull);
    });
  });
}
