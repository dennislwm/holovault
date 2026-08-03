import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/main.dart';

// ponytail: drift's StreamBuilder-backed watch() query schedules a
// zero-duration cleanup Timer on unmount (StreamQueryStore.markAsClosed).
// testWidgets() auto-unmounts after the test body returns, so that timer is
// created after any in-body pump can flush it -- the failure isn't a race
// during the test, it's the framework's own automatic teardown. Unmounting
// ourselves as the last step, under a pump we control, fixes it at the one
// place every test needs it, instead of pumps sprinkled after each action.
Future<void> disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('shows empty state with no items', (WidgetTester tester) async {
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();

    expect(find.text('No items yet'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('lists items and opens the detail screen on tap', (
    WidgetTester tester,
  ) async {
    await db.upsertItem(importedId: 'card-1', name: 'Charizard');
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();

    expect(find.text('Charizard'), findsOneWidget);

    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();

    expect(find.text('Item detail'), findsOneWidget);
    expect(find.text('Charizard'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('saving the detail form persists the edited name', (
    WidgetTester tester,
  ) async {
    await db.upsertItem(importedId: 'card-1', name: 'Charizard');
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Blastoise');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.collectionItems).get();
    expect(rows.single.name, 'Blastoise');

    await disposeAndFlush(tester);
  });
}
