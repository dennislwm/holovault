import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../annualized_return.dart';
import '../database/database.dart';
import '../widgets/search_filter_bar.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;
import 'item_detail_screen.dart';

const _limitKey = 'best_returns_limit';

const _defaultLimit = 5;

/// ADR-16 (superseded by ADR-19), ADR-19 Option 1: ranks collection items by
/// annualized return (CAGR) in a sortable DataTable whose "Return" column
/// combines a proportional-width bar with its percent text in one DataCell.
/// Filtering is the shared [SearchFilterBar] (search term + clause
/// builder), same as [ValueTrendScreen]/[CollectionListScreen]; `limit`
/// stays this screen's own post-rank `Stepper`, out of ADR-19's scope
/// (truncation, not a filter criterion). REQ-035: `min_paid`/`max_value`/
/// `min_days` (ADR-16) are gone -- the clause builder's `paidPerUnit`/
/// `valuePerUnit`/`daysHeld` fields fully subsume them.
class BestReturnsScreen extends StatefulWidget {
  const BestReturnsScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<BestReturnsScreen> createState() => _BestReturnsScreenState();
}

class _BestReturnsScreenState extends State<BestReturnsScreen> {
  List<CollectionItem> _filtered = const [];
  // REQ-034: see ValueTrendScreen's identical field -- same feedback-loop
  // risk from SearchFilterBar's onFiltered callback setState()ing this
  // State.
  late final Stream<List<CollectionItem>> _itemsStream = widget.database.watchAllItems();
  int _limit = _defaultLimit;
  bool _loadedPersisted = false;
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _limit = prefs.getInt(_limitKey) ?? _defaultLimit;
      _loadedPersisted = true;
    });
  }

  Future<void> _saveParams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitKey, _limit);
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
        stream: _itemsStream,
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

          final ranked = computeAnnualizedReturns(_filtered, limit: _limit);
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
              SearchFilterBar(
                prefsKeyPrefix: 'best_returns_filter',
                items: allItems,
                onFiltered: (result) => setState(() => _filtered = result),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
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
                    showCheckboxColumn: false,
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
                      for (final (i, r) in ranked.indexed)
                        DataRow(
                          // REQ-042 (a): open the item, paging the displayed (sorted) list.
                          onSelectChanged: (_) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(
                                database: widget.database,
                                items: [for (final x in ranked) x.item],
                                initialIndex: i,
                              ),
                            ),
                          ),
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
