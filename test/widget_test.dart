import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/main.dart';
import 'package:holovault/screens/collection_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // ADR-15: ValueTrendScreen now mounts eagerly alongside
    // CollectionListScreen inside HolovaultShell's IndexedStack, so its
    // SharedPreferences.getInstance() call runs even on tests that only
    // ever look at the Collection tab.
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('REQ-040: app-wide theme is wired in, not Flutter\'s unstyled default',
      (WidgetTester tester) async {
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();

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
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          rarity: const Value('Holo'),
          valueTotal: const Value(100.0),
          dateAdded: Value(DateTime(2026, 1, 1)),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Blastoise',
          rarity: const Value('Common'),
          valueTotal: const Value(50.0),
          dateAdded: Value(DateTime(2026, 2, 1)),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Charizard'), findsOneWidget);

      await tester.tap(find.text('Value trend'));
      await tester.pumpAndSettle();
      // REQ-034 (ADR-19): the clause-builder bottom sheet replaces the old
      // Rarity dropdown -- same field/operator/value sequence as
      // widget_test.dart's own "adding a clause via the bottom sheet" test.
      await tester.tap(find.text('Add clause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Field').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rarity').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operator').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('=').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Value').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Holo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
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

  testWidgets('lists items and opens the detail screen on tap', (
    WidgetTester tester,
  ) async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
    );
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();

    expect(find.text('Charizard'), findsOneWidget);

    await tester.tap(find.text('Charizard'));
    await tester.pumpAndSettle();

    expect(find.text('Item detail'), findsOneWidget);
    // REQ-014: the item name now renders twice -- once in the hero banner,
    // once in the editable name field below it.
    expect(find.text('Charizard'), findsNWidgets(2));

    await disposeAndFlush(tester);
  });

  testWidgets('saving the detail form persists the edited name', (
    WidgetTester tester,
  ) async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
    );
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

  testWidgets('import parses rows and persists them via upsertItem', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionListScreen(
          database: db,
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
    final rows = await db.select(db.collectionItems).get();
    expect(rows, hasLength(2));

    await disposeAndFlush(tester);
  });

  testWidgets(
    'saving the detail form does not wipe the item\'s other imported fields',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          valueTotal: const Value(10765.74),
          rarity: const Value('Sealed'),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charizard'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Blastoise');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final row = (await db.select(db.collectionItems).get()).single;
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
            database: db,
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

      final row = (await db.select(db.collectionItems).get()).single;
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
          database: db,
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

    final rows = await db.select(db.collectionItems).get();
    expect(rows, hasLength(1));

    await disposeAndFlush(tester);
  });

  testWidgets(
    'REQ-010: import shows a SnackBar instead of crashing when parseFile() throws',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: (path) async => throw const FormatException('bad csv'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Import failed'), findsOneWidget);
      final rows = await db.select(db.collectionItems).get();
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
            database: db,
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

      final rows = await db.select(db.collectionItems).get();
      expect(rows, isEmpty);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-011: import refuses a row with a malformed quantity instead of crashing',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      Future<List<Map<String, String?>>> parseFile(String path) async => [
        {'id': 'card-2', 'product_name': 'Blastoise', 'quantity': 'abc'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Import refused'), findsOneWidget);
      final rows = await db.select(db.collectionItems).get();
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
            database: db,
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

      final rows = await db.select(db.collectionItems).get();
      expect(rows, isEmpty);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-014: list row shows a quantity chip',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          quantity: const Value(3),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

      expect(find.text('×3'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-014: detail screen shows read-only imported fields grouped above the editable form',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Arceus V',
          setName: const Value('Sword & Shield Promos'),
          discriminator: const Value('267/S-P'),
          rarity: const Value('Promo'),
          quantity: const Value(1),
          valueTotal: const Value(115.19),
          valuePerUnit: const Value(115.19),
          paidTotal: const Value(85.25),
          paidPerUnit: const Value(85.25),
          gradeType: const Value('PSA'),
          gradeSubtype: const Value('10 GEM-MT'),
          dateAdded: Value(DateTime.parse('2026-03-24T22:37:38')),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
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
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Blastoise'),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
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
            database: db,
            pickFile: () async => '/fake/path/export.json',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported'), findsOneWidget);
      final rows = await db.select(db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.valueTotal, isNull);
      expect(rows.single.valuePerUnit, isNull);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-009: import with zero parsed rows leaves the existing collection untouched',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      Future<List<Map<String, String?>>> parseFile(String path) async => [];
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionListScreen(
            database: db,
            pickFile: () async => '/fake/path/export.csv',
            parseFile: parseFile,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_upload));
      await tester.pumpAndSettle();

      expect(find.text('Import found no rows'), findsOneWidget);
      final rows = await db.select(db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-029: Collection Distribution card shows Sealed/Graded/Ungraded '
    'amount and percent inline, above the item list',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Booster Box',
          rarity: const Value('Sealed'),
          valueTotal: const Value(150.0),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Arceus V',
          gradeType: const Value('PSA'),
          valueTotal: const Value(50.0),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-3',
          name: 'Pikachu',
          gradeType: const Value('Ungraded'),
          valueTotal: const Value(0.0),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

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
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Blastoise'),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

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
    'REQ-031: match-count line updates as the search bar narrows the list',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Blastoise'),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

      expect(find.text('2 matching items'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'char');
      await tester.pumpAndSettle();

      expect(find.text('1 matching items'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  testWidgets(
    'REQ-032: matching value and % of collection update as the search bar narrows the list',
    (WidgetTester tester) async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard',
          valueTotal: const Value(300),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Blastoise',
          valueTotal: const Value(100),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

      // Both items match: value = 300+100 = 400.00, 100.0% of the whole
      // collection (which is just these two items).
      expect(find.text('\$400.00'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'char');
      await tester.pumpAndSettle();

      // Narrowed to Charizard only: value = 300.00, 75.0% of the 400.00 whole.
      expect(find.text('\$300.00'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);

      await disposeAndFlush(tester);
    },
  );

  test(
    'REQ-032: collectionDistribution()\'s three buckets are exhaustive -- '
    'summing them equals the sum over every item, including items with a '
    'rarity/gradeType combination outside the "obvious" Sealed/Ungraded cases',
    () {
      final items = [
        CollectionItem(
          id: 1,
          importedId: '1',
          name: 'A',
          rarity: 'Sealed',
          valueTotal: 10,
        ),
        CollectionItem(
          id: 2,
          importedId: '2',
          name: 'B',
          gradeType: 'Ungraded',
          valueTotal: 20,
        ),
        CollectionItem(
          id: 3,
          importedId: '3',
          name: 'C',
          gradeType: 'PSA',
          valueTotal: 30,
        ),
        // Neither rarity nor gradeType set at all -- still falls into the
        // unconditional final "Graded" branch, not skipped.
        CollectionItem(id: 4, importedId: '4', name: 'D', valueTotal: 40),
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
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Booster Box',
          rarity: const Value('Sealed'),
        ),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-2',
          name: 'Charizard ex',
          rarity: const Value('Holo'),
        ),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add clause'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rarity').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Operator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('=').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Value'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sealed').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

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
        home: CollectionListScreen(database: db, pickFile: () async => null),
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
        await db.upsertItem(
          CollectionItemsCompanion.insert(importedId: 'card-$i', name: 'Card $i'),
        );
      }
      await tester.pumpWidget(
        MaterialApp(home: CollectionListScreen(database: db)),
      );
      await tester.pumpAndSettle();

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
        await db.upsertItem(
          CollectionItemsCompanion.insert(
            importedId: id,
            name: name,
            valueTotal: Value(value),
          ),
        );
      }
      List<String> order() => [
        for (final n in ['Aa', 'Bb', 'Cc']) n,
      ]..sort((a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy));

      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
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
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
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
        await db.upsertItem(CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Bb'));
        await db.upsertItem(CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Aa'));
        await tester.pumpWidget(HolovaultApp(database: db));
        await tester.pumpAndSettle();

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
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Aa', valueTotal: const Value(10)),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Bb', valueTotal: const Value(30)),
      );
      await tester.pumpWidget(HolovaultApp(database: db));
      await tester.pumpAndSettle();
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
}
