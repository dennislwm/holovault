import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/screens/collection_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// ponytail: drift's StreamBuilder-backed watch() query schedules a
// zero-duration cleanup Timer on unmount (StreamQueryStore.markAsClosed).
// testWidgets() auto-unmounts after the test body returns, so that timer is
// created after any in-body pump can flush it -- the failure isn't a race
// during the test, it's the framework's own automatic teardown. Unmounting
// ourselves as the last step, under a pump we control, fixes it at the one
// place every test needs it, instead of pumps sprinkled after each action.
void main() {
  final fx = WidgetFixture();

  testWidgets('shows empty state with no items', (WidgetTester tester) async {
    await fx.pumpApp(tester);

    expect(find.text('No items yet'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  // REQ-052: wiring only. The parser and the store are tested as plain
  // functions in set_lookup_test.dart.
  testWidgets('REQ-052: the overflow menu offers Import set lookup', (WidgetTester tester) async {
    await fx.pumpApp(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Import set lookup'), findsOneWidget);
    expect(find.text('Import custom fields'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets('REQ-040: app-wide theme is wired in, not Flutter\'s unstyled default',
      (WidgetTester tester) async {
    await fx.pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    // Default MaterialApp() with no theme: falls back to Colors.blue as the
    // seed -- confirming the primary differs from that default is a cheap
    // signal the ebonyClay scheme (not Flutter's own fallback) is applied.
    expect(app.theme!.colorScheme.primary, isNot(Colors.blue));

    await disposeAndFlush(tester);
  });

  testWidgets(
    'REQ-027: switching tabs preserves ValueTrendScreen filter state '
    'instead of resetting it',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        rarity: 'Holo',
        valueTotal: 100.0,
        dateAdded: DateTime(2026, 1, 1),
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Blastoise',
        rarity: 'Common',
        valueTotal: 50.0,
        dateAdded: DateTime(2026, 2, 1),
      );
      await fx.pumpApp(tester);

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Charizard'), findsOneWidget);

      await tester.tap(find.text('Value trend'));
      await tester.pumpAndSettle();
      // REQ-034 (ADR-19): the clause-builder bottom sheet replaces the old
      // Rarity dropdown -- same field/operator/value sequence as
      // widget_test.dart's own "adding a clause via the bottom sheet" test.
      await addClause(tester, field: 'Rarity', op: '=', value: 'Holo');
      expect(find.text('1 matching items'), findsOneWidget);

      // Switch to Collection, then back to Value trend -- with a pushed
      // AppBar/Navigator.push this would rebuild the screen from scratch
      // and reset the filter; IndexedStack keeps it mounted instead.
      await tester.tap(find.text('Collection'));
      await tester.pumpAndSettle();
      expect(find.text('Charizard'), findsOneWidget);

      await tester.tap(find.text('Value trend'));
      await tester.pumpAndSettle();
      expect(find.text('Rarity = Holo'), findsOneWidget);
      expect(find.text('1 matching items'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  test(
    'REQ-018: schemaErrorMessage names UnsupportedSchemaVersionException '
    'specifically, and falls back to a generic message for anything else',
    () {
      expect(
        schemaErrorMessage(UnsupportedSchemaVersionException(4)),
        "This collection database is from an unrecognized app version and "
        "can't be opened.",
      );
      expect(
        schemaErrorMessage(Exception('some other failure')),
        'Something went wrong loading your collection.',
      );
    },
  );

  testWidgets('saving the detail form persists the edited name', (
    WidgetTester tester,
  ) async {
    await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
    await fx.pumpApp(tester);
    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Blastoise');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await fx.db.select(fx.db.collectionItems).get();
    expect(rows.single.name, 'Blastoise');

    await disposeAndFlush(tester);
  });

  testWidgets('import parses rows and persists them via upsertItem', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionListScreen(
          database: fx.db,
          pickFile: () async => '/fake/path/export.csv',
          parseFile: (path) async => [
            {'id': 'card-1', 'product_name': 'Charizard', 'extra': null},
            {'id': 'card-2', 'product_name': 'Blastoise', 'extra': null},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();

    expect(find.text('Imported 2 item(s)'), findsOneWidget);
    final rows = await fx.db.select(fx.db.collectionItems).get();
    expect(rows, hasLength(2));

    await disposeAndFlush(tester);
  });

  testWidgets(
    'saving the detail form does not wipe the item\'s other imported fields',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Charizard',
        valueTotal: 10765.74,
        rarity: 'Sealed',
      );
      await fx.pumpApp(tester);
      await tester.tap(find.text('Charizard'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Blastoise');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final row = (await fx.db.select(fx.db.collectionItems).get()).single;
      expect(row.name, 'Blastoise');
      expect(row.valueTotal, 10765.74);
      expect(row.rarity, 'Sealed');

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'import coerces typed fields and converts the CSV null literal to real null',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: (path) async => [
              {
                'id': 'card-1',
                'product_name': 'Charizard',
                'quantity': '2',
                'value_total': '10765.74',
                'group_wishlist': 'false',
                // ponytail: drift's default DateTimeColumn stores unix
                // seconds, truncating sub-second precision -- using a
                // whole-second timestamp here so the test isn't asserting
                // on that unrelated storage-precision detail.
                'date_added': '2026-01-18T22:45:41',
                'tcgplayer_id': 'null',
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      final row = (await fx.db.select(fx.db.collectionItems).get()).single;
      expect(row.quantity, 2);
      expect(row.valueTotal, 10765.74);
      expect(row.groupWishlist, false);
      expect(row.dateAdded, DateTime.parse('2026-01-18T22:45:41'));
      expect(row.tcgplayerId, isNull);

      await disposeAndFlush(tester);
    },
  );

  testWidgets('re-importing the same file never duplicates rows', (
    WidgetTester tester,
  ) async {
    Future<List<Map<String, String?>>> parseFile(String path) async => [
      {'id': 'card-1', 'product_name': 'Charizard', 'extra': null},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionListScreen(
          database: fx.db,
          pickFile: () async => '/fake/path/export.csv',
          parseFile: parseFile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();

    final rows = await fx.db.select(fx.db.collectionItems).get();
    expect(rows, hasLength(1));

    await disposeAndFlush(tester);
  });

  testWidgets(
    'REQ-010: import shows a SnackBar instead of crashing when parseFile() throws',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: (path) async => throw const FormatException('bad csv'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Import failed'), findsOneWidget);
      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-010: import is idempotent -- parseFile() throwing twice leaves state unchanged both times',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: (path) async => throw const FormatException('bad csv'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, isEmpty);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-011: import refuses a row with a malformed quantity instead of crashing',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      Future<List<Map<String, String?>>> parseFile(String path) async => [
        {'id': 'card-2', 'product_name': 'Blastoise', 'quantity': 'abc'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Import refused'), findsOneWidget);
      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-011: import refuses the same malformed row twice, leaving state unchanged both times',
    (WidgetTester tester) async {
      Future<List<Map<String, String?>>> parseFile(String path) async => [
        {'id': 'card-1', 'product_name': 'Charizard', 'date_added': 'not-a-date'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, isEmpty);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-014: detail screen shows read-only imported fields grouped above the editable form',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Arceus V',
        setName: 'Sword & Shield Promos',
        discriminator: '267/S-P',
        rarity: 'Promo',
        quantity: 1,
        valueTotal: 115.19,
        valuePerUnit: 115.19,
        paidTotal: 85.25,
        paidPerUnit: 85.25,
        gradeType: 'PSA',
        gradeSubtype: '10 GEM-MT',
        dateAdded: DateTime.parse('2026-03-24T22:37:38'),
      );
      await fx.pumpApp(tester);
      await tester.tap(find.text('Arceus V'));
      await tester.pumpAndSettle();

      expect(find.text('IMPORTED DATA'), findsOneWidget);
      expect(find.text('Sword & Shield Promos'), findsOneWidget);
      expect(find.text('267/S-P'), findsOneWidget);
      expect(find.text('Promo'), findsOneWidget);
      expect(find.text('115.19'), findsNWidgets(2));
      expect(find.text('85.25'), findsNWidgets(2));
      expect(find.text('PSA 10 GEM-MT'), findsOneWidget);
      expect(find.text('24 Mar 2026'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-014: detail screen shows a position indicator and swipe hint',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      await seedItem(fx.db, importedId: 'card-2', name: 'Blastoise');
      await fx.pumpApp(tester);
      // REQ-042 (b): Collection now defaults to Name ascending, so Blastoise is 1.
      await tester.tap(find.text('Blastoise'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.textContaining('swipe'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-012: import accepts "Unavailable" for value_total/value_per_unit as null, matching the real ShinyExport sentinel',
    (WidgetTester tester) async {
      Future<List<Map<String, String?>>> parseFile(String path) async => [
        {
          'id': 'card-1',
          'product_name': 'Charizard',
          'value_total': 'Unavailable',
          'value_per_unit': 'Unavailable',
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.json',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported'), findsOneWidget);
      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.valueTotal, isNull);
      expect(rows.single.valuePerUnit, isNull);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-009: import with zero parsed rows leaves the existing collection untouched',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      Future<List<Map<String, String?>>> parseFile(String path) async => [];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: fx.db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.text('Import found no rows'), findsOneWidget);
      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-029: Collection Distribution card shows Sealed/Graded/Ungraded '
    'amount and percent inline, above the item list',
    (WidgetTester tester) async {
      await seedItem(
        fx.db,
        importedId: 'card-1',
        name: 'Booster Box',
        rarity: 'Sealed',
        valueTotal: 150.0,
      );
      await seedItem(
        fx.db,
        importedId: 'card-2',
        name: 'Arceus V',
        gradeType: 'PSA',
        valueTotal: 50.0,
      );
      await seedItem(
        fx.db,
        importedId: 'card-3',
        name: 'Pikachu',
        gradeType: 'Ungraded',
        valueTotal: 0.0,
      );
      await fx.pumpApp(tester);

      expect(find.text('COLLECTION DISTRIBUTION'), findsOneWidget);
      expect(find.text('\$150.00 · 75.0%'), findsOneWidget);
      expect(find.text('\$50.00 · 25.0%'), findsOneWidget);
      expect(find.text('\$0.00 · 0.0%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-030: typing in the search bar narrows the item list',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
      await seedItem(fx.db, importedId: 'card-2', name: 'Blastoise');
      await fx.pumpApp(tester);

      expect(find.text('Charizard'), findsOneWidget);
      expect(find.text('Blastoise'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'char');
      await tester.pumpAndSettle();

      expect(find.text('Charizard'), findsOneWidget);
      expect(find.text('Blastoise'), findsNothing);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-032: matching value and % of collection update as the search bar narrows the list',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Charizard', valueTotal: 300);
      await seedItem(fx.db, importedId: 'card-2', name: 'Blastoise', valueTotal: 100);
      await fx.pumpApp(tester);

      // Both items match: value = 300+100 = 400.00, 100.0% of the whole
      // collection (which is just these two items).
      expect(find.text('\$400.00'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.text('2 matching items'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'char');
      await tester.pumpAndSettle();

      // Narrowed to Charizard only: value = 300.00, 75.0% of the 400.00 whole.
      expect(find.text('\$300.00'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('1 matching items'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  test(
    'REQ-032: collectionDistribution()\'s three buckets are exhaustive -- '
    'summing them equals the sum over every item, including items with a '
    'rarity/gradeType combination outside the "obvious" Sealed/Ungraded cases',
    () {
      final items = [
        const MergedItem(
          id: 1,
          importedId: '1',
          name: 'A',
          rarity: 'Sealed',
          valueTotal: 10,
        ),
        const MergedItem(
          id: 2,
          importedId: '2',
          name: 'B',
          gradeType: 'Ungraded',
          valueTotal: 20,
        ),
        const MergedItem(
          id: 3,
          importedId: '3',
          name: 'C',
          gradeType: 'PSA',
          valueTotal: 30,
        ),
        // Neither rarity nor gradeType set at all -- still falls into the
        // unconditional final "Graded" branch, not skipped.
        const MergedItem(id: 4, importedId: '4', name: 'D', valueTotal: 40),
      ];

      final bucketSum = collectionDistribution(
        items,
      ).values.fold(0.0, (sum, v) => sum + v);
      final directSum = items.fold(0.0, (sum, i) => sum + (i.valueTotal ?? 0));

      expect(bucketSum, directSum);
      expect(bucketSum, 100);
    },
  );

  testWidgets(
    'REQ-030: adding a clause via the bottom sheet narrows the item list',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Booster Box', rarity: 'Sealed');
      await seedItem(fx.db, importedId: 'card-2', name: 'Charizard ex', rarity: 'Holo');
      await fx.pumpApp(tester);

      await addClause(tester, field: 'Rarity', op: '=', value: 'Sealed');

      expect(find.text('Booster Box'), findsOneWidget);
      expect(find.text('Charizard ex'), findsNothing);
      expect(find.text('Rarity = Sealed'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets('import button shows cancelled when the picker returns null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionListScreen(database: fx.db, pickFile: () async => null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();

    expect(find.text('Import cancelled'), findsOneWidget);

    await disposeAndFlush(tester);
  });

  testWidgets(
    'REQ-033: search text survives the field scrolling off-screen and back',
    (WidgetTester tester) async {
      for (var i = 0; i < 100; i++) {
        await seedItem(fx.db, importedId: 'card-$i', name: 'Card $i');
      }
      await fx.pumpScreen(tester, CollectionListScreen(database: fx.db));

      await tester.enterText(find.byType(TextField).first, 'Charizard');
      await tester.pump();

      // ADR-18's search field sits at a fixed ListView.builder index, near
      // the top; scrolling to the list end and back forces its list item
      // off-screen past the sliver's cache extent and back again.
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -100000));
      await tester.pumpAndSettle();
      await tester.drag(listFinder, const Offset(0, 100000));
      await tester.pumpAndSettle();

      expect(find.text('Charizard'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-042 (b): the sort picker and direction toggle reorder rows and persist across a restart',
    (WidgetTester tester) async {
      for (final (id, name, value) in [
        ('card-1', 'Aa', 10.0),
        ('card-2', 'Bb', null),
        ('card-3', 'Cc', 30.0),
      ]) {
        await seedItem(fx.db, importedId: id, name: name, valueTotal: value);
      }
      List<String> order() => [
        for (final n in ['Aa', 'Bb', 'Cc']) n,
      ]..sort((a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy));

      await fx.pumpApp(tester);
      expect(order(), ['Aa', 'Bb', 'Cc']); // default: Name ascending

      await tester.tap(find.byKey(const Key('sort-key-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Value').last);
      await tester.pumpAndSettle();
      expect(order(), ['Aa', 'Cc', 'Bb']); // no value last

      await tester.tap(find.byKey(const Key('sort-direction')));
      await tester.pumpAndSettle();
      expect(order(), ['Cc', 'Aa', 'Bb']); // no value still last

      // Restart: a fresh app reads the persisted key and direction.
      await tester.pumpWidget(const SizedBox());
      await fx.pumpApp(tester);
      expect(order(), ['Cc', 'Aa', 'Bb']);

      await disposeAndFlush(tester);
    },
  );

  for (final stored in <Map<String, Object>>[
    {'collection_list_filter_sort_key': 'bogus'},
    {'collection_list_filter_sort_key': 7, 'collection_list_filter_sort_asc': 'x'},
  ]) {
    testWidgets(
      'REQ-042 (b): a ${stored.containsKey("collection_list_filter_sort_asc") ? "wrong-typed" : "unknown"} stored sort falls back to the initial order',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(stored);
        await seedItem(fx.db, importedId: 'card-1', name: 'Bb');
        await seedItem(fx.db, importedId: 'card-2', name: 'Aa');
        await fx.pumpApp(tester);

        expect(
          tester.getTopLeft(find.text('Aa')).dy,
          lessThan(tester.getTopLeft(find.text('Bb')).dy),
        );

        await disposeAndFlush(tester);
      },
    );
  }

  testWidgets(
    'REQ-042 (b): changing the sort key resets a descending direction to ascending',
    (WidgetTester tester) async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Aa', valueTotal: 10);
      await seedItem(fx.db, importedId: 'card-2', name: 'Bb', valueTotal: 30);
      await fx.pumpApp(tester);
      await tester.tap(find.byKey(const Key('sort-direction'))); // Name descending
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sort-key-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Value').last);
      await tester.pumpAndSettle();

      // Value ascending: Aa (10) above Bb (30).
      expect(
        tester.getTopLeft(find.text('Aa')).dy,
        lessThan(tester.getTopLeft(find.text('Bb')).dy),
      );

      await disposeAndFlush(tester);
    },
  );

  Future<void> seedColumnsItem() => fx.db.upsertItem(
    CollectionItemsCompanion.insert(
      importedId: 'card-1',
      name: 'Charizard',
      extra: const Value('first ed'),
      quantity: const Value(3),
      paidTotal: const Value(40),
    ),
  );

  testWidgets(
    'REQ-042 (c): columns dialog changes the row, a restart keeps it, and clearing every column restores the default',
    (WidgetTester tester) async {
      await seedColumnsItem();
      await fx.pumpApp(tester);
      expect(find.text('first ed'), findsOneWidget); // default subtitle: Extra
      expect(find.text('×3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('columns-button')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Quantity'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsNothing);
      expect(find.text('Paid: 40.00'), findsOneWidget);

      // Restart: the persisted columns come back.
      await tester.pumpWidget(const SizedBox());
      await fx.pumpApp(tester);
      expect(find.text('Paid: 40.00'), findsOneWidget);

      // Uncheck everything: the screen default returns.
      await tester.tap(find.byKey(const Key('columns-button')).first);
      await tester.pumpAndSettle();
      for (final label in ['Name', 'Extra', 'Paid']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, label));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('first ed'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-042 (c): dragging a column to the top makes it the row title',
    (WidgetTester tester) async {
      await seedColumnsItem();
      await fx.pumpApp(tester);

      await tester.tap(find.byKey(const Key('columns-button')).first);
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const Key('drag-quantity')), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Quantity (title), Name (subtitle), Extra now trailing and labelled.
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('Extra: first ed'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('×3')).dy,
        lessThan(tester.getTopLeft(find.text('Charizard')).dy),
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-042 (c): stored column ids that match no field are skipped on load',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'collection_list_filter_columns': '["bogus","quantity","name"]',
      });
      await seedColumnsItem();
      await fx.pumpApp(tester);

      expect(
        tester.getTopLeft(find.text('×3')).dy,
        lessThan(tester.getTopLeft(find.text('Charizard')).dy),
      );

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-042 (c): a chosen Return/annual column draws a bar scaled to the displayed maximum',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'collection_list_filter_columns': '["name","extra","returnAnnual"]',
      });
      final bought = DateTime.now().subtract(const Duration(days: 365));
      for (final (id, name, paid, value) in [
        ('card-1', 'Big', 100.0, 200.0),
        ('card-2', 'Small', 100.0, 150.0),
      ]) {
        await seedItem(
          fx.db,
          importedId: id,
          name: name,
          paidPerUnit: paid,
          valuePerUnit: value,
          dateAdded: bought,
        );
      }
      await fx.pumpApp(tester);

      final bars = tester
          .widgetList<LinearProgressIndicator>(find.byKey(const Key('return-bar')))
          .map((b) => b.value!)
          .toList();
      expect(bars.length, 2);
      expect(bars.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-9));
      expect(bars.reduce((a, b) => a < b ? a : b), lessThan(1.0));

      await disposeAndFlush(tester);
    },
  );
}
