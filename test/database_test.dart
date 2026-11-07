import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';

import 'helpers.dart';

void main() {
  final fx = DbFixture();

  test('upsertItem is idempotent -- re-running with the same importedId never duplicates the row', () async {
    final entry = CollectionItemsCompanion.insert(
      importedId: 'card-1',
      name: 'Charizard',
    );
    await fx.db.upsertItem(entry);
    await fx.db.upsertItem(entry);
    await fx.db.upsertItem(entry);

    final rows = await fx.db.select(fx.db.collectionItems).get();
    expect(rows, hasLength(1));
  });

  test('upsertItem updates in place when the same importedId reappears with new data', () async {
    await seedItem(fx.db, importedId: 'card-1', name: 'Charizard');
    await seedItem(fx.db, importedId: 'card-1', name: 'Charizard (Renamed)');

    final rows = await fx.db.select(fx.db.collectionItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Charizard (Renamed)');
  });

  test(
    'REQ-007: a failed transaction rolls back every write in it, not just the failing one',
    () async {
      await seedItem(fx.db, importedId: 'existing', name: 'Pre');

      await expectLater(
        fx.db.transaction(() async {
          await seedItem(fx.db, importedId: 'card-1', name: 'A');
          throw Exception('simulated mid-import failure');
        }),
        throwsException,
      );

      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'existing');
    },
  );

  test(
    'REQ-008: deleteMissingImportedIds removes rows absent from the new import set',
    () async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Kept');
      await seedItem(fx.db, importedId: 'card-2', name: 'Sold');

      await fx.db.deleteMissingImportedIds(['card-1']);

      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');
    },
  );

  test(
    'REQ-008: deleteMissingImportedIds is idempotent -- re-running with the same set changes nothing',
    () async {
      await seedItem(fx.db, importedId: 'card-1', name: 'Kept');
      await seedItem(fx.db, importedId: 'card-2', name: 'Sold');

      await fx.db.deleteMissingImportedIds(['card-1']);
      await fx.db.deleteMissingImportedIds(['card-1']);

      final rows = await fx.db.select(fx.db.collectionItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.importedId, 'card-1');
    },
  );
}
