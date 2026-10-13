import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('REQ-030: a numeric clause (value>100) narrows the list', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '1', name: 'A', valueTotal: const Value(50)),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '2', name: 'B', valueTotal: const Value(150)),
    );
    final items = await db.select(db.collectionItems).get();

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
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '1', name: 'A', rarity: const Value('Sealed')),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '2', name: 'B', rarity: const Value('Holo')),
    );
    final items = await db.select(db.collectionItems).get();

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
    await db.upsertItem(CollectionItemsCompanion.insert(importedId: '1', name: 'A'));
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '2', name: 'B', valueTotal: const Value(100)),
    );
    final items = await db.select(db.collectionItems).get();

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
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '1',
        name: 'Charizard',
        rarity: const Value('Sealed'),
      ),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '2',
        name: 'Charizard',
        rarity: const Value('Holo'),
      ),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '3',
        name: 'Blastoise',
        rarity: const Value('Sealed'),
      ),
    );
    final items = await db.select(db.collectionItems).get();

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

  test('REQ-035: a paidPerUnit clause compares per-unit, not the paidTotal', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '1',
        name: 'Cheap per unit, high total',
        paidPerUnit: const Value(5),
        paidTotal: const Value(500),
      ),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '2',
        name: 'Pricey per unit',
        paidPerUnit: const Value(50),
        paidTotal: const Value(50),
      ),
    );
    final items = await db.select(db.collectionItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: '',
      clauses: const [
        SearchClause(field: SearchField.paidPerUnit, op: SearchOperator.greaterThan, value: '10'),
      ],
    );

    expect(result.map((i) => i.name), ['Pricey per unit']);
  });

  test('REQ-036: a valuePerUnit clause compares per-unit, not the valueTotal', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '1',
        name: 'Cheap per unit, high total',
        valuePerUnit: const Value(5),
        valueTotal: const Value(500),
      ),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: '2',
        name: 'Pricey per unit',
        valuePerUnit: const Value(50),
        valueTotal: const Value(50),
      ),
    );
    final items = await db.select(db.collectionItems).get();

    final result = await filterCollectionItems(
      items,
      searchTerm: '',
      clauses: const [
        SearchClause(field: SearchField.valuePerUnit, op: SearchOperator.greaterThan, value: '10'),
      ],
    );

    expect(result.map((i) => i.name), ['Pricey per unit']);
  });

  test('REQ-030: distinctValuesFor returns sorted, deduplicated real values', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '1', name: 'A', rarity: const Value('Sealed')),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '2', name: 'B', rarity: const Value('Holo')),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(importedId: '3', name: 'C', rarity: const Value('Holo')),
    );
    final items = await db.select(db.collectionItems).get();

    expect(distinctValuesFor(SearchField.rarity, items), ['Holo', 'Sealed']);
  });

  group('REQ-041: return fields', () {
    CollectionItem item(String name, {double? paid, double? value, DateTime? added}) =>
        CollectionItem(
          id: 1,
          importedId: name,
          name: name,
          paidPerUnit: paid,
          valuePerUnit: value,
          dateAdded: added,
        );
    final now = DateTime(2026, 1, 1);

    Future<List<String>> names(
      List<CollectionItem> items,
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
}
