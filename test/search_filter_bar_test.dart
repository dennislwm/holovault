import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/widgets/search_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final items = const [
    CollectionItem(id: 1, importedId: '1', name: 'Charizard', rarity: 'Holo'),
    CollectionItem(id: 2, importedId: '2', name: 'Blastoise', rarity: 'Sealed'),
  ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilterBar(
            prefsKeyPrefix: 'test',
            items: items,
            onFiltered: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> saveAs(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip('Save as...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Preset name'), name);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('REQ-037: saving a preset then reloading a fresh instance shows it in the dropdown',
      (WidgetTester tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'char');
    await tester.pump();
    await saveAs(tester, 'Charizards');

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await disposeAndFlush(tester);

    // Fresh instance, same prefsKeyPrefix -- proves the preset persisted,
    // not just held in the disposed widget's in-memory state.
    await pump(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Charizards'), findsWidgets);

    await disposeAndFlush(tester);
  });

  testWidgets('REQ-037: applying a preset restores its search term into the live state',
      (WidgetTester tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'char');
    await tester.pump();
    await saveAs(tester, 'Charizards');

    // Clear the live search term, then reapply the preset.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(find.text('char'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Charizards').last);
    await tester.pumpAndSettle();

    expect(find.text('char'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('REQ-037: saving under an existing name replaces it, not duplicates it',
      (WidgetTester tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'char');
    await tester.pump();
    await saveAs(tester, 'Charizards');
    await tester.enterText(find.byType(TextField).first, 'blast');
    await tester.pump();
    await saveAs(tester, 'Charizards');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Charizards'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('REQ-037: deleting a preset removes it from the dropdown',
      (WidgetTester tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, 'char');
    await tester.pump();
    await saveAs(tester, 'Charizards');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await disposeAndFlush(tester);
  });
}
