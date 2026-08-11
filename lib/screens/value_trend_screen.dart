import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;

const _filterSetKey = 'value_trend_filter_set';
const _filterRarityKey = 'value_trend_filter_rarity';

/// ADR-12, Option 2: a cumulative value-trend chart over `watchAllItems()`,
/// filterable by set/rarity, with the last-used filter persisted via
/// shared_preferences so it survives app restart (REQ-015).
class ValueTrendScreen extends StatefulWidget {
  const ValueTrendScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ValueTrendScreen> createState() => _ValueTrendScreenState();
}

class _ValueTrendScreenState extends State<ValueTrendScreen> {
  String? _filterSet;
  String? _filterRarity;
  bool _loadedPersistedFilter = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedFilter();
  }

  Future<void> _loadPersistedFilter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filterSet = prefs.getString(_filterSetKey);
      _filterRarity = prefs.getString(_filterRarityKey);
      _loadedPersistedFilter = true;
    });
  }

  Future<void> _saveFilter() async {
    final prefs = await SharedPreferences.getInstance();
    if (_filterSet == null) {
      await prefs.remove(_filterSetKey);
    } else {
      await prefs.setString(_filterSetKey, _filterSet!);
    }
    if (_filterRarity == null) {
      await prefs.remove(_filterRarityKey);
    } else {
      await prefs.setString(_filterRarityKey, _filterRarity!);
    }
  }

  List<CollectionItem> _applyFilter(List<CollectionItem> items) {
    return items.where((item) {
      if (_filterSet != null && item.setName != _filterSet) return false;
      if (_filterRarity != null && item.rarity != _filterRarity) return false;
      return true;
    }).toList();
  }

  Future<void> _pickFilter(List<CollectionItem> allItems) async {
    final setNames = allItems.map((i) => i.setName).whereType<String>().toSet().toList()..sort();
    final rarities = allItems.map((i) => i.rarity).whereType<String>().toSet().toList()..sort();

    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add filter'),
        children: [
          if (setNames.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Set'),
            ),
            for (final s in setNames)
              SimpleDialogOption(
                onPressed: () {
                  setState(() => _filterSet = s);
                  Navigator.of(context).pop();
                },
                child: Text(s),
              ),
          ],
          if (rarities.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Rarity'),
            ),
            for (final r in rarities)
              SimpleDialogOption(
                onPressed: () {
                  setState(() => _filterRarity = r);
                  Navigator.of(context).pop();
                },
                child: Text(r),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection Value')),
      body: StreamBuilder<List<CollectionItem>>(
        stream: widget.database.watchAllItems(),
        builder: (context, snapshot) {
          // REQ-018 (ADR-07): this screen holds its own independent
          // watchAllItems() stream -- an unrecognized schema version must
          // surface here too, not only on CollectionListScreen.
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
          if (!_loadedPersistedFilter) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data ?? const [];
          final filtered = _applyFilter(allItems);

          // REQ-015: cumulative running total over time, sorted by
          // dateAdded, matching ADR-12's "value trend over time" framing --
          // not a per-item scatter of individual values.
          final withDates = filtered
              .where((i) => i.dateAdded != null && i.valueTotal != null)
              .toList()
            ..sort((a, b) => a.dateAdded!.compareTo(b.dateAdded!));

          double running = 0;
          final spots = <FlSpot>[
            for (var i = 0; i < withDates.length; i++)
              FlSpot(i.toDouble(), running += withDates[i].valueTotal!),
          ];
          final total = spots.isEmpty ? 0.0 : spots.last.y;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (_filterSet != null)
                      Chip(
                        label: Text('Set: $_filterSet'),
                        onDeleted: () {
                          setState(() => _filterSet = null);
                        },
                      ),
                    if (_filterRarity != null)
                      Chip(
                        label: Text('Rarity: $_filterRarity'),
                        onDeleted: () {
                          setState(() => _filterRarity = null);
                        },
                      ),
                    ActionChip(
                      label: const Text('+ Add filter'),
                      onPressed: () => _pickFilter(allItems),
                    ),
                  ],
                ),
                if (_filterSet != null || _filterRarity != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saveFilter,
                      child: const Text('Save this filter'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  total.toString(),
                  key: const Key('value-trend-total'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: spots.isEmpty
                      ? const Center(child: Text('No value data yet'))
                      : LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(spots: spots, isCurved: true),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Matching items · ${filtered.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                for (final item in filtered)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name),
                              Text(
                                [
                                  item.setName,
                                  item.rarity,
                                ].whereType<String>().join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(item.valueTotal?.toString() ?? '--'),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
