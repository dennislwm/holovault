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

/// ADR-04, mechanism A1: a mobile-width list of collection items, reactive
/// to the underlying drift table via [AppDatabase.watchAllItems].
class CollectionListScreen extends StatelessWidget {
  const CollectionListScreen({
    super.key,
    required this.database,
    this.pickFile = pickImportFile,
  });

  final AppDatabase database;
  final Future<String?> Function() pickFile;

  Future<void> _handleImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await pickFile();
    messenger.showSnackBar(
      SnackBar(content: Text(path == null ? 'Import cancelled' : 'Selected: $path')),
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
