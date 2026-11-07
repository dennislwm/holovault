import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart' show customIdPrefix;
import 'package:holovault/screens/value_trend_screen.dart';
import 'package:holovault/set_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  final fx = WidgetFixture();

  // REQ-053: wiring only; the lookup itself is tested in set_lookup_test.dart.
  testWidgets('REQ-053: an imported set lookup shows in the language column without a restart',
      (WidgetTester tester) async {
    addTearDown(() => setLookup = {});
    SharedPreferences.setMockInitialValues({
      'value_trend_filter_columns': jsonEncode(['name', '${customIdPrefix}language']),
    });
    await seedItem(
      fx.db,
      importedId: 'card-1',
      name: 'Card',
      setName: 'Base Set',
      valueTotal: 100.0,
      dateAdded: DateTime(2026, 1, 1),
    );
    await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));
    expect(find.text('ja'), findsNothing);

    await fx.db.replaceSetLookup([
      (aliasName: 'Base Set', language: 'ja', tcgdexId: null, officialName: null),
    ]);
    await refreshSetLookup(fx.db);
    await tester.pumpAndSettle();

    expect(find.text('ja'), findsWidgets); // the column cell and, REQ-054, the chip

    await disposeAndFlush(tester);
  });

  testWidgets(
    'REQ-015/REQ-034: filtering by a Set name clause narrows the chart total to matching items',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        setName: 'Base Set',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Pikachu',
        setName: 'Jungle',
        valueTotal: 20.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        setName: 'Base Set',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      await addClause(tester, field: 'Set name', op: '=', value: 'Base Set');

      await disposeAndFlush(tester);

      // Fresh screen instance -- same underlying SharedPreferences store.
      // Clause auto-persists on add (no explicit save step).
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      expect(
        tester.widget<Text>(find.byKey(const Key('value-trend-total'))).data,
        '100.00',
      );
      expect(find.text('Set name = Base Set'), findsOneWidget);

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        setName: 'Base Set',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      expect(tester.takeException(), isNull);
      expect(find.text('0 matching items'), findsOneWidget);
      // REQ-042 (e)/(f): the headline is labelled, and an empty list says why.
      expect(find.text('Chart total'), findsOneWidget);
      expect(find.text('No items match the current filter'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'shows the cumulative paid total alongside the value total, as a second chart line',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        valueTotal: 100.0,
        paidTotal: 60.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Blastoise',
        valueTotal: 50.0,
        paidTotal: 40.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

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
      // REQ-042 (b): the strip is taller; keep every row inside the viewport.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        valueTotal: 100.0,
        paidTotal: 60.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Blastoise',
        valueTotal: 50.0,
        paidTotal: 40.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard VMAX',
        rarity: 'Holo Rare',
        gradeType: 'PSA',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Base Set Booster Box',
        rarity: 'Sealed',
        gradeType: 'PSA',
        valueTotal: 500.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      // Both items match Grade type = PSA before the exclude-sealed clause
      // is added.
      await addClause(tester, field: 'Grade type', op: '=', value: 'PSA');
      expect(find.text('2 matching items'), findsOneWidget);

      await addClause(tester, field: 'Rarity', op: '!=', value: 'Sealed');

      expect(find.text('1 matching items'), findsOneWidget);
      expect(find.text('Charizard VMAX'), findsOneWidget);
      expect(find.text('Base Set Booster Box'), findsNothing);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-021: a dated item with no valueTotal/paidTotal appears on the x-axis '
        'and contributes 0 to both running totals',
    (WidgetTester tester) async {
      // REQ-042 (b): the strip is taller; keep every row inside the viewport.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        valueTotal: 100.0,
        paidTotal: 80.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Undated-value Pikachu',
        dateAdded: DateTime(2026, 2, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-3',
        name: 'Blastoise',
        valueTotal: 50.0,
        paidTotal: 40.0,
        dateAdded: DateTime(2026, 3, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      // All three appear -- the middle item's missing valueTotal/paidTotal
      // does not exclude it from the x-axis now that withDates only
      // requires dateAdded (REQ-020 widened the filter).
      expect(find.text('3 matching items'), findsOneWidget);
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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Base Set Booster Box',
        rarity: 'Sealed',
        valueTotal: 500.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      await addClause(tester, field: 'Rarity', op: '=', value: 'Sealed');
      expect(find.text('1 matching items'), findsOneWidget);

      await addClause(tester, field: 'Rarity', op: '!=', value: 'Sealed');

      expect(find.text('0 matching items'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-034: adding a clause with a long set name value does not throw',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        setName: 'A Very Long Expansion Set Name That Would Never Fit On One Line',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

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
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      await fx.pumpScreen(tester, ValueTrendScreen(database: fx.db));

      await tester.tap(find.byKey(const Key('value-trend-row-0')));
      await tester.pumpAndSettle();

      expect(find.text('Item detail'), findsOneWidget);
      expect(find.text('Charizard'), findsNWidgets(2));

      await disposeAndFlush(tester);
    },
  );
}
