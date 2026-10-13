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

/// ADR-20, Option 1: a named, saved `{searchTerm, clauses}` snapshot a user
/// can reapply later, distinct from [SearchFilterBarState]'s own single
/// live state.
class FilterPreset {
  const FilterPreset({required this.name, required this.searchTerm, required this.clauses});

  final String name;
  final String searchTerm;
  final List<SearchClause> clauses;

  Map<String, dynamic> toJson() => {
    'name': name,
    'searchTerm': searchTerm,
    'clauses': clauses.map((c) => c.toJson()).toList(),
  };

  factory FilterPreset.fromJson(Map<String, dynamic> json) => FilterPreset(
    name: json['name'] as String,
    searchTerm: json['searchTerm'] as String,
    clauses: (json['clauses'] as List<dynamic>)
        .map((e) => SearchClause.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
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
  final List<FilterPreset> _presets = [];

  String get _searchKey => '${widget.prefsKeyPrefix}_search';
  String get _clausesKey => '${widget.prefsKeyPrefix}_clauses';
  String get _presetsKey => '${widget.prefsKeyPrefix}_presets';

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
    final rawPresets = prefs.getString(_presetsKey);
    if (rawPresets != null) {
      final decoded = jsonDecode(rawPresets) as List<dynamic>;
      _presets.addAll(
        decoded.map((e) => FilterPreset.fromJson(e as Map<String, dynamic>)),
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

  Future<void> _persistPresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _presetsKey,
      jsonEncode(_presets.map((p) => p.toJson()).toList()),
    );
  }

  /// Saving under an existing name replaces that entry -- idempotent by
  /// name, never appends a duplicate.
  void _savePreset(String name) {
    setState(() {
      _presets.removeWhere((p) => p.name == name);
      _presets.add(
        FilterPreset(name: name, searchTerm: _searchTerm, clauses: List.of(_clauses)),
      );
    });
    _persistPresets();
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      _searchTerm = preset.searchTerm;
      _searchController.text = preset.searchTerm;
      _clauses
        ..clear()
        ..addAll(preset.clauses);
    });
    _recompute();
    _persist();
  }

  void _deletePreset(String name) {
    setState(() => _presets.removeWhere((p) => p.name == name));
    _persistPresets();
  }

  /// REQ-039: deleting a preset has no undo, so confirm before it happens.
  Future<void> _confirmDeletePreset(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _deletePreset(name);
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
          child: Row(
            children: [
              Expanded(
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
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save as...',
                onPressed: () => _showSaveAsDialog(context),
              ),
            ],
          ),
        ),
        if (_presets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: DropdownButtonFormField<String>(
              initialValue: null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Presets', isDense: true),
              items: [
                for (final preset in _presets)
                  DropdownMenuItem(
                    value: preset.name,
                    child: Row(
                      children: [
                        Expanded(child: Text(preset.name, overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _confirmDeletePreset(context, preset.name),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (name) {
                if (name == null) return;
                final preset = _presets.firstWhere((p) => p.name == name);
                _applyPreset(preset);
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
                onPressed: () => showAddClauseSheet(
                  context,
                  _filtered,
                  _addClause,
                  existing: _clauses,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSaveAsDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as...'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Preset name'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.of(context).pop(value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(value.text.trim()),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) _savePreset(name);
  }
}

/// ADR-18, Option 2: sequential picker -- field, then an operator dropdown
/// scoped to that field's type, then the value last (a number field for
/// numeric/date fields, a dropdown of real distinct values, narrowed by
/// [narrowed], for text fields). Shared by every [SearchFilterBar] instance.
/// REQ-041: [existing] is the clause list already added, so the Field
/// dropdown can hide a return field whose rival is already in use.
void showAddClauseSheet(
  BuildContext context,
  List<CollectionItem> narrowed,
  void Function(SearchClause) onAdd, {
  List<SearchClause> existing = const [],
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AddClauseSheet(narrowed: narrowed, onAdd: onAdd, existing: existing),
  );
}

/// REQ-038: was a `StatefulBuilder` closure over local variables --
/// reported (device only, not reproducible in a widget test) to lose the
/// field/operator selection when the numeric Value `TextField`'s keyboard
/// takes focus. A real `StatefulWidget` gives this form its own `State`
/// object instead of relying on an enclosing builder closure staying
/// intact across every rebuild, removing that fragility class outright.
class _AddClauseSheet extends StatefulWidget {
  const _AddClauseSheet({
    required this.narrowed,
    required this.onAdd,
    required this.existing,
  });

  final List<CollectionItem> narrowed;
  final void Function(SearchClause) onAdd;
  final List<SearchClause> existing;

  @override
  State<_AddClauseSheet> createState() => _AddClauseSheetState();
}

class _AddClauseSheetState extends State<_AddClauseSheet> {
  SearchField? _field;
  SearchOperator? _op;
  String? _textValue;
  final _valueController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            initialValue: _field,
            decoration: const InputDecoration(labelText: 'Field'),
            items: [
              for (final f in availableFields(widget.existing))
                DropdownMenuItem(value: f, child: Text(f.label)),
            ],
            onChanged: (value) => setState(() {
              _field = value;
              _op = null;
              _textValue = null;
              _valueController.clear();
            }),
          ),
          if (_field != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<SearchOperator>(
              initialValue: _op,
              decoration: const InputDecoration(labelText: 'Operator'),
              items: [
                for (final o in operatorsFor(_field!))
                  DropdownMenuItem(value: o, child: Text(o.symbol)),
              ],
              onChanged: (value) => setState(() => _op = value),
            ),
          ],
          if (_field != null && _op != null) ...[
            const SizedBox(height: 12),
            if (_field!.isText)
              DropdownButtonFormField<String>(
                initialValue: _textValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Value'),
                items: [
                  for (final v in distinctValuesFor(_field!, widget.narrowed))
                    DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _textValue = value),
              )
            else
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Value'),
                onChanged: (_) => setState(() {}),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _field == null || _op == null
                || (_field!.isText ? _textValue == null : _valueController.text.isEmpty)
                ? null
                : () {
                    widget.onAdd(
                      SearchClause(
                        field: _field!,
                        op: _op!,
                        value: _field!.isText ? _textValue! : _valueController.text,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
