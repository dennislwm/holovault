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

/// REQ-041: one item's CAGR percent, or null when any input is missing or
/// unusable (null/non-positive paid, null value, null dateAdded, days <= 0).
/// Shared by [computeAnnualizedReturns] (ranking) and
/// `SearchField.returnAnnual` (filtering) so the two cannot drift.
// ponytail: no min-days guard -- a 1-day hold inflates via 365/days; a Days
// held clause covers it (REQ-035 did the same for min_days).
double? annualizedReturnPercent(CollectionItem item, DateTime now) {
  final paid = item.paidPerUnit;
  final value = item.valuePerUnit;
  final dateAdded = item.dateAdded;
  if (paid == null || paid <= 0) return null;
  if (value == null) return null;
  if (dateAdded == null) return null;
  final days = now.difference(dateAdded).inDays;
  if (days <= 0) return null;
  return ((pow(value / paid, 365.0 / days) - 1) * 100).toDouble();
}

/// REQ-041: one item's plain (non-annualized) return percent,
/// `(valuePerUnit / paidPerUnit - 1) * 100`. Same null/non-positive-paid
/// rule as [annualizedReturnPercent], but needs no dateAdded.
double? baseReturnPercent(CollectionItem item) {
  final paid = item.paidPerUnit;
  final value = item.valuePerUnit;
  if (paid == null || paid <= 0) return null;
  if (value == null) return null;
  return (value / paid - 1) * 100;
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
    final percent = annualizedReturnPercent(item, today);
    if (percent == null) continue;
    // dateAdded is non-null here: annualizedReturnPercent returns null without it.
    final days = today.difference(item.dateAdded!).inDays;
    results.add(AnnualizedReturn(item: item, daysHeld: days, percent: percent));
  }
  results.sort((a, b) => b.percent.compareTo(a.percent));
  return results.take(limit).toList();
}
