import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertItem inserts a new row', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
    );

    final rows = await db.select(db.collectionItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Charizard');
  });

  test('upsertItem is idempotent -- re-running with the same importedId never duplicates the row', () async {
    final entry = CollectionItemsCompanion.insert(
      importedId: 'card-1',
      name: 'Charizard',
    );
    await db.upsertItem(entry);
    await db.upsertItem(entry);
    await db.upsertItem(entry);

    final rows = await db.select(db.collectionItems).get();
    expect(rows, hasLength(1));
  });

  test('upsertItem updates in place when the same importedId reappears with new data', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: 'card-1',
        name: 'Charizard (Renamed)',
      ),
    );

    final rows = await db.select(db.collectionItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Charizard (Renamed)');
  });

  test(
    'REQ-007: a failed transaction rolls back every write in it, not just the failing one',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'existing', name: 'Pre'),
      );

      await expectLater(
        db.transaction(() async {
          await db.upsertItem(
            CollectionItemsCompanion.insert(importedId: 'card-1', name: 'A'),
          );
          throw Exception('simulated mid-import failure');
        }),
        throwsException,
      );

      final rows = await db.select(db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'existing');
    },
  );

  test(
    'REQ-008: deleteMissingImportedIds removes rows absent from the new import set',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Kept'),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Sold'),
      );

      await db.deleteMissingImportedIds(['card-1']);

      final rows = await db.select(db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');
    },
  );

  test(
    'REQ-008: deleteMissingImportedIds is idempotent -- re-running with the same set changes nothing',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Kept'),
      );
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-2', name: 'Sold'),
      );

      await db.deleteMissingImportedIds(['card-1']);
      await db.deleteMissingImportedIds(['card-1']);

      final rows = await db.select(db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');
    },
  );
}
