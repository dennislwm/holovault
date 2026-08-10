import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/main.dart';
import 'package:holovault/screens/collection_list_screen.dart';

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
      await tester.tap(find.text('Charizard'));
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
}
