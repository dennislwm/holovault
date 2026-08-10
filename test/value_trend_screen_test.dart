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
        '150.0',
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
        '120.0',
      );

      await tester.tap(find.text('+ Add filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base Set').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.0',
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

      await tester.tap(find.text('+ Add filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Base Set').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save this filter'));
      await tester.pumpAndSettle();

      await disposeAndFlush(tester);

      // Fresh screen instance -- same underlying SharedPreferences store.
      await tester.pumpWidget(
        MaterialApp(home: ValueTrendScreen(database: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set: Base Set'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );
}
