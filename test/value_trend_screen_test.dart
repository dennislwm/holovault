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
    'REQ-015: filtering by set narrows the chart total to matching items',
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

      await tester.tap(find.text('Set: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base Set').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-015: saved filter persists across a fresh screen instance',
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

      await tester.tap(find.text('Set: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base Set').last);
      await tester.pumpAndSettle();

      await disposeAndFlush(tester);

      // Fresh screen instance -- same underlying SharedPreferences store.
      // Dropdown selection auto-persists on change (no explicit save step).
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'filtering by grade type narrows the chart total to matching items',
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

      await tester.tap(find.text('Grade type: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PSA').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'a persisted filter value absent from current items falls back to All instead of crashing',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'value_trend_filter_set': 'Discontinued Set',
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
      expect(find.text('Set: All'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );

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
}
