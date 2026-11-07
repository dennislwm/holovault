import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/screens/best_returns_screen.dart';

import 'helpers.dart';

void main() {
  final fx = WidgetFixture();

  testWidgets(
    'REQ-028: ranks items by annualized return, shows the bar+percent, paid, value, days inline',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Slow grower',
        paidPerUnit: 100.0,
        valuePerUnit: 150.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Fast grower',
        paidPerUnit: 100.0,
        valuePerUnit: 300.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'In Base Set',
        setName: 'Base Set',
        paidPerUnit: 10.0,
        valuePerUnit: 20.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'In Jungle',
        setName: 'Jungle',
        paidPerUnit: 10.0,
        valuePerUnit: 40.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));

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
        await seedItem(
          fx.db,
          importedId: 'card-$i',
          name: 'Item $i',
          paidPerUnit: 10.0 + i,
          valuePerUnit: 30.0 + i,
          dateAdded: DateTime.now().subtract(const Duration(days: 200)),
        );
      }
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Zorua',
        paidPerUnit: 10.0,
        valuePerUnit: 50.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Abra',
        paidPerUnit: 10.0,
        valuePerUnit: 20.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));

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
        await seedItem(
          fx.db,
          importedId: id,
          name: name,
          paidPerUnit: 100.0,
          valuePerUnit: value,
          dateAdded: DateTime.now().subtract(const Duration(days: 200)),
        );
      }
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));

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
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Grower',
        paidPerUnit: 100.0,
        valuePerUnit: 150.0,
        dateAdded: DateTime.now().subtract(const Duration(days: 200)),
      );
      await fx.pumpScreen(tester, BestReturnsScreen(database: fx.db));
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
