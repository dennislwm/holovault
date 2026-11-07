import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/annualized_return.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';

import 'helpers.dart';

void main() {
  final fx = DbFixture();

  test('REQ-030: a numeric clause (value>100) narrows the list', () async {
    await seedItem(fx.db, importedId: '1', name: 'A', valueTotal: 50);
    await seedItem(fx.db, importedId: '2', name: 'B', valueTotal: 150);
    final items = await fx.db.select(fx.db.mergedItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: '',
      clauses: const [
        SearchClause(field: SearchField.value, op: SearchOperator.greaterThan, value: '100'),
      ],
    );

    expect(result.map((i) => i.name), ['B']);
  });

  test('REQ-030: a text clause (rarity!=Sealed) excludes matching items', () async {
    await seedItem(fx.db, importedId: '1', name: 'A', rarity: 'Sealed');
    await seedItem(fx.db, importedId: '2', name: 'B', rarity: 'Holo');
    final items = await fx.db.select(fx.db.mergedItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: '',
      clauses: const [
        SearchClause(field: SearchField.rarity, op: SearchOperator.notEqual, value: 'Sealed'),
      ],
    );

    expect(result.map((i) => i.name), ['B']);
  });

  test('REQ-030: an item with a null field never matches any clause on that field', () async {
    await seedItem(fx.db, importedId: '1', name: 'A');
    await seedItem(fx.db, importedId: '2', name: 'B', valueTotal: 100);
    final items = await fx.db.select(fx.db.mergedItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: '',
      clauses: const [
        SearchClause(field: SearchField.value, op: SearchOperator.notEqual, value: '999'),
      ],
    );

    // 'A' has a null valueTotal -- excluded even though 999 != null "should"
    // vacuously hold; explicit exclusion is REQ-030's stated behavior.
    expect(result.map((i) => i.name), ['B']);
  });

  test('REQ-030: search text and a clause narrow together (AND)', () async {
    await seedItem(fx.db, importedId: '1', name: 'Charizard', rarity: 'Sealed');
    await seedItem(fx.db, importedId: '2', name: 'Charizard', rarity: 'Holo');
    await seedItem(fx.db, importedId: '3', name: 'Blastoise', rarity: 'Sealed');
    final items = await fx.db.select(fx.db.mergedItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: 'char',
      clauses: const [
        SearchClause(field: SearchField.rarity, op: SearchOperator.equal, value: 'Sealed'),
      ],
    );

    expect(result.map((i) => i.name), ['Charizard']);
    expect(result.single.rarity, 'Sealed');
  });

  // REQ-035 (paid) and REQ-036 (value): a per-unit field compares the per-unit
  // column, not the total column.
  for (final (label, field, make) in <(
    String,
    SearchField,
    CollectionItemsCompanion Function(String, String, double, double),
  )>[
    (
      'REQ-035: a paidPerUnit clause compares per-unit, not the paidTotal',
      SearchField.paidPerUnit,
      (id, name, unit, total) => CollectionItemsCompanion.insert(
        importedId: id,
        name: name,
        paidPerUnit: Value(unit),
        paidTotal: Value(total),
      ),
    ),
    (
      'REQ-036: a valuePerUnit clause compares per-unit, not the valueTotal',
      SearchField.valuePerUnit,
      (id, name, unit, total) => CollectionItemsCompanion.insert(
        importedId: id,
        name: name,
        valuePerUnit: Value(unit),
        valueTotal: Value(total),
      ),
    ),
  ]) {
    test(label, () async {
      await fx.db.upsertItem(make('1', 'Cheap per unit, high total', 5, 500));
      await fx.db.upsertItem(make('2', 'Pricey per unit', 50, 50));
      final items = await fx.db.select(fx.db.mergedItems).get();

      final result = await filterCollectionItems(
        items,
        searchTerm: '',
        clauses: [SearchClause(field: field, op: SearchOperator.greaterThan, value: '10')],
      );

      expect(result.map((i) => i.name), ['Pricey per unit']);
    });
  }

  test('REQ-030: distinctValuesForId returns sorted, deduplicated real values', () async {
    await seedItem(fx.db, importedId: '1', name: 'A', rarity: 'Sealed');
    await seedItem(fx.db, importedId: '2', name: 'B', rarity: 'Holo');
    await seedItem(fx.db, importedId: '3', name: 'C', rarity: 'Holo');
    final items = await fx.db.select(fx.db.mergedItems).get();

    expect(distinctValuesForId(SearchField.rarity.name, items), ['Holo', 'Sealed']);
  });

  group('REQ-041: return fields', () {
    MergedItem item(String name, {double? paid, double? value, DateTime? added}) =>
        MergedItem(
          id: 1,
          importedId: name,
          name: name,
          paidPerUnit: paid,
          valuePerUnit: value,
          dateAdded: added,
        );
    final now = DateTime(2026, 1, 1);

    Future<List<String>> names(
      List<MergedItem> items,
      SearchField field,
      SearchOperator op,
      String value,
    ) async {
      final result = await filterCollectionItems(
        items,
        searchTerm: '',
        clauses: [SearchClause(field: field, op: op, value: value)],
        now: now,
      );
      return result.map((i) => i.name).toList();
    }

    test('returnBase threshold: > excludes the boundary, >= includes it, below is excluded', () async {
      final items = [
        item('above', paid: 100, value: 160),
        item('at', paid: 100, value: 150),
        item('below', paid: 100, value: 149),
      ];

      expect(await names(items, SearchField.returnBase, SearchOperator.greaterThan, '50'), ['above']);
      expect(
        await names(items, SearchField.returnBase, SearchOperator.greaterThanOrEqual, '50'),
        unorderedEquals(['above', 'at']),
      );
    });

    test('returnAnnual threshold: same boundary behaviour on a 365-day hold', () async {
      final added = DateTime(2025, 1, 1);
      final items = [
        item('above', paid: 100, value: 160, added: added),
        item('at', paid: 100, value: 150, added: added),
        item('below', paid: 100, value: 149, added: added),
      ];

      expect(await names(items, SearchField.returnAnnual, SearchOperator.greaterThan, '50'), ['above']);
      expect(
        await names(items, SearchField.returnAnnual, SearchOperator.greaterThanOrEqual, '50'),
        unorderedEquals(['above', 'at']),
      );
    });

    test('returnAnnual and returnBase are distinct fields: a short hold passes only the annualized one', () async {
      // 73 days held, +10% base: annualized is (1.1^5 - 1) * 100, about 61%.
      final items = [item('short hold', paid: 100, value: 110, added: DateTime(2025, 10, 20))];

      expect(await names(items, SearchField.returnAnnual, SearchOperator.greaterThan, '50'), ['short hold']);
      expect(await names(items, SearchField.returnBase, SearchOperator.greaterThan, '50'), isEmpty);
    });

    test('an item with no price data never matches a return clause, not even !=', () async {
      final items = [item('no price')];

      expect(await names(items, SearchField.returnBase, SearchOperator.notEqual, '999'), isEmpty);
      expect(await names(items, SearchField.returnAnnual, SearchOperator.notEqual, '999'), isEmpty);
    });

    test('availableFields hides the rival return field and restores it when the clause is gone', () {
      const annual = SearchClause(
        field: SearchField.returnAnnual,
        op: SearchOperator.greaterThan,
        value: '20',
      );
      const base = SearchClause(
        field: SearchField.returnBase,
        op: SearchOperator.greaterThan,
        value: '20',
      );

      expect(availableFields(const []), SearchField.values);

      final withAnnual = availableFields(const [annual]);
      expect(withAnnual, contains(SearchField.returnAnnual));
      expect(withAnnual, isNot(contains(SearchField.returnBase)));

      final withBase = availableFields(const [base]);
      expect(withBase, contains(SearchField.returnBase));
      expect(withBase, isNot(contains(SearchField.returnAnnual)));
    });
  });

  group('REQ-042 (b): sortItems', () {
    Future<List<MergedItem>> seed() async {
      await seedItem(fx.db, importedId: '1', name: 'b', valueTotal: 20);
      await seedItem(fx.db, importedId: '2', name: 'A');
      await seedItem(fx.db, importedId: '3', name: 'C', valueTotal: 10);
      return fx.db.select(fx.db.mergedItems).get();
    }

    test('an item with no value sorts last in both directions', () async {
      final items = await seed();

      final asc = sortItems(items, SearchField.value.name, true);
      final desc = sortItems(items, SearchField.value.name, false);

      expect(asc.map((i) => i.name), ['C', 'b', 'A']);
      expect(desc.map((i) => i.name), ['b', 'C', 'A']);
    });

    test('name sorts case-insensitively and an unknown key keeps the order', () async {
      final items = await seed();

      expect(sortItems(items, nameSortKey, true).map((i) => i.name), ['A', 'b', 'C']);
      expect(sortItems(items, 'no_such_key', true), items);
    });
  });

  group('REQ-042 (c): parseColumnIds', () {
    const fallback = ['name', 'extra'];

    test('keeps known ids in order and skips unknown, duplicate and non-string entries', () {
      expect(
        parseColumnIds('["paid","bogus","name",7,"paid"]', fallback),
        ['paid', 'name'],
      );
    });

    test('missing, malformed, wrong-typed or empty falls back', () {
      expect(parseColumnIds(null, fallback), fallback);
      expect(parseColumnIds('not json', fallback), fallback);
      expect(parseColumnIds('{"a":1}', fallback), fallback);
      expect(parseColumnIds(5, fallback), fallback);
      expect(parseColumnIds('["bogus"]', fallback), fallback);
      expect(parseColumnIds('[]', fallback), fallback);
    });
  });

  test('REQ-042 (c): maxAbsReturnAnnual is 0 for no items or no return and the largest absolute value otherwise', () async {
    expect(maxAbsReturnAnnual(const []), 0);
    final now = DateTime(2026, 1, 1);
    final bought = DateTime(2025, 1, 1);
    for (final (id, paid, value) in [
      ('1', 100.0, 150.0),
      ('2', 100.0, 40.0),
      ('3', 100.0, null),
    ]) {
      await seedItem(
        fx.db,
        importedId: id,
        name: id,
        paidPerUnit: paid,
        valuePerUnit: value,
        dateAdded: bought,
      );
    }
    final items = await fx.db.watchMergedItems().first;
    expect(maxAbsReturnAnnual([items.last], now: now), 0);
    final byId = {for (final i in items) i.importedId: i};
    final up = annualizedReturnPercent(byId['1']!, now)!;
    final down = annualizedReturnPercent(byId['2']!, now)!;
    expect(maxAbsReturnAnnual(items, now: now), closeTo(up.abs() > down.abs() ? up.abs() : down.abs(), 1e-9));
    expect(down, isNegative);
  });

  test('REQ-042 (c): cellText formats each field kind and reports a missing value as null', () async {
    await seedItem(fx.db, importedId: '1', name: 'A', quantity: 3, paidTotal: 12.5, rarity: 'Holo');
    final item = (await fx.db.watchMergedItems().first).single;
    expect(cellText(item, 'name'), 'A');
    expect(cellText(item, 'extra'), isNull);
    expect(cellText(item, 'quantity'), '×3');
    expect(cellText(item, 'paid'), '12.50');
    expect(cellText(item, 'rarity'), 'Holo');
    expect(cellText(item, 'value'), isNull);
  });
}
