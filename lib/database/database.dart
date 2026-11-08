import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../override_convert.dart';
import 'overrides_schema.dart';

part 'database.g.dart';

/// REQ-055: one step of the generated `overrideSteps`. `type` is the type after
/// the step, `from` the type before a `retype` (empty for `add`), `clear` true
/// for a retype that empties the field.
typedef OverrideStep = ({int id, String kind, String type, String from, bool clear});

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

/// REQ-052 (ADR-24 Option 3): the imported set lookup, one row per alias name
/// the source file resolved `exact`. Replaced whole by an import, never
/// written by the collection import or the overrides path.
class SetLookupRows extends Table {
  TextColumn get aliasName => text()();
  TextColumn get language => text()();
  TextColumn get tcgdexId => text().nullable()();
  TextColumn get officialName => text().nullable()();

  @override
  Set<Column> get primaryKey => {aliasName};
}

@DriftDatabase(
  tables: [CollectionItems, CollectionItemOverrides, SetLookupRows],
  views: [MergedItems],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor: bypasses path_provider/driftDatabase so tests
  /// can run against an in-memory database with no filesystem dependency.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 5;

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
        // REQ-055: the table above already has the current columns, so the
        // counter is written here and beforeOpen has nothing to recreate.
        await _ensureCounterTable();
        await customStatement(
          'INSERT INTO $_counterTable (value) VALUES ($overrideCounter)',
        );
        handled = true;
      }
      // REQ-055: installs at version 3, 4 and 5 have no counter and a
      // key-only or name-keyed overrides table; beforeOpen recreates it once.
      // (The REQ-043 `from == 3` branch that added columns by registry is
      // superseded by that.)
      if (from < 5) {
        // REQ-052: the set lookup table is new in version 5. Every install
        // below 5 gets it here, whichever branch above also ran.
        await m.createTable(setLookupRows);
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
    // REQ-055: an overrides table whose columns follow the config ids. A
    // database with no counter row is the earlier name-keyed schema (or a
    // fresh one): recreate its overrides table once, keeping the imported
    // ids, then write the counter. An existing counter, whatever its value,
    // changes nothing, so a second open is a no-op. The counter write is in
    // the same transaction as the recreate.
    beforeOpen: (details) async {
      await _ensureCounterTable();
      final have = await customSelect('SELECT value FROM $_counterTable').get();
      if (have.isNotEmpty) {
        // A stored counter behind the generated one: replay the steps in
        // between. At or above it: nothing (a rollback is a no-op).
        final stored = have.first.read<int>('value');
        if (stored < overrideCounter) await replayOverrideSteps(from: stored);
        return;
      }
      await transaction(() async {
        if (!details.wasCreated) await _recreateOverrides();
        await customStatement(
          'INSERT INTO $_counterTable (value) VALUES ($overrideCounter)',
        );
      });
    },
  );

  static const _counterTable = 'override_counter';

  static String _sqlAffinity(String type) => switch (type) {
    'text' || 'choice' => 'TEXT',
    'real' => 'REAL',
    _ => 'INTEGER',
  };

  /// REQ-055 (a): replays `steps[from..target)` on the overrides table, then
  /// recreates the merged view and stores [target], all in one transaction
  /// (the view goes first, because a retype drops and renames the column it
  /// selects). An `add` step adds its column unless it exists; one that exists
  /// with a different SQLite type fails loudly instead of being reused. A
  /// `retype` step replaces the column of its id by one of the new type,
  /// converting each value (or leaving it empty when `clear`). Defaults are
  /// the generated steps; tests pass their own.
  Future<void> replayOverrideSteps({
    required int from,
    int target = overrideCounter,
    List<OverrideStep> steps = overrideSteps,
  }) => transaction(() async {
    final m = createMigrator();
    final table = collectionItemOverrides.actualTableName;
    await m.drop(mergedItems);
    for (final s in steps.sublist(from, target)) {
      final have = {
        for (final r in await customSelect('PRAGMA table_info($table)').get())
          r.read<String>('name'): r.read<String>('type'),
      };
      switch (s.kind) {
        case 'add':
          final column = overrideColumn(collectionItemOverrides, s.id);
          if (column == null) throw StateError('override step names unknown id ${s.id}');
          final existing = have[column.name];
          if (existing == null) {
            await m.addColumn(collectionItemOverrides, column);
          } else if (existing != _sqlAffinity(s.type)) {
            throw StateError(
              'override column ${column.name} exists as $existing, step wants ${s.type}',
            );
          }
        case 'retype':
          await _retypeColumn(table, s, have);
        default:
          throw StateError('unknown override step kind ${s.kind}');
      }
    }
    await m.createView(mergedItems);
    await customStatement('UPDATE $_counterTable SET value = $target');
  });

  /// One `retype` step: add `cf<id>_new` of the new type, copy every non-null
  /// value through [convertOverrideValue] (none when the step clears), drop the
  /// old column, rename the new one to `cf<id>`. Runs inside the caller's
  /// transaction, with the merged view already dropped.
  Future<void> _retypeColumn(
    String table,
    OverrideStep s,
    Map<String, String> have,
  ) async {
    final col = 'cf${s.id}';
    final tmp = '${col}_new';
    if (!have.containsKey(col)) throw StateError('retype of missing column $col');
    final check = s.type == 'bool' ? ' CHECK ($tmp IN (0, 1))' : '';
    await customStatement(
      'ALTER TABLE $table ADD COLUMN $tmp ${_sqlAffinity(s.type)} NULL$check',
    );
    if (!s.clear) {
      final rows = await customSelect(
        'SELECT imported_id, $col AS v FROM $table WHERE $col IS NOT NULL',
      ).get();
      for (final r in rows) {
        await customStatement(
          'UPDATE $table SET $tmp = ? WHERE imported_id = ?',
          [convertOverrideValue(r.data['v'], s.from, s.type), r.read<String>('imported_id')],
        );
      }
    }
    await customStatement('ALTER TABLE $table DROP COLUMN $col');
    await customStatement('ALTER TABLE $table RENAME COLUMN $tmp TO $col');
  }

  Future<void> _ensureCounterTable() => customStatement(
    'CREATE TABLE IF NOT EXISTS $_counterTable (value INTEGER NOT NULL)',
  );

  /// Drops the view, replaces the overrides table with one of the current
  /// definition (copying only the imported ids), and recreates the view.
  Future<void> _recreateOverrides() async {
    final m = createMigrator();
    final table = collectionItemOverrides.actualTableName;
    await m.drop(mergedItems);
    await customStatement('ALTER TABLE $table RENAME TO ${table}_old');
    await m.createTable(collectionItemOverrides);
    await customStatement(
      'INSERT INTO $table (imported_id) SELECT imported_id FROM ${table}_old',
    );
    await customStatement('DROP TABLE ${table}_old');
    await m.createView(mergedItems);
  }

  /// Inserts a collection item, or updates it in place if `importedId`
  /// already exists -- re-running an import with the same source data
  /// never duplicates a row.
  Future<void> upsertItem(CollectionItemsCompanion entry) {
    return into(collectionItems).insert(
      entry,
      onConflict: DoUpdate((old) => entry, target: [collectionItems.importedId]),
    );
  }

  /// REQ-052: every stored set lookup row.
  Future<List<SetLookupRow>> allSetLookupRows() => select(setLookupRows).get();

  /// REQ-052: replaces the whole set lookup in one transaction. A failure
  /// keeps the previous rows. Writes only the lookup table.
  Future<void> replaceSetLookup(
    List<
      ({String aliasName, String language, String? tcgdexId, String? officialName})
    >
    rows,
  ) => transaction(() async {
    await delete(setLookupRows).go();
    await batch((b) {
      b.insertAll(setLookupRows, [
        for (final r in rows)
          SetLookupRowsCompanion.insert(
            aliasName: r.aliasName,
            language: r.language,
            tcgdexId: Value(r.tcgdexId),
            officialName: Value(r.officialName),
          ),
      ]);
    });
  });

  /// REQ-043 (b): the item's merged row (imported + overrides), or null.
  Future<MergedItem?> mergedItemByImportedId(String importedId) =>
      (select(mergedItems)..where((m) => m.importedId.equals(importedId)))
          .getSingleOrNull();

  /// REQ-043 (b): upserts the overrides row for [importedId] from a
  /// name-to-value map (null clears). Writes only the overrides table.
  Future<void> saveCustomFields(
    String importedId,
    Map<String, Object?> values, {
    List<CustomColumn>? registry,
  }) {
    final row = <String, Expression>{'imported_id': Variable<String>(importedId)};
    for (final c in registry ?? customColumns) {
      if (!values.containsKey(c.name)) continue;
      final v = values[c.name];
      row[c.column(collectionItemOverrides).name] =
          v == null ? const Constant<Object>(null) : Variable<Object>(v);
    }
    final entry = RawValuesInsertable<CollectionItemOverride>(row);
    return into(collectionItemOverrides).insert(
      entry,
      onConflict: DoUpdate(
        (old) => entry,
        target: [collectionItemOverrides.importedId],
      ),
    );
  }

  /// REQ-045 (iii): the item row and its custom fields in one transaction, so
  /// a failure in either leaves both as they were.
  Future<void> saveItemAndCustomFields(
    CollectionItemsCompanion item,
    String importedId,
    Map<String, Object?> values, {
    List<CustomColumn>? registry,
  }) => transaction(() async {
    await upsertItem(item);
    await saveCustomFields(importedId, values, registry: registry);
  });

  /// REQ-047: every overrides row (dormant ones included), read from the
  /// table directly, by importedId, with the registry's typed raw values.
  Future<List<({String importedId, Map<String, Object?> values})>>
  overrideRows({List<CustomColumn>? registry}) async {
    final cols = registry ?? customColumns;
    final key = collectionItemOverrides.importedId;
    final q = selectOnly(collectionItemOverrides)
      ..addColumns([key, for (final c in cols) c.column(collectionItemOverrides)])
      ..orderBy([OrderingTerm.asc(key)]);
    return [
      for (final r in await q.get())
        (
          importedId: r.read(key)!,
          values: {
            for (final c in cols)
              c.name: r.read(c.column(collectionItemOverrides)),
          },
        ),
    ];
  }

  /// REQ-047: upserts every parsed row in ONE transaction; writes only the
  /// overrides table. Only keys present in a row's values are touched.
  Future<void> importCustomFieldRows(
    List<({String importedId, Map<String, Object?> values})> rows, {
    List<CustomColumn>? registry,
  }) => transaction(() async {
    for (final r in rows) {
      await saveCustomFields(r.importedId, r.values, registry: registry);
    }
  });

  /// REQ-043 (b): raw stored values of one overrides column, over live and
  /// hidden (no longer imported) rows alike; feed to `suggestionList`.
  Future<List<String?>> storedValues(CustomColumn c) async {
    final col = c.column(collectionItemOverrides);
    final q = selectOnly(collectionItemOverrides, distinct: true)
      ..addColumns([col]);
    return (await q.get()).map((r) => r.read(col) as String?).toList();
  }

  /// Reactive query for ADR-04's list screens (REQ-043 c: merged rows, not
  /// raw imported rows) -- emits a new list whenever either table changes.
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
