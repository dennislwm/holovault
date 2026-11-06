import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/custom_field_logic.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/screens/item_detail_screen.dart';

CustomColumn _col(String name) =>
    customColumns.firstWhere((c) => c.name == name);

void main() {
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
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'c1', name: 'Charizard'),
      );
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('upsert writes only overrides, is idempotent, empty stores null', () async {
      final before = await db.select(db.collectionItems).get();
      final vals = {'serialNo': 'X1', 'addCost': 12.5, 'preGrade': null};
      await db.saveCustomFields('c1', vals);
      await db.saveCustomFields('c1', vals);

      final o = await db.select(db.collectionItemOverrides).get();
      expect(o, hasLength(1));
      expect(o.single.serialNo, 'X1');
      expect(o.single.addCost, 12.5);
      expect(o.single.preGrade, isNull);
      expect(await db.select(db.collectionItems).get(), before);

      final merged = await db.mergedItemByImportedId('c1');
      expect(merged!.serialNo, 'X1');

      await db.saveCustomFields('c1', {'serialNo': null});
      final cleared = await db.mergedItemByImportedId('c1');
      expect(cleared!.serialNo, isNull);
      expect(cleared.addCost, 12.5);
    });

    test('REQ-043 c: merged stream carries custom values, null without overrides, omits hidden rows', () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'c2', name: 'Blastoise'),
      );
      await db.saveCustomFields('c1', {'serialNo': 'X1'});
      await db.saveCustomFields('gone', {'serialNo': 'H1'});

      final items = await db.watchMergedItems().first;
      final byId = {for (final i in items) i.importedId: i};

      expect(byId.keys.toSet(), {'c1', 'c2'});
      expect(byId['c1']!.serialNo, 'X1');
      expect(byId['c2']!.serialNo, isNull);
    });

    test('suggestions include a value held only by a hidden row', () async {
      await db.saveCustomFields('c1', {'preGrade': 'Near Mint'});
      await db.saveCustomFields('gone', {'preGrade': 'Played'});
      final s = suggestionList(await db.storedValues(_col('preGrade')));
      expect(s, ['Near Mint', 'Played']);
    });

    testWidgets('invalid input saves nothing; valid input saves the override', (
      tester,
    ) async {
      final item = (await tester.runAsync(() => db.select(db.mergedItems).get()))!
          .single;
      await tester.runAsync(
        () => db.saveCustomFields('c1', {'addCost': 1.0}),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ItemDetailScreen(
            database: db,
            items: [item],
            initialIndex: 0,
            registry: [_col('serialNo'), _col('addCost')],
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      // Name, Extra, serialNo, addCost.
      final cost = find.byType(TextField).at(3);
      expect(find.byType(TextField), findsNWidgets(4));
      await tester.enterText(cost, 'abc');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a number'), findsOneWidget);
      var row = await tester.runAsync(() => db.mergedItemByImportedId('c1'));
      expect(row!.addCost, 1.0);

      await tester.enterText(cost, '2.5');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      row = await tester.runAsync(() => db.mergedItemByImportedId('c1'));
      expect(row!.addCost, 2.5);
      expect(row.serialNo, isNull);
    });
  });
}
