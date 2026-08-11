import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'overrides_schema.dart';

part 'database.g.dart';

/// ADR-07, Option 3: thrown by [AppDatabase.migration] when the on-disk
/// database's version has no matching migration branch -- a rollback to an
/// older app build, a restored backup predating a schema change, or file
/// corruption, none of which should be allowed to silently no-op or crash
/// on an unrelated query later.
class UnsupportedSchemaVersionException implements Exception {
  final int from;
  UnsupportedSchemaVersionException(this.from);

  @override
  String toString() =>
      'UnsupportedSchemaVersionException: no migration path from schema '
      'version $from';
}

/// Real import-feature schema per ADR-09 (Option 1: native typed columns).
/// Column types verified against `../13pyholofoil/input/ShinyExport-*.csv`'s
/// real header and sample values -- see the ADR's column/type table.
class CollectionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get importedId => text().unique()();
  TextColumn get name => text()();
  TextColumn get extra => text().nullable()();
  TextColumn get setName => text().nullable()();
  TextColumn get brandName => text().nullable()();
  TextColumn get discriminator => text().nullable()();
  TextColumn get rarity => text().nullable()();
  IntColumn get quantity => integer().nullable()();
  RealColumn get valueTotal => real().nullable()();
  RealColumn get valuePerUnit => real().nullable()();
  TextColumn get valueCurrency => text().nullable()();
  RealColumn get paidTotal => real().nullable()();
  RealColumn get paidPerUnit => real().nullable()();
  TextColumn get paidCurrency => text().nullable()();
  TextColumn get gradeType => text().nullable()();
  TextColumn get gradeSubtype => text().nullable()();
  TextColumn get groupName => text().nullable()();
  BoolColumn get groupWishlist => boolean().nullable()();
  TextColumn get tcgplayerId => text().nullable()();
  TextColumn get pricechartingId => text().nullable()();
  TextColumn get doubleholoId => text().nullable()();
  DateTimeColumn get dateAdded => dateTime().nullable()();
  TextColumn get tag => text().nullable()();
}

@DriftDatabase(
  tables: [CollectionItems, CollectionItemOverrides],
  views: [MergedItems],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor: bypasses path_provider/driftDatabase so tests
  /// can run against an in-memory database with no filesystem dependency.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  /// ADR-09: v1 had only importedId/name/extra. v2 adds the 19 real
  /// ShinyExport fields -- all nullable, so no default value is needed for
  /// pre-existing rows.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      var handled = false;
      if (from < 2) {
        await m.addColumn(collectionItems, collectionItems.setName);
        await m.addColumn(collectionItems, collectionItems.brandName);
        await m.addColumn(collectionItems, collectionItems.discriminator);
        await m.addColumn(collectionItems, collectionItems.rarity);
        await m.addColumn(collectionItems, collectionItems.quantity);
        await m.addColumn(collectionItems, collectionItems.valueTotal);
        await m.addColumn(collectionItems, collectionItems.valuePerUnit);
        await m.addColumn(collectionItems, collectionItems.valueCurrency);
        await m.addColumn(collectionItems, collectionItems.paidTotal);
        await m.addColumn(collectionItems, collectionItems.paidPerUnit);
        await m.addColumn(collectionItems, collectionItems.paidCurrency);
        await m.addColumn(collectionItems, collectionItems.gradeType);
        await m.addColumn(collectionItems, collectionItems.gradeSubtype);
        await m.addColumn(collectionItems, collectionItems.groupName);
        await m.addColumn(collectionItems, collectionItems.groupWishlist);
        await m.addColumn(collectionItems, collectionItems.tcgplayerId);
        await m.addColumn(collectionItems, collectionItems.pricechartingId);
        await m.addColumn(collectionItems, collectionItems.doubleholoId);
        await m.addColumn(collectionItems, collectionItems.dateAdded);
        await m.addColumn(collectionItems, collectionItems.tag);
        handled = true;
      }
      if (from < 3) {
        // ADR-03, Option 3: this branch runs at most once per install,
        // gated by drift's own schemaVersion tracking (`from < 3` is only
        // true during the single migration off an older schema).
        await m.createTable(collectionItemOverrides);
        await m.createView(mergedItems);
        handled = true;
      }
      // ADR-07, Option 3: `from` matched neither branch above -- an
      // unrecognized/newer/rolled-back schema version. Fail loudly instead
      // of silently no-op'ing and leaving queries to fail later with an
      // unrelated SQLite error.
      if (!handled) {
        throw UnsupportedSchemaVersionException(from);
      }
    },
  );

  /// Inserts a collection item, or updates it in place if `importedId`
  /// already exists -- re-running an import with the same source data
  /// never duplicates a row.
  Future<void> upsertItem(CollectionItemsCompanion entry) {
    return into(collectionItems).insert(
      entry,
      onConflict: DoUpdate((old) => entry, target: [collectionItems.importedId]),
    );
  }

  /// Reactive query for ADR-04's list screen -- emits a new list whenever
  /// the underlying table changes, so the UI stays live during import/edit.
  Stream<List<CollectionItem>> watchAllItems() =>
      select(collectionItems).watch();

  /// ADR-03, Option 3: `mergedItems` is a real drift `View`, so this gets
  /// native `.watch()` reactivity for free -- no manual polling/refresh
  /// wrapper, unlike Option 2's `customStatement`-created SQL view.
  Stream<List<MergedItem>> watchMergedItems() =>
      select(mergedItems).watch();

  /// ADR-10, Option 1: removes any row whose `importedId` is absent from
  /// the just-imported set -- an import is a full-inventory snapshot, so a
  /// row missing from it means the source item is gone.
  Future<void> deleteMissingImportedIds(List<String> importedIds) {
    return (delete(
      collectionItems,
    )..where((t) => t.importedId.isNotIn(importedIds))).go();
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'holovault',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
