import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    valueTotal: Value(valueTotal == null ? null : double.parse(valueTotal)),
    valuePerUnit: Value(
      valuePerUnit == null ? null : double.parse(valuePerUnit),
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
    final rows = await parseFile(path);
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
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No items yet'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: item.extra == null ? null : Text(item.extra!),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
                      database: database,
                      items: items,
                      initialIndex: index,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
