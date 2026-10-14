import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../collection_search.dart';
import '../database/database.dart';

/// REQ-042 (b), ADR-22 Option 1: the controls strip shared by the three
/// item-list tabs -- matching count, matching value, percent of the whole
/// collection's value, a sort key picker and an asc/desc toggle. Controlled:
/// the host owns [sortKey]/[ascending] (its own initial value is the
/// first-launch and fallback value) and applies [sortItems]; this widget
/// persists the choice under [prefsKeyPrefix] (same prefix as
/// [SearchFilterBar]) and reports a persisted choice once on load.
class ItemListStrip extends StatefulWidget {
  const ItemListStrip({
    super.key,
    required this.prefsKeyPrefix,
    required this.filtered,
    required this.whole,
    required this.sortKey,
    required this.ascending,
    required this.onChanged,
  });

  final String prefsKeyPrefix;
  final List<CollectionItem> filtered;
  final List<CollectionItem> whole;
  final String sortKey;
  final bool ascending;
  final void Function(String key, bool ascending) onChanged;

  @override
  State<ItemListStrip> createState() => _ItemListStripState();
}

class _ItemListStripState extends State<ItemListStrip> {
  String get _keyPref => '${widget.prefsKeyPrefix}_sort_key';
  String get _ascPref => '${widget.prefsKeyPrefix}_sort_asc';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // `get` + type test, not getString/getBool: a wrong-typed stored value
    // must fall back like a missing one, not throw.
    final key = prefs.get(_keyPref);
    final asc = prefs.get(_ascPref);
    // An unknown, missing or wrong-typed key keeps the host's initial value.
    if (!mounted || key is! String || !sortKeyIds.contains(key)) return;
    widget.onChanged(key, asc is bool ? asc : true);
  }

  Future<void> _change(String key, bool ascending) async {
    widget.onChanged(key, ascending);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
    await prefs.setBool(_ascPref, ascending);
  }

  double _total(List<CollectionItem> items) =>
      collectionDistribution(items).values.fold(0.0, (sum, v) => sum + v);

  @override
  Widget build(BuildContext context) {
    final matching = _total(widget.filtered);
    final whole = _total(widget.whole);
    final pct = whole == 0 ? 0.0 : matching / whole * 100;
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.filtered.length} matching items', style: style),
              Text('\$${matching.toStringAsFixed(2)}', style: style),
              Text('${pct.toStringAsFixed(1)}%', style: style),
            ],
          ),
          Row(
            children: [
              Text('Sort', style: style),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: const Key('sort-key-picker'),
                value: widget.sortKey,
                isDense: true,
                items: [
                  for (final id in sortKeyIds)
                    DropdownMenuItem(value: id, child: Text(sortKeyLabel(id))),
                ],
                // A key change resets the direction to ascending.
                onChanged: (id) => id == null ? null : _change(id, true),
              ),
              IconButton(
                key: const Key('sort-direction'),
                tooltip: widget.ascending ? 'Ascending' : 'Descending',
                icon: Icon(widget.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => _change(widget.sortKey, !widget.ascending),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
