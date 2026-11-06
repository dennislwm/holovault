import 'dart:convert';

import 'package:local_query_filter/local_query_filter.dart';

import 'annualized_return.dart';
import 'database/database.dart';
import 'database/overrides_schema.dart';

/// ADR-18, Option 2: fields an ad hoc clause can target.
enum SearchField {
  value('Value'),
  paid('Paid'),
  valuePerUnit('Value/unit'),
  paidPerUnit('Paid/unit'),
  quantity('Quantity'),
  daysHeld('Days held'),
  rarity('Rarity'),
  gradeType('Grade type'),
  setName('Set name'),
  // REQ-041: percent values (a typed `20` means 20%). Never rename these --
  // persisted clauses and presets store `field.name`. Kept after setName so
  // the existing text fields keep their picker position.
  returnAnnual('Return/annual'),
  returnBase('Return/base');

  const SearchField(this.label);
  final String label;

  bool get isText => this == rarity || this == gradeType || this == setName;

  /// REQ-041: the return field the Add clause picker hides once this one is
  /// used in a clause. Picker-only -- evaluation never consults it.
  SearchField? get rival => switch (this) {
        returnAnnual => returnBase,
        returnBase => returnAnnual,
        _ => null,
      };
}

/// REQ-041: the fields the Add clause picker offers given the clauses
/// already added -- every field except one whose [SearchField.rival] is in
/// use. Removing the clause brings the rival back (derived, not stored).
List<SearchField> availableFields(List<SearchClause> clauses) {
  final used = {for (final c in clauses) if (c.field != null) c.field};
  return [
    for (final f in SearchField.values)
      if (!used.contains(f.rival)) f,
  ];
}

enum SearchOperator {
  equal('='),
  notEqual('!='),
  greaterThan('>'),
  greaterThanOrEqual('>='),
  lessThan('<'),
  lessThanOrEqual('<=');

  const SearchOperator(this.symbol);
  final String symbol;
}

/// Text fields only support equal/notEqual -- a `>`/`<` reading on a
/// string field (per real column collation) is not something ADR-18
/// exposes to the picker.
List<SearchOperator> operatorsFor(SearchField field) =>
    field.isText
        ? const [SearchOperator.equal, SearchOperator.notEqual]
        : SearchOperator.values;

/// A clause targets a built-in [field] or, REQ-043 (e), a custom field by
/// [customFieldId] (`cf.<name>`); exactly one is set.
class SearchClause {
  const SearchClause({required SearchField this.field, required this.op, required this.value})
      : customFieldId = null;
  const SearchClause.custom({required String this.customFieldId, required this.op, required this.value})
      : field = null;
  final SearchField? field;
  final String? customFieldId;
  final SearchOperator op;
  final String value;

  /// Persisted id: the built-in `SearchField.name` (unchanged) or `cf.<name>`.
  String get fieldId => field?.name ?? customFieldId!;

  /// Chip label: the built-in label or the custom field's name, no type suffix.
  String get fieldLabel =>
      field?.label ?? customFieldId!.substring(customIdPrefix.length);

  /// REQ-034 (ADR-19): `jsonEncode` can't serialize enum fields directly --
  /// this explicit map conversion is the required step, per ADR-19's own
  /// Decision Drivers.
  Map<String, String> toJson() => {
    'field': fieldId,
    'op': op.name,
    'value': value,
  };

  /// REQ-043 (e): null (skip) when the field id names no built-in field and no
  /// declared custom field, or the operator is unknown. Never throws on a
  /// well-formed map.
  static SearchClause? tryFromJson(Map<String, dynamic> json, [List<CustomColumn>? registry]) {
    final id = json['field'] as String;
    final op = SearchOperator.values.asNameMap()[json['op'] as String];
    final value = json['value'] as String;
    if (op == null) return null;
    final builtIn = SearchField.values.asNameMap()[id];
    if (builtIn != null) return SearchClause(field: builtIn, op: op, value: value);
    if (customColumnFor(id, registry ?? customColumns) == null) return null;
    return SearchClause.custom(customFieldId: id, op: op, value: value);
  }
}

/// REQ-043 (e): the Add clause picker's field ids: built-ins (rival rule
/// applied) then declared custom ones. Bool (no clause behaviour specified)
/// and date (slice (f)) are not offered.
List<String> pickerFieldIds(List<SearchClause> existing, [List<CustomColumn>? registry]) => [
      for (final f in availableFields(existing)) f.name,
      for (final c in registry ?? customColumns)
        if (c.type != CustomColumnType.bool && c.type != CustomColumnType.date) customId(c.name),
    ];

/// Picker label: built-in label, or `name (type)` for a custom field.
String pickerFieldLabel(String id, [List<CustomColumn>? registry]) {
  final c = customColumnFor(id, registry ?? customColumns);
  return c == null ? sortKeyLabel(id, registry) : '${c.name} (${c.type.name})';
}

/// Text handling (= and != only, dropdown value) for built-in text fields and
/// custom text and choice fields.
bool fieldIsText(String id, [List<CustomColumn>? registry]) {
  final b = SearchField.values.asNameMap()[id];
  if (b != null) return b.isText;
  final t = customColumnFor(id, registry ?? customColumns)?.type;
  return t == CustomColumnType.text || t == CustomColumnType.choice;
}

List<SearchOperator> operatorsForId(String id, [List<CustomColumn>? registry]) =>
    fieldIsText(id, registry)
        ? const [SearchOperator.equal, SearchOperator.notEqual]
        : SearchOperator.values;

int? _daysHeld(MergedItem item, DateTime now) {
  final added = item.dateAdded;
  return added == null ? null : now.difference(added).inDays;
}

num? _numericFieldValue(MergedItem item, SearchField field, DateTime now) {
  switch (field) {
    case SearchField.value:
      return item.valueTotal;
    case SearchField.paid:
      return item.paidTotal;
    case SearchField.valuePerUnit:
      return item.valuePerUnit;
    case SearchField.paidPerUnit:
      return item.paidPerUnit;
    case SearchField.quantity:
      return item.quantity;
    case SearchField.daysHeld:
      return _daysHeld(item, now);
    case SearchField.returnAnnual:
      return annualizedReturnPercent(item, now);
    case SearchField.returnBase:
      return baseReturnPercent(item);
    case SearchField.rarity:
    case SearchField.gradeType:
    case SearchField.setName:
      return null;
  }
}

String? textFieldValue(MergedItem item, SearchField field) {
  switch (field) {
    case SearchField.rarity:
      return item.rarity;
    case SearchField.gradeType:
      return item.gradeType;
    case SearchField.setName:
      return item.setName;
    case SearchField.value:
    case SearchField.paid:
    case SearchField.valuePerUnit:
    case SearchField.paidPerUnit:
    case SearchField.quantity:
    case SearchField.daysHeld:
    case SearchField.returnAnnual:
    case SearchField.returnBase:
      return null;
  }
}

/// Text value of built-in or custom field [id]; null when unset or not text.
String? _textValueById(MergedItem item, String id, List<CustomColumn> registry) {
  final f = SearchField.values.asNameMap()[id];
  if (f != null) return textFieldValue(item, f);
  final v = customColumnFor(id, registry)?.value(item);
  return v is String ? v : null;
}

bool _matchesClause(MergedItem item, SearchClause clause, DateTime now, List<CustomColumn> registry) {
  if (fieldIsText(clause.fieldId, registry)) {
    final actual = _textValueById(item, clause.fieldId, registry);
    if (actual == null) return false;
    return clause.op == SearchOperator.notEqual
        ? actual != clause.value
        : actual == clause.value;
  }
  final builtIn = clause.field;
  final num? actual;
  if (builtIn != null) {
    actual = _numericFieldValue(item, builtIn, now);
  } else {
    final v = customColumnFor(clause.fieldId, registry)?.value(item);
    actual = v is num ? v : null;
  }
  final target = num.tryParse(clause.value);
  if (actual == null || target == null) return false;
  switch (clause.op) {
    case SearchOperator.equal:
      return actual == target;
    case SearchOperator.notEqual:
      return actual != target;
    case SearchOperator.greaterThan:
      return actual > target;
    case SearchOperator.greaterThanOrEqual:
      return actual >= target;
    case SearchOperator.lessThan:
      return actual < target;
    case SearchOperator.lessThanOrEqual:
      return actual <= target;
  }
}

/// ADR-18: search text and every clause narrow together (AND). Wraps
/// each clause as a [CustomConstraint] rather than [ComparisonConstraint]
/// so a null field value (an unset paidTotal/dateAdded/etc.) is handled
/// explicitly -- it never matches any clause, not even `!=`.
Future<List<MergedItem>> filterCollectionItems(
  List<MergedItem> items, {
  required String searchTerm,
  required List<SearchClause> clauses,
  DateTime? now,
  List<CustomColumn>? registry,
}) {
  final today = now ?? DateTime.now();
  final reg = registry ?? customColumns;
  final filter = QueryFilter<MergedItem>(
    ascending: true,
    searchTerm: searchTerm,
    constraints: [
      for (final clause in clauses)
        CustomConstraint<MergedItem>(
          customComparator: (item) => _matchesClause(item, clause, today, reg),
        ),
    ],
    searchFieldsExtractor: (item) => [
      item.name,
      if (item.setName != null) item.setName!,
    ],
  );
  return filter.applyFilterAndSort(items);
}

/// ADR-18: real distinct values for a text field, scoped to [narrowed] --
/// the items still matching every clause already added -- so the value
/// picker never offers a choice that would already yield zero results.
List<String> distinctValuesFor(SearchField field, List<MergedItem> narrowed) =>
    distinctValuesForId(field.name, narrowed);

/// As [distinctValuesFor] for a built-in or custom (`cf.<name>`) field id.
List<String> distinctValuesForId(
  String id,
  List<MergedItem> narrowed, [
  List<CustomColumn>? registry,
]) {
  final reg = registry ?? customColumns;
  final values = <String>{};
  for (final item in narrowed) {
    final v = _textValueById(item, id, reg);
    if (v != null && v.isNotEmpty) values.add(v);
  }
  return values.toList()..sort();
}

/// REQ-042 (b), ADR-22: list sort keys are every [SearchField] member plus
/// two picker-owned text keys. Stored by string id, so like
/// [SearchField] these ids are never renamed.
const nameSortKey = 'name';
const extraSortKey = 'extra';

/// Name and Extra first (they are the row identity), then the fields in
/// [SearchField] declaration order.
final List<String> sortKeyIds = [
  nameSortKey,
  extraSortKey,
  for (final f in SearchField.values) f.name,
];

/// REQ-043 (d): a custom field's list id is `cf.<name>`, so it cannot collide
/// with a built-in id. Stored by string like the built-ins.
const customIdPrefix = 'cf.';
String customId(String name) => '$customIdPrefix$name';

/// The declared custom column behind [id], or null (not a custom id, or no
/// longer declared).
CustomColumn? customColumnFor(String id, List<CustomColumn> registry) {
  if (!id.startsWith(customIdPrefix)) return null;
  final name = id.substring(customIdPrefix.length);
  for (final c in registry) {
    if (c.name == name) return c;
  }
  return null;
}

/// Every id a column can show: built-ins first, then declared custom ones.
List<String> columnIdsFor([List<CustomColumn>? registry]) => [
      ...sortKeyIds,
      for (final c in registry ?? customColumns) customId(c.name),
    ];

/// Ids a list can sort by: as [columnIdsFor] minus date columns (slice (f)).
List<String> sortableIdsFor([List<CustomColumn>? registry]) => [
      ...sortKeyIds,
      for (final c in registry ?? customColumns)
        if (c.type != CustomColumnType.date) customId(c.name),
    ];

/// Label for [id]; an id that names nothing known returns itself, never throws.
String sortKeyLabel(String id, [List<CustomColumn>? registry]) => switch (id) {
      nameSortKey => 'Name',
      extraSortKey => 'Extra',
      _ => SearchField.values.asNameMap()[id]?.label ??
          customColumnFor(id, registry ?? customColumns)?.name ??
          id,
    };

num? _customNum(Object? v) => switch (v) {
      num n => n,
      bool b => b ? 1 : 0,
      _ => null,
    };

/// Sort value of a custom column: text and choice lowercase, int and real
/// numeric, bool false before true. Null when unset.
Comparable? customSortValue(CustomColumn c, MergedItem item) {
  final v = c.value(item);
  return switch (c.type) {
    CustomColumnType.text || CustomColumnType.choice => v is String ? v.toLowerCase() : null,
    CustomColumnType.int || CustomColumnType.real || CustomColumnType.bool => _customNum(v),
    CustomColumnType.date => null,
  } as Comparable?;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Row cell text of a custom column; a date is the calendar date only.
String? customCellText(CustomColumn c, MergedItem item) {
  final v = c.value(item);
  if (v == null) return null;
  return switch (v) {
    DateTime d => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}',
    bool b => b ? 'Yes' : 'No',
    _ => '$v',
  };
}

/// REQ-042 (b): [items] ordered by [key], an item with no value for it
/// always last (ascending or descending). Unknown [key] returns the list
/// order unchanged. Stable: equal keys keep their incoming order.
List<MergedItem> sortItems(
  List<MergedItem> items,
  String key,
  bool ascending, {
  DateTime? now,
  List<CustomColumn>? registry,
}) {
  final reg = registry ?? customColumns;
  if (!sortableIdsFor(reg).contains(key)) return items;
  final today = now ?? DateTime.now();
  final custom = customColumnFor(key, reg);
  Comparable? valueOf(MergedItem i) {
    if (custom != null) return customSortValue(custom, i);
    if (key == nameSortKey) return i.name.toLowerCase();
    if (key == extraSortKey) return i.extra?.toLowerCase();
    final field = SearchField.values.byName(key);
    if (field.isText) return textFieldValue(i, field)?.toLowerCase();
    return _numericFieldValue(i, field, today);
  }

  final keyed = [for (final i in items) (i, valueOf(i))];
  final present = [for (final k in keyed) if (k.$2 != null) k]
    ..sort((a, b) => ascending ? a.$2!.compareTo(b.$2) : b.$2!.compareTo(a.$2));
  return [
    for (final k in present) k.$1,
    for (final k in keyed) if (k.$2 == null) k.$1,
  ];
}

/// ADR-17, Option 1: category totals for the Collection Distribution card.
/// Derivation confirmed against real data (see ADR-17 Decision Drivers):
/// `rarity == 'Sealed'` -> Sealed; else `gradeType == 'Ungraded'` ->
/// Ungraded; else -> Graded. Sums `valueTotal`, treating a null total as 0.
///
/// REQ-032: the three buckets are exhaustive by construction -- the
/// ternary chain's final branch is an unconditional `-> Graded`, not a
/// null/skip case, so every item lands in exactly one bucket regardless
/// of its `rarity`/`gradeType` values. Summing all three bucket totals
/// therefore equals the sum over every item, making this function safe
/// to reuse for a whole-list total (REQ-032's matching-value/percentage),
/// not just the three-way distribution card it was originally written for.
Map<String, double> collectionDistribution(List<MergedItem> items) {
  final totals = {'Sealed': 0.0, 'Graded': 0.0, 'Ungraded': 0.0};
  for (final item in items) {
    final category = item.rarity == 'Sealed'
        ? 'Sealed'
        : item.gradeType == 'Ungraded'
        ? 'Ungraded'
        : 'Graded';
    totals[category] = totals[category]! + (item.valueTotal ?? 0);
  }
  return totals;
}

/// REQ-042 (c), ADR-22: the text a row cell shows for column [id], or null
/// when the item has no value for it. Money to two decimals, percent to one,
/// quantity as `×N`, text fields verbatim.
String? cellText(MergedItem item, String id, {DateTime? now, List<CustomColumn>? registry}) {
  if (id == nameSortKey) return item.name;
  if (id == extraSortKey) return item.extra;
  final field = SearchField.values.asNameMap()[id];
  if (field == null) {
    final c = customColumnFor(id, registry ?? customColumns);
    return c == null ? null : customCellText(c, item);
  }
  if (field.isText) return textFieldValue(item, field);
  final v = _numericFieldValue(item, field, now ?? DateTime.now());
  if (v == null) return null;
  return switch (field) {
    SearchField.quantity => '×$v',
    SearchField.daysHeld => '$v',
    SearchField.returnAnnual || SearchField.returnBase => '${v.toStringAsFixed(1)}%',
    _ => v.toStringAsFixed(2),
  };
}

/// REQ-042 (c): the largest absolute annual return over [items], the
/// denominator for the row's return bar. 0 when none has a return.
double maxAbsReturnAnnual(List<MergedItem> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var max = 0.0;
  for (final i in items) {
    final p = annualizedReturnPercent(i, today);
    if (p != null && p.abs() > max) max = p.abs();
  }
  return max;
}

/// REQ-042 (c): column ids from a stored JSON list. Unknown ids, duplicates
/// and wrong-typed entries are skipped; a missing, malformed or empty result
/// falls back to [fallback].
List<String> parseColumnIds(
  Object? stored,
  List<String> fallback, {
  List<CustomColumn>? registry,
}) {
  final known = columnIdsFor(registry);
  if (stored is! String) return fallback;
  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } catch (_) {
    return fallback;
  }
  if (decoded is! List) return fallback;
  final ids = [
    ...{
    for (final e in decoded)
      if (e is String && known.contains(e)) e,
    },
  ];
  return ids.isEmpty ? fallback : ids;
}
