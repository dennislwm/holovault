import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/screens/value_trend_screen.dart';
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
    'REQ-015: shows the cumulative value trend chart and total',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          setName: const Value('Base Set'),
          rarity: const Value('Holo'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Blastoise',
          setName: const Value('Base Set'),
          rarity: const Value('Holo'),
          valueTotal: const Value(50.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '150.00',
      );
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Matching items · 2'), findsOneWidget);
      expect(find.text('Charizard'), findsOneWidget);
      expect(find.text('Blastoise'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-015/REQ-034: filtering by a Set name clause narrows the chart total to matching items',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          setName: const Value('Base Set'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Pikachu',
          setName: const Value('Jungle'),
          valueTotal: const Value(20.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '120.00',
      );

      await addClause(tester, field: 'Set name', op: '=', value: 'Base Set');

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-015/REQ-034: saved clause persists across a fresh screen instance',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          setName: const Value('Base Set'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      await addClause(tester, field: 'Set name', op: '=', value: 'Base Set');

      await disposeAndFlush(tester);

      // Fresh screen instance -- same underlying SharedPreferences store.
      // Clause auto-persists on add (no explicit save step).
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );
      expect(find.text('Set name = Base Set'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-034: filtering by a Grade type clause narrows the chart total to matching items',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          gradeType: const Value('PSA'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Pikachu',
          gradeType: const Value('Raw'),
          valueTotal: const Value(20.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '120.00',
      );

      await addClause(tester, field: 'Grade type', op: '=', value: 'PSA');

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-034: a persisted clause referencing a value absent from current items yields zero matches, not a crash',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'value_trend_filter_clauses': jsonEncode([
          {'field': 'setName', 'op': 'equal', 'value': 'Discontinued Set'},
        ]),
      });
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          setName: const Value('Base Set'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Matching items · 0'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'shows the cumulative paid total alongside the value total, as a second chart line',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          valueTotal: const Value(100.0),
          paidTotal: const Value(60.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Blastoise',
          valueTotal: const Value(50.0),
          paidTotal: const Value(40.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '150.00',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('value-trend-paid-total')))
            .data,
        'Paid: 100.00',
      );
      expect(
        tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
        hasLength(2),
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'the matching items list shows each item\'s paid total alongside its value total',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          valueTotal: const Value(100.0),
          paidTotal: const Value(60.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Blastoise',
          valueTotal: const Value(50.0),
          paidTotal: const Value(40.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      // Per-item row values (60.00, 40.00), distinct from the header's
      // cumulative "Paid: 100.00" (60 + 40).
      expect(find.text('Paid: 60.00'), findsOneWidget);
      expect(find.text('Paid: 40.00'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-022/REQ-034: a Rarity != Sealed clause drops sealed items, independent of a Grade type clause',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard VMAX',
          rarity: const Value('Holo Rare'),
          gradeType: const Value('PSA'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Base Set Booster Box',
          rarity: const Value('Sealed'),
          gradeType: const Value('PSA'),
          valueTotal: const Value(500.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      // Both items match Grade type = PSA before the exclude-sealed clause
      // is added.
      await addClause(tester, field: 'Grade type', op: '=', value: 'PSA');
      expect(find.text('Matching items · 2'), findsOneWidget);

      await addClause(tester, field: 'Rarity', op: '!=', value: 'Sealed');

      expect(find.text('Matching items · 1'), findsOneWidget);
      expect(find.text('Charizard VMAX'), findsOneWidget);
      expect(find.text('Base Set Booster Box'), findsNothing);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-021: a dated item with no valueTotal/paidTotal appears on the x-axis '
        'and contributes 0 to both running totals',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          valueTotal: const Value(100.0),
          paidTotal: const Value(80.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Undated-value Pikachu',
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-3',
          name: 'Blastoise',
          valueTotal: const Value(50.0),
          paidTotal: const Value(40.0),
          dateAdded: Value(DateTime(2026, 3, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      // All three appear -- the middle item's missing valueTotal/paidTotal
      // does not exclude it from the x-axis now that withDates only
      // requires dateAdded (REQ-020 widened the filter).
      expect(find.text('Matching items · 3'), findsOneWidget);
      expect(find.text('Undated-value Pikachu'), findsOneWidget);

      // Running totals: the middle item contributes 0 to each, so the
      // final total is just the two dated-and-valued items summed.
      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '150.00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-paid-total'))).data,
        'Paid: 120.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-023/REQ-034: Rarity = Sealed + Rarity != Sealed clauses together yield zero matching items',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Base Set Booster Box',
          rarity: const Value('Sealed'),
          valueTotal: const Value(500.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      await addClause(tester, field: 'Rarity', op: '=', value: 'Sealed');
      expect(find.text('Matching items · 1'), findsOneWidget);

      await addClause(tester, field: 'Rarity', op: '!=', value: 'Sealed');

      expect(find.text('Matching items · 0'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-034: adding a clause with a long set name value does not throw',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          setName: const Value(
            'A Very Long Expansion Set Name That Would Never Fit On One Line',
          ),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      await addClause(
        tester,
        field: 'Set name',
        op: '=',
        value: 'A Very Long Expansion Set Name That Would Never Fit On One Line',
      );

      expect(tester.takeException(), isNull);

      await disposeAndFlush(tester);
    },
  );


  testWidgets(
    'REQ-042 (a): tapping a row opens the detail screen on that item',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
            importedId: 'card-1', name: 'Charizard'),
      );
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('value-trend-row-0')));
      await tester.pumpAndSettle();

      expect(find.text('Item detail'), findsOneWidget);
      expect(find.text('Charizard'), findsNWidgets(2));

      await disposeAndFlush(tester);
    },
  );
}
