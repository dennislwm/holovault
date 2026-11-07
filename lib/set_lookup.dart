// REQ-052 (ADR-24 Option 3): the set lookup in memory, and the derived
// columns that read it. Derived columns are read-only: they live in their own
// list, so every storage site (migration, save, export and import,
// overrideRows, storedValues, the detail form) keeps using [customColumns] and
// never sees them.
import 'package:flutter/foundation.dart';

import 'database/database.dart';
import 'database/overrides_schema.dart';

/// The stored set lookup keyed by alias name; empty until [refreshSetLookup].
Map<String, SetLookupRow> setLookup = {};

/// Bumped by every [refreshSetLookup]; the collection screen listens so its
/// rows pick up a changed lookup (the row stream does not watch this table).
final setLookupVersion = ValueNotifier<int>(0);

/// Reloads [setLookup] from the database. Call at startup and after an import.
Future<void> refreshSetLookup(AppDatabase db) async {
  final rows = await db.allSetLookupRows();
  setLookup = {for (final r in rows) r.aliasName: r};
  setLookupVersion.value++;
}

CustomColumn _derived(String name, String? Function(SetLookupRow) pick) =>
    CustomColumn(
      name,
      CustomColumnType.text,
      (r) {
        final set = r.setName;
        final row = set == null ? null : setLookup[set];
        return row == null ? null : pick(row);
      },
      // ponytail: a derived column has no overrides-table column; nothing on
      // the storage side is ever given this entry, so this is never called.
      (_) => throw UnsupportedError('derived column $name has no overrides column'),
    );

/// Fields the lookup adds to every row: blank where the row's set name has no
/// exact alias in the lookup.
final derivedColumns = <CustomColumn>[
  _derived('language', (r) => r.language),
  _derived('setId', (r) => r.tcgdexId),
  _derived('setOfficialName', (r) => r.officialName),
];

/// What the list shows, sorts and filters by: stored custom columns first,
/// then the derived ones.
List<CustomColumn> get readColumns => [...customColumns, ...derivedColumns];
