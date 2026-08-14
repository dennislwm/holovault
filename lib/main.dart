import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'database/database.dart';
import 'screens/best_returns_screen.dart';
import 'screens/collection_list_screen.dart';
import 'screens/value_trend_screen.dart';

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
      // ADR-21, Option 2: flex_color_scheme's ebonyClay scheme -- a visual
      // match for the app's navy-blue-dominant logo with teal/green accents.
      theme: FlexThemeData.light(scheme: FlexScheme.ebonyClay),
      darkTheme: FlexThemeData.dark(scheme: FlexScheme.ebonyClay),
      themeMode: ThemeMode.system,
      home: HolovaultShell(database: database),
    );
  }
}

/// ADR-15, Option 1: a persistent 2-tab shell -- both tabs stay mounted in
/// [IndexedStack] so switching tabs preserves each screen's in-memory state
/// (e.g. ValueTrendScreen's filters/chart), unlike the AppBar-icon push/pop
/// it replaces. Uses the app's single root Navigator, same as before -- a
/// push from within a tab (e.g. CollectionListScreen's ItemDetailScreen
/// push, ADR-04) still covers the whole screen, tab bar included.
class HolovaultShell extends StatefulWidget {
  const HolovaultShell({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HolovaultShell> createState() => _HolovaultShellState();
}

class _HolovaultShellState extends State<HolovaultShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          CollectionListScreen(database: widget.database),
          ValueTrendScreen(database: widget.database),
          BestReturnsScreen(database: widget.database),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark),
            label: 'Collection',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Value trend',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Best Returns',
          ),
        ],
      ),
    );
  }
}
