import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Minimal proof-of-concept schema for ADR-01 (persistence choice).
/// A full import-feature schema is out of scope until a REQ defines it --
/// this table only demonstrates the drift/native storage mechanism works,
/// including upsert-on-conflict for idempotent re-imports.
class CollectionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get importedId => text().unique()();
  TextColumn get name => text()();
  TextColumn get extra => text().nullable()();
}

@DriftDatabase(tables: [CollectionItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor: bypasses path_provider/driftDatabase so tests
  /// can run against an in-memory database with no filesystem dependency.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  /// Inserts a collection item, or updates it in place if `importedId`
  /// already exists -- re-running an import with the same source data
  /// never duplicates a row.
  Future<void> upsertItem({
    required String importedId,
    required String name,
    String? extra,
  }) {
    final entry = CollectionItemsCompanion.insert(
      importedId: importedId,
      name: name,
      extra: Value(extra),
    );
    return into(collectionItems).insert(
      entry,
      onConflict: DoUpdate(
        (old) => entry,
        target: [collectionItems.importedId],
      ),
    );
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
