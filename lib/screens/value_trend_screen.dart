import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;

const _filterSetKey = 'value_trend_filter_set';
const _filterRarityKey = 'value_trend_filter_rarity';
const _filterGradeTypeKey = 'value_trend_filter_grade_type';
const _filterExcludeSealedKey = 'value_trend_filter_exclude_sealed';

/// ADR-12, Option 2: a cumulative value-trend chart over `watchAllItems()`,
/// filterable by set/rarity/grade type, with an independent "exclude sealed"
/// toggle (REQ-022), and the last-used filter persisted via
/// shared_preferences so it survives app restart (REQ-015). Picker is a
/// native `DropdownButton` per field, not the original dialog+chip picker --
/// see Conventions.md.
class ValueTrendScreen extends StatefulWidget {
  const ValueTrendScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ValueTrendScreen> createState() => _ValueTrendScreenState();
}

class _ValueTrendScreenState extends State<ValueTrendScreen> {
  String? _filterSet;
  String? _filterRarity;
  String? _filterGradeType;
  bool _filterExcludeSealed = false;
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
      _filterGradeType = prefs.getString(_filterGradeTypeKey);
      _filterExcludeSealed = prefs.getBool(_filterExcludeSealedKey) ?? false;
      _loadedPersistedFilter = true;
    });
  }

  Future<void> _saveFilter() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in {
      _filterSetKey: _filterSet,
      _filterRarityKey: _filterRarity,
      _filterGradeTypeKey: _filterGradeType,
    }.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value!);
      }
    }
    await prefs.setBool(_filterExcludeSealedKey, _filterExcludeSealed);
  }

  List<CollectionItem> _applyFilter(
    List<CollectionItem> items, {
    required String? filterSet,
    required String? filterRarity,
    required String? filterGradeType,
    required bool filterExcludeSealed,
  }) {
    return items.where((item) {
      if (filterSet != null && item.setName != filterSet) return false;
      if (filterRarity != null && item.rarity != filterRarity) return false;
      if (filterGradeType != null && item.gradeType != filterGradeType) {
        return false;
      }
      if (filterExcludeSealed && item.rarity == 'Sealed') return false;
      return true;
    }).toList();
  }

  Widget _filterDropdown({
    required String label,
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButton<String?>(
      hint: Text(label),
      value: selected,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('$label: All')),
        for (final v in values) DropdownMenuItem<String?>(value: v, child: Text(v)),
      ],
      onChanged: (v) {
        onChanged(v);
        _saveFilter();
      },
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
          final setNames = allItems.map((i) => i.setName).whereType<String>().toSet().toList()..sort();
          final rarities = allItems.map((i) => i.rarity).whereType<String>().toSet().toList()..sort();
          final gradeTypes = allItems.map((i) => i.gradeType).whereType<String>().toSet().toList()..sort();

          // A persisted filter value may no longer exist among current items
          // (the matching item was deleted/edited since the filter was
          // saved) -- fall back to "All" rather than passing DropdownButton
          // a value absent from its own items list, which throws.
          final effectiveFilterSet = setNames.contains(_filterSet) ? _filterSet : null;
          final effectiveFilterRarity = rarities.contains(_filterRarity) ? _filterRarity : null;
          final effectiveFilterGradeType = gradeTypes.contains(_filterGradeType) ? _filterGradeType : null;
          final filtered = _applyFilter(
            allItems,
            filterSet: effectiveFilterSet,
            filterRarity: effectiveFilterRarity,
            filterGradeType: effectiveFilterGradeType,
            filterExcludeSealed: _filterExcludeSealed,
          );

          // REQ-015: cumulative running total over time, sorted by
          // dateAdded, matching ADR-12's "value trend over time" framing --
          // not a per-item scatter of individual values. A missing
          // valueTotal/paidTotal on an otherwise-dated item contributes 0,
          // so both lines share the same x-axis (item order by dateAdded).
          final withDates = filtered.where((i) => i.dateAdded != null).toList()
            ..sort((a, b) => a.dateAdded!.compareTo(b.dateAdded!));

          double runningValue = 0;
          double runningPaid = 0;
          final valueSpots = <FlSpot>[];
          final paidSpots = <FlSpot>[];
          for (var i = 0; i < withDates.length; i++) {
            runningValue += withDates[i].valueTotal ?? 0;
            runningPaid += withDates[i].paidTotal ?? 0;
            valueSpots.add(FlSpot(i.toDouble(), runningValue));
            paidSpots.add(FlSpot(i.toDouble(), runningPaid));
          }
          final total = valueSpots.isEmpty ? 0.0 : valueSpots.last.y;
          final totalPaid = paidSpots.isEmpty ? 0.0 : paidSpots.last.y;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _filterDropdown(
                      label: 'Set',
                      values: setNames,
                      selected: effectiveFilterSet,
                      onChanged: (v) => setState(() => _filterSet = v),
                    ),
                    _filterDropdown(
                      label: 'Rarity',
                      values: rarities,
                      selected: effectiveFilterRarity,
                      onChanged: (v) => setState(() => _filterRarity = v),
                    ),
                    _filterDropdown(
                      label: 'Grade type',
                      values: gradeTypes,
                      selected: effectiveFilterGradeType,
                      onChanged: (v) => setState(() => _filterGradeType = v),
                    ),
                    FilterChip(
                      label: const Text('Exclude sealed'),
                      selected: _filterExcludeSealed,
                      onSelected: (v) {
                        setState(() => _filterExcludeSealed = v);
                        _saveFilter();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  total.toStringAsFixed(2),
                  key: const Key('value-trend-total'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Paid: ${totalPaid.toStringAsFixed(2)}',
                  key: const Key('value-trend-paid-total'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: valueSpots.isEmpty
                      ? const Center(child: Text('No value data yet'))
                      : LineChart(
                          LineChartData(
                            lineBarsData: [
                              LineChartBarData(spots: valueSpots, isCurved: true),
                              LineChartBarData(
                                spots: paidSpots,
                                isCurved: true,
                                color: Colors.orange,
                                dashArray: [6, 4],
                              ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(item.valueTotal?.toStringAsFixed(2) ?? '--'),
                            Text(
                              'Paid: ${item.paidTotal?.toStringAsFixed(2) ?? '--'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
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
