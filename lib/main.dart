import 'package:flutter/material.dart';

import 'database/database.dart';
import 'screens/collection_list_screen.dart';

void main() {
  runApp(HolovaultApp());
}

class HolovaultApp extends StatelessWidget {
  HolovaultApp({super.key, AppDatabase? database})
      : database = database ?? AppDatabase();

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'holovault',
      home: CollectionListScreen(database: database),
    );
  }
}
