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
}
