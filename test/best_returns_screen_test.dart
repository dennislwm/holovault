import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/screens/best_returns_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// REQ-034 (ADR-19): drives the shared clause-builder bottom sheet
/// (`SearchFilterBar`'s `showAddClauseSheet`), same sequence as
/// `widget_test.dart`'s "adding a clause via the bottom sheet" test --
/// field, then operator, then value, then Add.
Future<void> addClause(
  WidgetTester tester, {
  required String field,
  required String op,
  required String value,
}) async {
  await tester.tap(find.text('Add clause'));
  await tester.pumpAndSettle();
  // .last on each label -- the bottom sheet renders on top of (after) any
  // same-named Text already in the screen behind it (e.g. BestReturnsScreen's
  // "Value" DataColumn header), so the sheet's own label is always the last
  // match in tree order.
  await tester.tap(find.text('Field').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(field).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Operator').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(op).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Value').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add').last);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'REQ-028: ranks items by annualized return, shows the bar+percent, paid, value, days inline',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Slow grower',
          paidPerUnit: const Value(100.0),
          valuePerUnit: const Value(150.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Fast grower',
          paidPerUnit: const Value(100.0),
          valuePerUnit: const Value(300.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 2'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Fast grower'), findsOneWidget);
      expect(find.text('Slow grower'), findsOneWidget);
      expect(find.textContaining('100.00'), findsWidgets);
      expect(find.text('200'), findsWidgets);
      expect(find.byKey(const Key('best-returns-bar')), findsNWidgets(2));

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-028/REQ-034: filtering by a Set name clause narrows the ranked list',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'In Base Set',
          setName: const Value('Base Set'),
          paidPerUnit: const Value(10.0),
          valuePerUnit: const Value(20.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'In Jungle',
          setName: const Value('Jungle'),
          paidPerUnit: const Value(10.0),
          valuePerUnit: const Value(40.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 2'), findsOneWidget);

      await addClause(tester, field: 'Set name', op: '=', value: 'Base Set');

      expect(find.text('Ranked · 1'), findsOneWidget);
      expect(find.text('In Base Set'), findsOneWidget);
      expect(find.text('In Jungle'), findsNothing);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-028: min paid param excludes items at or below the threshold, persists on submit',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Cheap',
          paidPerUnit: const Value(1.0),
          valuePerUnit: const Value(2.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Pricier',
          paidPerUnit: const Value(50.0),
          valuePerUnit: const Value(80.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 2'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('best-returns-min-paid')), '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 1'), findsOneWidget);
      expect(find.text('Pricier'), findsOneWidget);
      expect(find.text('Cheap'), findsNothing);

      await disposeAndFlush(tester);

      // Fresh screen instance -- min paid should still be 10.
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 1'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-028: limit stepper truncates the ranked list',
    (WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await db.upsertItem(
          CollectionItemsCompanion.insert(
            importedId: 'card-$i',
            name: 'Item $i',
            paidPerUnit: Value(10.0 + i),
            valuePerUnit: Value(30.0 + i),
            dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ranked · 3'), findsOneWidget);

      // Default limit is 5; tap minus down to 1 (5 -> 4 -> 3 -> 2 -> 1).
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('best-returns-limit-minus')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Ranked · 1'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-028: tapping the Item column header sorts alphabetically instead of by return',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Zorua',
          paidPerUnit: const Value(10.0),
          valuePerUnit: const Value(50.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Abra',
          paidPerUnit: const Value(10.0),
          valuePerUnit: const Value(20.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      // Default sort is by Return descending -- Zorua (higher %) first.
      final beforeRows = tester.widget<DataTable>(find.byType(DataTable)).rows;
      expect(beforeRows.first.cells.first.child, isA<Text>());

      await tester.tap(find.text('Item'));
      await tester.pumpAndSettle();

      final afterRows = tester.widget<DataTable>(find.byType(DataTable)).rows;
      final firstCellText = (afterRows.first.cells.first.child as Text).data;
      expect(firstCellText, 'Abra');

      await disposeAndFlush(tester);
    },
  );
}
