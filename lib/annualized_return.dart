import 'dart:math';

import 'database/database.dart';

/// ADR-16, Option 1: one item's CAGR result. Kept in its own pure-Dart
/// file, separate from the screen widget, so the formula is
/// unit-testable without a widget pump.
class AnnualizedReturn {
  const AnnualizedReturn({
    required this.item,
    required this.daysHeld,
    required this.percent,
  });

  final CollectionItem item;
  final int daysHeld;
  final double percent;
}

/// pyholofoil's CAGR formula (`(value/paid)^(365/days) - 1`), reframed in
/// Dart terms: holovault's valuePerUnit/paidPerUnit are already typed
/// REAL (REQ-012 already resolves the "Unavailable" sentinel to null at
/// import time), so this needs a null-check only, not pyholofoil's
/// TEXT-guard clauses. REQ-035: the `minPaid`/`maxValue`/`minDays`
/// thresholds this function used to apply are now the clause builder's
/// job (`SearchField.paidPerUnit`/`.valuePerUnit`/`.daysHeld`) -- this
/// function only computes the ranking, on whatever's already filtered.
List<AnnualizedReturn> computeAnnualizedReturns(
  List<CollectionItem> items, {
  required int limit,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final results = <AnnualizedReturn>[];
  for (final item in items) {
    final paid = item.paidPerUnit;
    final value = item.valuePerUnit;
    final dateAdded = item.dateAdded;
    if (paid == null || paid <= 0) continue;
    if (value == null) continue;
    if (dateAdded == null) continue;
    final days = today.difference(dateAdded).inDays;
    if (days <= 0) continue;
    final percent = (pow(value / paid, 365.0 / days) - 1) * 100;
    results.add(
      AnnualizedReturn(item: item, daysHeld: days, percent: percent.toDouble()),
    );
  }
  results.sort((a, b) => b.percent.compareTo(a.percent));
  return results.take(limit).toList();
}
