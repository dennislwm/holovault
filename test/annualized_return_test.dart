import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/annualized_return.dart';
import 'package:holovault/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('ranks items by annualized return, highest first', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: 'card-1',
        name: 'Slow grower',
        paidPerUnit: const Value(100.0),
        valuePerUnit: const Value(150.0),
        dateAdded: Value(DateTime(2025, 1, 1)),
      ),
    );
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: 'card-2',
        name: 'Fast grower',
        paidPerUnit: const Value(100.0),
        valuePerUnit: const Value(300.0),
        dateAdded: Value(DateTime(2025, 1, 1)),
      ),
    );
    final items = await db.select(db.collectionItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 10, now: DateTime(2026, 1, 1));

    expect(ranked, hasLength(2));
    expect(ranked.first.item.name, 'Fast grower');
    expect(ranked.first.percent, greaterThan(ranked.last.percent));
  });

  test('excludes an item with no paidPerUnit/valuePerUnit', () async {
    await db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: 'card-1',
        name: 'No price data',
        dateAdded: Value(DateTime(2025, 1, 1)),
      ),
    );
    final items = await db.select(db.collectionItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 10, now: DateTime(2026, 1, 1));

    expect(ranked, isEmpty);
  });

  test('limit truncates the ranked list to the top N', () async {
    for (var i = 0; i < 5; i++) {
      await db.upsertItem(
        CollectionItemsCompanion.insert(
          importedId: 'card-$i',
          name: 'Item $i',
          paidPerUnit: Value(10.0 + i),
          valuePerUnit: Value(20.0 + i),
          dateAdded: Value(DateTime(2025, 1, 1)),
        ),
      );
    }
    final items = await db.select(db.collectionItems).get();

    final ranked = computeAnnualizedReturns(items, limit: 2, now: DateTime(2026, 1, 1));

    expect(ranked, hasLength(2));
  });
}
