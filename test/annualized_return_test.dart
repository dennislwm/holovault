import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/annualized_return.dart';
import 'package:holovault/database/database.dart';

import 'helpers.dart';

void main() {
  final fx = DbFixture();

  test('ranks items by annualized return, highest first', () async {
    await seedItem(
      fx.db,
      importedId: 'card-1',
      name: 'Slow grower',
      paidPerUnit: 100.0,
      valuePerUnit: 150.0,
      dateAdded: DateTime(2025, 1, 1),
    );
    await seedItem(
      fx.db,
      importedId: 'card-2',
      name: 'Fast grower',
      paidPerUnit: 100.0,
      valuePerUnit: 300.0,
      dateAdded: DateTime(2025, 1, 1),
    );
    final items = await fx.db.select(fx.db.mergedItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 10, now: DateTime(2026, 1, 1));

    expect(ranked, hasLength(2));
    expect(ranked.first.item.name, 'Fast grower');
    expect(ranked.first.percent, greaterThan(ranked.last.percent));
  });

  test('excludes an item with no paidPerUnit/valuePerUnit', () async {
    await seedItem(
      fx.db,
      importedId: 'card-1',
      name: 'No price data',
      dateAdded: DateTime(2025, 1, 1),
    );
    final items = await fx.db.select(fx.db.mergedItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 10, now: DateTime(2026, 1, 1));

    expect(ranked, isEmpty);
  });

  test('limit truncates the ranked list to the top N', () async {
    for (var i = 0; i < 5; i++) {
      await seedItem(
        fx.db,
        importedId: 'card-$i',
        name: 'Item $i',
        paidPerUnit: 10.0 + i,
        valuePerUnit: 20.0 + i,
        dateAdded: DateTime(2025, 1, 1),
      );
    }
    final items = await fx.db.select(fx.db.mergedItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 2, now: DateTime(2026, 1, 1));

    expect(ranked, hasLength(2));
  });

  group('REQ-041: per-item return percent', () {
    MergedItem item({double? paid, double? value, DateTime? added}) => MergedItem(
      id: 1,
      importedId: 'x',
      name: 'X',
      paidPerUnit: paid,
      valuePerUnit: value,
      dateAdded: added,
    );
    final now = DateTime(2026, 1, 1);
    final held365 = DateTime(2025, 1, 1); // 365 days: annualized equals base

    test('annualized: a 365-day hold equals the base return, at and below zero', () {
      expect(annualizedReturnPercent(item(paid: 100, value: 150, added: held365), now), 50.0);
      expect(annualizedReturnPercent(item(paid: 100, value: 100, added: held365), now), 0.0);
      expect(
        annualizedReturnPercent(item(paid: 100, value: 80, added: held365), now),
        closeTo(-20, 1e-9),
      );
    });

    test('annualized: null paid, non-positive paid, null value, null or same-day dateAdded give null', () {
      expect(annualizedReturnPercent(item(value: 150, added: held365), now), isNull);
      expect(annualizedReturnPercent(item(paid: 0, value: 150, added: held365), now), isNull);
      expect(annualizedReturnPercent(item(paid: 100, added: held365), now), isNull);
      expect(annualizedReturnPercent(item(paid: 100, value: 150), now), isNull);
      expect(annualizedReturnPercent(item(paid: 100, value: 150, added: now), now), isNull);
    });

    test('base: value over paid minus one, as a percent, with no dateAdded needed', () {
      expect(baseReturnPercent(item(paid: 100, value: 150)), 50.0);
      expect(baseReturnPercent(item(paid: 100, value: 100)), 0.0);
    });

    test('base: null paid, non-positive paid and null value give null', () {
      expect(baseReturnPercent(item(value: 150)), isNull);
      expect(baseReturnPercent(item(paid: 0, value: 150)), isNull);
      expect(baseReturnPercent(item(paid: 100)), isNull);
    });
  });
}
