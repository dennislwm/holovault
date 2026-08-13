import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../collection_search.dart';
import '../database/database.dart';
import '../import_schema.dart';
import 'item_detail_screen.dart';

/// ADR-06, Option A: acquires a file path via the native document picker.
/// Scope note (ADR-06): acquisition only -- parsing the picked file into
/// rows is separate, undecided work.
Future<String?> pickImportFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'json'],
  );
  return result?.files.single.path;
}

/// ADR-08, Option 2: parses a picked CSV/JSON file into row maps keyed by
/// [CollectionItems]' own column names (`importedId`/`name`/`extra`), on
/// the main isolate. CSV parsing goes through the `csv` package so quoted
/// commas, embedded newlines, and a UTF-8 BOM don't silently mis-parse.
Future<List<Map<String, String?>>> parseImportFile(String path) async {
  final contents = await File(path).readAsString();
  if (path.toLowerCase().endsWith('.json')) {
    final rows = jsonDecode(contents) as List<dynamic>;
    return rows
        .map(
          (row) => (row as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, value?.toString()),
          ),
        )
        .toList();
  }
  final rows = csv.decode(contents);
  if (rows.isEmpty) return [];
  final header = rows.first.map((cell) => cell.toString()).toList();
  return rows.skip(1).map((row) {
    return {
      for (var i = 0; i < header.length; i++) header[i]: row[i]?.toString(),
    };
  }).toList();
}

/// ADR-09: converts a literal CSV `"null"` string to a real `null`. Only
/// CSV needs this -- JSON's real `null` already survives `parseImportFile`
/// unchanged (`value?.toString()` short-circuits on a null receiver).
String? _nullableField(Map<String, String?> row, String key) {
  final value = row[key];
  return value == 'null' ? null : value;
}

/// ADR-09: coerces a parsed row's already-stringified values into
/// [CollectionItems]' typed columns. One shared step for both CSV and
/// JSON, since `parseImportFile` stringifies both before this runs.
CollectionItemsCompanion _rowToCompanion(Map<String, String?> row) {
  final quantity = row['quantity'];
  final valueTotal = row['value_total'];
  final valuePerUnit = row['value_per_unit'];
  final paidTotal = row['paid_total'];
  final paidPerUnit = row['paid_per_unit'];
  final groupWishlist = row['group_wishlist'];
  final dateAdded = row['date_added'];
  return CollectionItemsCompanion.insert(
    importedId: row['id'] ?? '',
    name: row['product_name'] ?? '',
    extra: Value(row['extra']),
    setName: Value(row['set_name']),
    brandName: Value(row['brand_name']),
    discriminator: Value(row['discriminator']),
    rarity: Value(row['rarity']),
    quantity: Value(quantity == null ? null : int.parse(quantity)),
    valueTotal: Value(
      valueTotal == null || valueTotal == 'Unavailable'
          ? null
          : double.parse(valueTotal),
    ),
    valuePerUnit: Value(
      valuePerUnit == null || valuePerUnit == 'Unavailable'
          ? null
          : double.parse(valuePerUnit),
    ),
    valueCurrency: Value(row['value_currency']),
    paidTotal: Value(paidTotal == null ? null : double.parse(paidTotal)),
    paidPerUnit: Value(paidPerUnit == null ? null : double.parse(paidPerUnit)),
    paidCurrency: Value(row['paid_currency']),
    gradeType: Value(row['grade_type']),
    gradeSubtype: Value(row['grade_subtype']),
    groupName: Value(row['group_name']),
    groupWishlist: Value(
      groupWishlist == null ? null : bool.parse(groupWishlist),
    ),
    tcgplayerId: Value(_nullableField(row, 'tcgplayer_id')),
    pricechartingId: Value(_nullableField(row, 'pricecharting_id')),
    doubleholoId: Value(_nullableField(row, 'doubleholo_id')),
    dateAdded: Value(dateAdded == null ? null : DateTime.parse(dateAdded)),
    tag: Value(row['tag']),
  );
}

/// REQ-018 (ADR-07): the message shown when [CollectionListScreen]'s
/// [StreamBuilder] errors -- a named message for the one error type this
/// app can currently produce (an unrecognized on-disk schema version),
/// a generic fallback for anything else.
String schemaErrorMessage(Object? error) {
  return error is UnsupportedSchemaVersionException
      ? "This collection database is from an unrecognized app version and "
            "can't be opened."
      : 'Something went wrong loading your collection.';
}

/// ADR-17, Option 1: category totals for the Collection Distribution card.
/// Derivation confirmed against real data (see ADR-17 Decision Drivers):
/// `rarity == 'Sealed'` -> Sealed; else `gradeType == 'Ungraded'` ->
/// Ungraded; else -> Graded. Sums `valueTotal`, treating a null total as 0.
Map<String, double> collectionDistribution(List<CollectionItem> items) {
  final totals = {'Sealed': 0.0, 'Graded': 0.0, 'Ungraded': 0.0};
  for (final item in items) {
    final category = item.rarity == 'Sealed'
        ? 'Sealed'
        : item.gradeType == 'Ungraded'
        ? 'Ungraded'
        : 'Graded';
    totals[category] = totals[category]! + (item.valueTotal ?? 0);
  }
  return totals;
}

/// ADR-17, Option 1: stacked rows, each a category label + $ amount + %
/// inline with a native [LinearProgressIndicator] underneath.
class CollectionDistributionCard extends StatelessWidget {
  const CollectionDistributionCard({super.key, required this.items});

  final List<CollectionItem> items;

  @override
  Widget build(BuildContext context) {
    final totals = collectionDistribution(items);
    final grandTotal = totals.values.fold(0.0, (sum, v) => sum + v);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COLLECTION DISTRIBUTION',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            for (final category in ['Sealed', 'Graded', 'Ungraded'])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          grandTotal == 0
                              ? '\$${totals[category]!.toStringAsFixed(2)} · 0%'
                              : '\$${totals[category]!.toStringAsFixed(2)} · '
                                    '${(totals[category]! / grandTotal * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: grandTotal == 0 ? 0 : totals[category]! / grandTotal,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ADR-04, mechanism A1: a mobile-width list of collection items, reactive
/// to the underlying drift table via [AppDatabase.watchAllItems].
class CollectionListScreen extends StatelessWidget {
  const CollectionListScreen({
    super.key,
    required this.database,
    this.pickFile = pickImportFile,
    this.parseFile = parseImportFile,
  });

  final AppDatabase database;
  final Future<String?> Function() pickFile;
  final Future<List<Map<String, String?>>> Function(String path) parseFile;

  Future<void> _handleImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await pickFile();
    if (path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Import cancelled')));
      return;
    }
    // REQ-010: a malformed CSV/JSON file makes parseFile() throw -- surface
    // it as a SnackBar like every other refusal path, not an uncaught crash.
    final List<Map<String, String?>> rows;
    try {
      rows = await parseFile(path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
      return;
    }
    // REQ-009: an empty parse would make deleteMissingImportedIds() match
    // every row (NOT IN () is vacuously true) and wipe the collection.
    if (rows.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Import found no rows')));
      return;
    }
    // REQ-011: refuse the whole import on the first row that would crash
    // _rowToCompanion()'s coercion, instead of throwing uncaught mid-write.
    for (var i = 0; i < rows.length; i++) {
      final errors = validateRow(rows[i]);
      if (errors.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('Import refused: row ${i + 1} ${errors.first}')),
        );
        return;
      }
    }
    // REQ-007: atomic -- an app backgrounded/killed mid-import leaves no
    // partially-applied state; either every row lands or none does.
    await database.transaction(() async {
      for (final row in rows) {
        await database.upsertItem(_rowToCompanion(row));
      }
      // REQ-008: a re-import is a full-inventory snapshot -- any row not
      // in this import no longer exists in the source and is removed.
      await database.deleteMissingImportedIds(
        rows.map((row) => row['id'] ?? '').toList(),
      );
    });
    messenger.showSnackBar(
      SnackBar(content: Text('Imported ${rows.length} item(s)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import',
            onPressed: () => _handleImport(context),
          ),
        ],
      ),
      body: StreamBuilder<List<CollectionItem>>(
        stream: database.watchAllItems(),
        builder: (context, snapshot) {
          // REQ-018 (ADR-07): an unrecognized on-disk schema version makes
          // the underlying stream error with UnsupportedSchemaVersionException
          // instead of emitting data -- surface it clearly instead of
          // silently falling through to the empty-state message below.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      schemaErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No items yet'));
          }
          return _FilterableCollectionList(database: database, items: items);
        },
      ),
    );
  }
}

/// ADR-18, Option 2: below [CollectionDistributionCard] (unaffected by
/// filtering -- it always summarizes the whole collection), a free-text
/// search input plus an addable/removable structured clause builder,
/// narrowing the item list below. Search and clauses narrow together
/// (AND) via [filterCollectionItems].
class _FilterableCollectionList extends StatefulWidget {
  const _FilterableCollectionList({required this.database, required this.items});

  final AppDatabase database;
  final List<CollectionItem> items;

  @override
  State<_FilterableCollectionList> createState() => _FilterableCollectionListState();
}

class _FilterableCollectionListState extends State<_FilterableCollectionList> {
  String _searchTerm = '';
  final List<SearchClause> _clauses = [];
  List<CollectionItem> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(covariant _FilterableCollectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) _recompute();
  }

  Future<void> _recompute() async {
    final result = await filterCollectionItems(
      widget.items,
      searchTerm: _searchTerm,
      clauses: _clauses,
    );
    if (mounted) setState(() => _filtered = result);
  }

  void _addClause(SearchClause clause) {
    setState(() => _clauses.add(clause));
    _recompute();
  }

  void _removeClause(int index) {
    setState(() => _clauses.removeAt(index));
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _filtered.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          return CollectionDistributionCard(items: widget.items);
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchTerm = value;
                _recompute();
              },
            ),
          );
        }
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _clauses.length; i++)
                  InputChip(
                    label: Text(
                      '${_clauses[i].field.label} ${_clauses[i].op.symbol} ${_clauses[i].value}',
                    ),
                    onDeleted: () => _removeClause(i),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add clause'),
                  onPressed: () => _showAddClauseSheet(context, _filtered, _addClause),
                ),
              ],
            ),
          );
        }
        final item = _filtered[index - 3];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
              ),
            ),
            title: Text(item.name),
            subtitle: item.extra == null ? null : Text(item.extra!),
            trailing: item.quantity == null
                ? null
                : Chip(label: Text('×${item.quantity}')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ItemDetailScreen(
                  database: widget.database,
                  items: _filtered,
                  initialIndex: index - 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ADR-18, Option 2: sequential picker -- field, then an operator
/// dropdown scoped to that field's type, then the value last (a number
/// field for numeric/date fields, a dropdown of real distinct values,
/// narrowed by [narrowed], for text fields).
void _showAddClauseSheet(
  BuildContext context,
  List<CollectionItem> narrowed,
  void Function(SearchClause) onAdd,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      SearchField? field;
      SearchOperator? op;
      final valueController = TextEditingController();
      String? textValue;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add clause', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<SearchField>(
                  initialValue: field,
                  decoration: const InputDecoration(labelText: 'Field'),
                  items: [
                    for (final f in SearchField.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (value) => setSheetState(() {
                    field = value;
                    op = null;
                    textValue = null;
                    valueController.clear();
                  }),
                ),
                if (field != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SearchOperator>(
                    initialValue: op,
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: [
                      for (final o in operatorsFor(field!))
                        DropdownMenuItem(value: o, child: Text(o.symbol)),
                    ],
                    onChanged: (value) => setSheetState(() => op = value),
                  ),
                ],
                if (field != null && op != null) ...[
                  const SizedBox(height: 12),
                  if (field!.isText)
                    DropdownButtonFormField<String>(
                      initialValue: textValue,
                      decoration: const InputDecoration(labelText: 'Value'),
                      items: [
                        for (final v in distinctValuesFor(field!, narrowed))
                          DropdownMenuItem(value: v, child: Text(v)),
                      ],
                      onChanged: (value) => setSheetState(() => textValue = value),
                    )
                  else
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Value'),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: field == null || op == null
                      || (field!.isText ? textValue == null : valueController.text.isEmpty)
                      ? null
                      : () {
                          onAdd(
                            SearchClause(
                              field: field!,
                              op: op!,
                              value: field!.isText ? textValue! : valueController.text,
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
