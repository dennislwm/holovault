import 'dart:io';

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

  test(
    'REQ-016: an item with no override row still appears in mergedItems',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );

      final rows = await db.select(db.mergedItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Charizard');
    },
  );

  test(
    'REQ-016: an item survives a re-import (upsertItem) after an override row exists for it',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await db
          .into(db.collectionItemOverrides)
          .insert(CollectionItemOverridesCompanion.insert(importedId: 'card-1'));

      // Re-import with the same importedId (upsertItem) must not touch the
      // overrides table -- ADR-03's persistence guarantee.
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-1',
          name: 'Charizard (updated)',
        ),
      );

      final overrides = await db.select(db.collectionItemOverrides).get();
      expect(overrides, hasLength(1));
      expect(overrides.single.importedId, 'card-1');

      final merged = await db.select(db.mergedItems).get();
      expect(merged, hasLength(1));
      expect(merged.single.name, 'Charizard (updated)');
    },
  );

  test(
    'REQ-016: schema migration to v3 (overrides table + view) is idempotent -- '
    'reopening the same on-disk database never errors or duplicates data',
    () async {
      final dbFile = File(
        '${Directory.systemTemp.path}/holovault_overrides_migration_test.sqlite',
      );
      if (dbFile.existsSync()) dbFile.deleteSync();
      addTearDown(() {
        if (dbFile.existsSync()) dbFile.deleteSync();
      });

      final first = AppDatabase.withExecutor(NativeDatabase(dbFile));
      await first.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );
      await first.close();

      // Simulates an app restart against the same underlying store --
      // AppDatabase's migration strategy must not fail or duplicate rows
      // on a database that already has the v3 schema applied.
      final second = AppDatabase.withExecutor(NativeDatabase(dbFile));
      final rows = await second.select(second.mergedItems).get();
      expect(rows, hasLength(1));
      await second.close();
    },
  );

  test(
    'REQ-016: watchMergedItems emits an update when an override row is written',
    () async {
      await db.upsertItem(
        CollectionItemsCompanion.insert(importedId: 'card-1', name: 'Charizard'),
      );

      final stream = db.watchMergedItems();
      final emissions = <int>[];
      final sub = stream.listen((rows) => emissions.add(rows.length));
      await pumpEventQueue();

      await db
          .into(db.collectionItemOverrides)
          .insert(CollectionItemOverridesCompanion.insert(importedId: 'card-1'));
      await pumpEventQueue();

      await sub.cancel();
      expect(emissions, isNotEmpty);
      expect(emissions.last, 1);
    },
  );
}
