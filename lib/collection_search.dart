import 'package:local_query_filter/local_query_filter.dart';

import 'annualized_return.dart';
import 'database/database.dart';

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
  final used = {for (final c in clauses) c.field};
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

class SearchClause {
  const SearchClause({required this.field, required this.op, required this.value});
  final SearchField field;
  final SearchOperator op;
  final String value;

  /// REQ-034 (ADR-19): `jsonEncode` can't serialize enum fields directly --
  /// this explicit map conversion is the required step, per ADR-19's own
  /// Decision Drivers.
  Map<String, String> toJson() => {
    'field': field.name,
    'op': op.name,
    'value': value,
  };

  factory SearchClause.fromJson(Map<String, dynamic> json) => SearchClause(
    field: SearchField.values.byName(json['field'] as String),
    op: SearchOperator.values.byName(json['op'] as String),
    value: json['value'] as String,
  );
}

int? _daysHeld(CollectionItem item, DateTime now) {
  final added = item.dateAdded;
  return added == null ? null : now.difference(added).inDays;
}

num? _numericFieldValue(CollectionItem item, SearchField field, DateTime now) {
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

String? textFieldValue(CollectionItem item, SearchField field) {
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

bool _matchesClause(CollectionItem item, SearchClause clause, DateTime now) {
  if (clause.field.isText) {
    final actual = textFieldValue(item, clause.field);
    if (actual == null) return false;
    return clause.op == SearchOperator.notEqual
        ? actual != clause.value
        : actual == clause.value;
  }
  final actual = _numericFieldValue(item, clause.field, now);
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
Future<List<CollectionItem>> filterCollectionItems(
  List<CollectionItem> items, {
  required String searchTerm,
  required List<SearchClause> clauses,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final filter = QueryFilter<CollectionItem>(
    ascending: true,
    searchTerm: searchTerm,
    constraints: [
      for (final clause in clauses)
        CustomConstraint<CollectionItem>(
          customComparator: (item) => _matchesClause(item, clause, today),
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
List<String> distinctValuesFor(SearchField field, List<CollectionItem> narrowed) {
  final values = <String>{};
  for (final item in narrowed) {
    final v = textFieldValue(item, field);
    if (v != null && v.isNotEmpty) values.add(v);
  }
  return values.toList()..sort();
}
