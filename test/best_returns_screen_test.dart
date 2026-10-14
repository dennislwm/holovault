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
      expect(find.text('Fast grower'), findsOneWidget);
      expect(find.text('Slow grower'), findsOneWidget);
      expect(find.textContaining('100.00'), findsWidgets);
      expect(find.textContaining('200'), findsWidgets);
      expect(find.text('Top N by return'), findsOneWidget);
      expect(find.byKey(const Key('return-bar')), findsNWidgets(2));

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
      // REQ-042 (b): the strip is taller; keep every row inside the viewport.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
      expect(
        tester.getTopLeft(find.text('Zorua')).dy,
        lessThan(tester.getTopLeft(find.text('Abra')).dy),
      );

      // REQ-042 (b): the strip's sort picker replaces the header sort.
      await tester.tap(find.byKey(const Key('sort-key-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name').last);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Abra')).dy,
        lessThan(tester.getTopLeft(find.text('Zorua')).dy),
      );

      await disposeAndFlush(tester);
    },
  );


  testWidgets(
    'REQ-042 (a): tapping a ranked row opens the detail screen on that item',
    (WidgetTester tester) async {
      for (final (id, name, value) in [
        ('card-1', 'Slow grower', 150.0),
        ('card-2', 'Fast grower', 300.0),
      ]) {
        await db.upsertItem(
          CollectionItemsCompanion.insert(
            importedId: id,
            name: name,
            paidPerUnit: const Value(100.0),
            valuePerUnit: Value(value),
            dateAdded:
                Value(DateTime.now().subtract(const Duration(days: 200))),
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();

      // Default sort is Return descending, so the slow grower is row 1: the
      // tapped index must map into the displayed list, not storage order.
      await tester.tap(find.text('Slow grower'));
      await tester.pumpAndSettle();

      expect(find.text('Item detail'), findsOneWidget);
      expect(find.text('Slow grower'), findsNWidgets(2));

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-042 (d): the columns dialog changes the ranked rows on Best Returns',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Grower',
          paidPerUnit: const Value(100.0),
          valuePerUnit: const Value(150.0),
          dateAdded: Value(DateTime.now().subtract(const Duration(days: 200))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: BestReturnsScreen(database: db)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Days held'), findsOneWidget);

      await tester.tap(find.byKey(const Key('columns-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Days held'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Days held'), findsNothing);
      expect(find.text('Grower'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );
}
