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
}
