import 'package:flutter/material.dart';

import '../database/database.dart';
import 'item_detail_screen.dart';

/// ADR-04, mechanism A1: a mobile-width list of collection items, reactive
/// to the underlying drift table via [AppDatabase.watchAllItems].
class CollectionListScreen extends StatelessWidget {
  const CollectionListScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection')),
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
