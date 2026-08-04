import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';
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
    for (final row in rows) {
      await database.upsertItem(
        importedId: row['importedId'] ?? '',
        name: row['name'] ?? '',
        extra: row['extra'],
      );
    }
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
