import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../annualized_return.dart';
import '../database/database.dart';
import '../collection_search.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/item_list_strip.dart';
import '../widgets/item_row.dart';
import 'collection_list_screen.dart' show schemaErrorMessage;
import 'item_detail_screen.dart';

const _limitKey = 'best_returns_limit';

const _defaultLimit = 5;

/// ADR-16 (superseded by ADR-19), ADR-19 Option 1: ranks collection items by
/// annualized return (CAGR) as shared item rows (ADR-22) whose Return/annual cell
/// is the percent text plus a proportional-width bar.
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
  // REQ-042 (b): the screen's initial sort (Return descending, as before);
  // the strip persists the user's.
  String _sortKey = SearchField.returnAnnual.name;
  bool _sortAsc = false;
  // REQ-042 (d): the screen's default columns; the strip persists the user's.
  static const _defaultColumns = [
    'name',
    'returnAnnual',
    'paidPerUnit',
    'valuePerUnit',
    'daysHeld',
  ];
  List<String> _columns = _defaultColumns;

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

          // Top N by return, then shown in the strip's chosen order.
          final top = computeAnnualizedReturns(_filtered, limit: _limit);
          final byItem = {for (final r in top) r.item: r};
          final ranked = [
            for (final i in sortItems([for (final r in top) r.item], _sortKey, _sortAsc))
              byItem[i]!,
          ];
          final returnBarMax = maxAbsReturnAnnual([for (final r in ranked) r.item]);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SearchFilterBar(
                prefsKeyPrefix: 'best_returns_filter',
                items: allItems,
                onFiltered: (result) => setState(() => _filtered = result),
              ),
              const SizedBox(height: 12),
              ItemListStrip(
                prefsKeyPrefix: 'best_returns_filter',
                filtered: _filtered,
                whole: allItems,
                sortKey: _sortKey,
                ascending: _sortAsc,
                columns: _columns,
                defaultColumns: _defaultColumns,
                onColumnsChanged: (cols) => setState(() => _columns = cols),
                onChanged: (key, asc) => setState(() {
                  _sortKey = key;
                  _sortAsc = asc;
                }),
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
                      Text('Top N by return', style: Theme.of(context).textTheme.bodySmall),
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
                for (final (i, r) in ranked.indexed)
                  InkWell(
                    key: Key('best-returns-row-$i'),
                    // REQ-042 (a): open the item, paging the displayed (sorted) list.
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          database: widget.database,
                          items: [for (final x in ranked) x.item],
                          initialIndex: i,
                        ),
                      ),
                    ),
                    child: ItemRow(
                      item: r.item,
                      columns: _columns,
                      returnBarMax: returnBarMax,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
