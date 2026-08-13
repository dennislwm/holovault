import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../annualized_return.dart';
import '../database/database.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;

const _filterSetKey = 'best_returns_filter_set';
const _filterRarityKey = 'best_returns_filter_rarity';
const _filterGradeTypeKey = 'best_returns_filter_grade_type';
const _filterExcludeSealedKey = 'best_returns_filter_exclude_sealed';
const _minPaidKey = 'best_returns_min_paid';
const _maxValueKey = 'best_returns_max_value';
const _minDaysKey = 'best_returns_min_days';
const _limitKey = 'best_returns_limit';

const _defaultMinPaid = 0.0;
const _defaultMaxValue = 100000.0;
const _defaultMinDays = 90;
const _defaultLimit = 5;

// ponytail: duplicates ValueTrendScreen's _filterDropdown (ADR-12/REQ-024)
// rather than extracting a shared widget -- ValueTrendScreen is an
// already-Accepted, tested screen, and REQ-028 didn't ask for a refactor
// of it. Extract to a shared widget if a third screen ever needs this.
Widget _filterDropdown({
  required String label,
  required List<String> values,
  required String? selected,
  required ValueChanged<String?> onChanged,
}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 130),
    child: DropdownButton<String?>(
      isExpanded: true,
      hint: Text(label),
      value: selected,
      selectedItemBuilder: (context) => [
        Text('$label: All', overflow: TextOverflow.ellipsis),
        for (final v in values) Text('$label: $v', overflow: TextOverflow.ellipsis),
      ],
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('$label: All')),
        for (final v in values) DropdownMenuItem<String?>(value: v, child: Text(v)),
      ],
      onChanged: onChanged,
    ),
  );
}

/// ADR-16, Option 1: ranks collection items by annualized return (CAGR)
/// in a sortable DataTable whose "Return" column combines a
/// proportional-width bar with its percent text in one DataCell --
/// DataCell.child is a plain Widget, so bar-length ranking and every
/// number (paid/value/days/return) render inline, no separate list.
/// Reuses ValueTrendScreen's filter UI (Set/Rarity/Grade type/Exclude
/// sealed) and its shared_preferences persistence pattern (ADR-12),
/// extended to the four pyholofoil bind params (min paid, max value,
/// min days, limit).
class BestReturnsScreen extends StatefulWidget {
  const BestReturnsScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<BestReturnsScreen> createState() => _BestReturnsScreenState();
}

class _BestReturnsScreenState extends State<BestReturnsScreen> {
  String? _filterSet;
  String? _filterRarity;
  String? _filterGradeType;
  bool _filterExcludeSealed = false;
  double _minPaid = _defaultMinPaid;
  double _maxValue = _defaultMaxValue;
  int _minDays = _defaultMinDays;
  int _limit = _defaultLimit;
  bool _loadedPersisted = false;
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  late final TextEditingController _minPaidController;
  late final TextEditingController _maxValueController;

  @override
  void initState() {
    super.initState();
    _minPaidController = TextEditingController();
    _maxValueController = TextEditingController();
    _loadPersisted();
  }

  @override
  void dispose() {
    _minPaidController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filterSet = prefs.getString(_filterSetKey);
      _filterRarity = prefs.getString(_filterRarityKey);
      _filterGradeType = prefs.getString(_filterGradeTypeKey);
      _filterExcludeSealed = prefs.getBool(_filterExcludeSealedKey) ?? false;
      _minPaid = prefs.getDouble(_minPaidKey) ?? _defaultMinPaid;
      _maxValue = prefs.getDouble(_maxValueKey) ?? _defaultMaxValue;
      _minDays = prefs.getInt(_minDaysKey) ?? _defaultMinDays;
      _limit = prefs.getInt(_limitKey) ?? _defaultLimit;
      _minPaidController.text = _minPaid.toStringAsFixed(2);
      _maxValueController.text = _maxValue.toStringAsFixed(2);
      _loadedPersisted = true;
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

  Future<void> _saveParams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_minPaidKey, _minPaid);
    await prefs.setDouble(_maxValueKey, _maxValue);
    await prefs.setInt(_minDaysKey, _minDays);
    await prefs.setInt(_limitKey, _limit);
  }

  List<CollectionItem> _applyFilter(List<CollectionItem> items) {
    return items.where((item) {
      if (_filterSet != null && item.setName != _filterSet) return false;
      if (_filterRarity != null && item.rarity != _filterRarity) return false;
      if (_filterGradeType != null && item.gradeType != _filterGradeType) {
        return false;
      }
      if (_filterExcludeSealed && item.rarity == 'Sealed') return false;
      return true;
    }).toList();
  }

  void _sortBy(int columnIndex) {
    setState(() {
      _sortAscending = columnIndex == _sortColumnIndex ? !_sortAscending : true;
      _sortColumnIndex = columnIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Best Returns')),
      body: StreamBuilder<List<CollectionItem>>(
        stream: widget.database.watchAllItems(),
        builder: (context, snapshot) {
          // REQ-018 (ADR-07): this screen holds its own independent
          // watchAllItems() stream -- an unrecognized schema version must
          // surface here too, not only on the other two tabs.
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
          if (!_loadedPersisted) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snapshot.data ?? const [];
          final setNames = allItems.map((i) => i.setName).whereType<String>().toSet().toList()..sort();
          final rarities = allItems.map((i) => i.rarity).whereType<String>().toSet().toList()..sort();
          final gradeTypes = allItems.map((i) => i.gradeType).whereType<String>().toSet().toList()..sort();

          // A persisted filter value may no longer exist among current
          // items -- fall back to "All" rather than passing DropdownButton
          // a value absent from its own items list, which throws.
          final effectiveFilterSet = setNames.contains(_filterSet) ? _filterSet : null;
          final effectiveFilterRarity = rarities.contains(_filterRarity) ? _filterRarity : null;
          final effectiveFilterGradeType = gradeTypes.contains(_filterGradeType) ? _filterGradeType : null;
          _filterSet = effectiveFilterSet;
          _filterRarity = effectiveFilterRarity;
          _filterGradeType = effectiveFilterGradeType;

          final filtered = _applyFilter(allItems);
          final ranked = computeAnnualizedReturns(
            filtered,
            minPaid: _minPaid,
            maxValue: _maxValue,
            minDays: _minDays,
            limit: _limit,
          );
          // Re-apply the user's chosen sort (default: Return descending,
          // matching computeAnnualizedReturns' own default order) on top
          // of the already-filtered/limited ranked list.
          int compare(AnnualizedReturn a, AnnualizedReturn b) {
            switch (_sortColumnIndex) {
              case 0:
                return a.item.name.compareTo(b.item.name);
              case 2:
                return (a.item.paidPerUnit ?? 0).compareTo(b.item.paidPerUnit ?? 0);
              case 3:
                return (a.item.valuePerUnit ?? 0).compareTo(b.item.valuePerUnit ?? 0);
              case 4:
                return a.daysHeld.compareTo(b.daysHeld);
              case 1:
              default:
                return a.percent.compareTo(b.percent);
            }
          }

          ranked.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
          final maxPercent = ranked.isEmpty
              ? 1.0
              : ranked.map((r) => r.percent.abs()).reduce((a, b) => a > b ? a : b);

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
                    onChanged: (v) {
                      setState(() => _filterSet = v);
                      _saveFilter();
                    },
                  ),
                  _filterDropdown(
                    label: 'Rarity',
                    values: rarities,
                    selected: effectiveFilterRarity,
                    onChanged: (v) {
                      setState(() => _filterRarity = v);
                      _saveFilter();
                    },
                  ),
                  _filterDropdown(
                    label: 'Grade type',
                    values: gradeTypes,
                    selected: effectiveFilterGradeType,
                    onChanged: (v) {
                      setState(() => _filterGradeType = v);
                      _saveFilter();
                    },
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
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      key: const Key('best-returns-min-paid'),
                      controller: _minPaidController,
                      decoration: const InputDecoration(labelText: 'Min paid'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      // Recomputes on submit/blur, not onChanged -- onChanged
                      // fires per keystroke, so typing "180" would recompute
                      // against "1" and "18" first (ADR-16 Decision Drivers).
                      onSubmitted: (v) {
                        setState(() => _minPaid = double.tryParse(v) ?? _defaultMinPaid);
                        _saveParams();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      key: const Key('best-returns-max-value'),
                      controller: _maxValueController,
                      decoration: const InputDecoration(labelText: 'Max value'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onSubmitted: (v) {
                        setState(() => _maxValue = double.tryParse(v) ?? _defaultMaxValue);
                        _saveParams();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Min days: $_minDays', style: Theme.of(context).textTheme.bodySmall),
                        Slider(
                          key: const Key('best-returns-min-days'),
                          value: _minDays.toDouble(),
                          min: 0,
                          max: 365,
                          divisions: 73,
                          label: '$_minDays',
                          // onChangeEnd (not onChanged) -- avoids recomputing
                          // on every pixel of drag (ADR-16 Decision Drivers).
                          onChanged: (v) => setState(() => _minDays = v.round()),
                          onChangeEnd: (v) {
                            setState(() => _minDays = v.round());
                            _saveParams();
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Limit', style: Theme.of(context).textTheme.bodySmall),
                      IconButton(
                        key: const Key('best-returns-limit-minus'),
                        icon: const Icon(Icons.remove_circle_outline),
                        // Each tap is already one discrete step -- onChanged
                        // directly, no debouncing needed (ADR-16 Decision
                        // Drivers).
                        onPressed: _limit <= 1
                            ? null
                            : () {
                                setState(() => _limit -= 1);
                                _saveParams();
                              },
                      ),
                      Text('$_limit'),
                      IconButton(
                        key: const Key('best-returns-limit-plus'),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() => _limit += 1);
                          _saveParams();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ranked · ${ranked.length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              if (ranked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No items match these filters/params')),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columns: [
                      DataColumn(
                        label: const Text('Item'),
                        onSort: (i, _) => _sortBy(i),
                      ),
                      DataColumn(
                        label: const Text('Return'),
                        numeric: true,
                        onSort: (i, _) => _sortBy(i),
                      ),
                      DataColumn(
                        label: const Text('Paid'),
                        numeric: true,
                        onSort: (i, _) => _sortBy(i),
                      ),
                      DataColumn(
                        label: const Text('Value'),
                        numeric: true,
                        onSort: (i, _) => _sortBy(i),
                      ),
                      DataColumn(
                        label: const Text('Days'),
                        numeric: true,
                        onSort: (i, _) => _sortBy(i),
                      ),
                    ],
                    rows: [
                      for (final r in ranked)
                        DataRow(
                          cells: [
                            DataCell(Text(r.item.name)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    key: const Key('best-returns-bar'),
                                    width: 32,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: maxPercent == 0
                                          ? 0
                                          : (r.percent.abs() / maxPercent).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${r.percent.toStringAsFixed(2)}%'),
                                ],
                              ),
                            ),
                            DataCell(Text(r.item.paidPerUnit?.toStringAsFixed(2) ?? '--')),
                            DataCell(Text(r.item.valuePerUnit?.toStringAsFixed(2) ?? '--')),
                            DataCell(Text('${r.daysHeld}')),
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
