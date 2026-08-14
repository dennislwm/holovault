import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../collection_search.dart';
import '../database/database.dart';

/// ADR-19, Option 1: the search bar + clause-builder mechanism
/// [CollectionListScreen] (ADR-18) originated, promoted to a shared widget
/// so [ValueTrendScreen]/[BestReturnsScreen] use the same input mechanism
/// instead of their own fixed-dropdown filters (ADR-12/ADR-16, both
/// superseded). Owns the search term + clause list, persists both to
/// `shared_preferences` keyed by [prefsKeyPrefix] (REQ-034 -- restart
/// persistence on all three tabs, including [CollectionListScreen], which
/// previously had none), and reports the filtered result of
/// [filterCollectionItems] via [onFiltered] whenever [items], the search
/// term, or the clause list changes.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.prefsKeyPrefix,
    required this.items,
    required this.onFiltered,
  });

  final String prefsKeyPrefix;
  final List<CollectionItem> items;
  final void Function(List<CollectionItem> filtered) onFiltered;

  @override
  State<SearchFilterBar> createState() => SearchFilterBarState();
}

class SearchFilterBarState extends State<SearchFilterBar> {
  String _searchTerm = '';
  final List<SearchClause> _clauses = [];
  List<CollectionItem> _filtered = const [];
  // REQ-033: owned here, not by the TextField itself -- this State is never
  // virtualized (each screen uses it as a single ListView/Column item), so
  // it's safe from the Element-destruction risk an uncontrolled TextField
  // would otherwise carry.
  final TextEditingController _searchController = TextEditingController();

  String get _searchKey => '${widget.prefsKeyPrefix}_search';
  String get _clausesKey => '${widget.prefsKeyPrefix}_clauses';

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _searchTerm = prefs.getString(_searchKey) ?? '';
    _searchController.text = _searchTerm;
    final rawClauses = prefs.getString(_clausesKey);
    if (rawClauses != null) {
      final decoded = jsonDecode(rawClauses) as List<dynamic>;
      _clauses.addAll(
        decoded.map((e) => SearchClause.fromJson(e as Map<String, dynamic>)),
      );
    }
    await _recompute();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchKey, _searchTerm);
    await prefs.setString(
      _clausesKey,
      jsonEncode(_clauses.map((c) => c.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) _recompute();
  }

  Future<void> _recompute() async {
    final result = await filterCollectionItems(
      widget.items,
      searchTerm: _searchTerm,
      clauses: _clauses,
    );
    if (!mounted) return;
    setState(() => _filtered = result);
    widget.onFiltered(result);
  }

  void _addClause(SearchClause clause) {
    setState(() => _clauses.add(clause));
    _recompute();
    _persist();
  }

  void _removeClause(int index) {
    setState(() => _clauses.removeAt(index));
    _recompute();
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _searchTerm = value;
              _recompute();
              _persist();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _clauses.length; i++)
                InputChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      '${_clauses[i].field.label} ${_clauses[i].op.symbol} ${_clauses[i].value}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () => _removeClause(i),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add clause'),
                onPressed: () => showAddClauseSheet(context, _filtered, _addClause),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ADR-18, Option 2: sequential picker -- field, then an operator dropdown
/// scoped to that field's type, then the value last (a number field for
/// numeric/date fields, a dropdown of real distinct values, narrowed by
/// [narrowed], for text fields). Shared by every [SearchFilterBar] instance.
void showAddClauseSheet(
  BuildContext context,
  List<CollectionItem> narrowed,
  void Function(SearchClause) onAdd,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      SearchField? field;
      SearchOperator? op;
      final valueController = TextEditingController();
      String? textValue;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add clause', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<SearchField>(
                  initialValue: field,
                  decoration: const InputDecoration(labelText: 'Field'),
                  items: [
                    for (final f in SearchField.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (value) => setSheetState(() {
                    field = value;
                    op = null;
                    textValue = null;
                    valueController.clear();
                  }),
                ),
                if (field != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SearchOperator>(
                    initialValue: op,
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: [
                      for (final o in operatorsFor(field!))
                        DropdownMenuItem(value: o, child: Text(o.symbol)),
                    ],
                    onChanged: (value) => setSheetState(() => op = value),
                  ),
                ],
                if (field != null && op != null) ...[
                  const SizedBox(height: 12),
                  if (field!.isText)
                    DropdownButtonFormField<String>(
                      initialValue: textValue,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Value'),
                      items: [
                        for (final v in distinctValuesFor(field!, narrowed))
                          DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setSheetState(() => textValue = value),
                    )
                  else
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Value'),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: field == null || op == null
                      || (field!.isText ? textValue == null : valueController.text.isEmpty)
                      ? null
                      : () {
                          onAdd(
                            SearchClause(
                              field: field!,
                              op: op!,
                              value: field!.isText ? textValue! : valueController.text,
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
