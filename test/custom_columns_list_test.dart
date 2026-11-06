import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/widgets/item_list_strip.dart';
import 'package:holovault/widgets/item_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REQ-043 (d): a registry holding every type, read from existing merged-row
// fields (the real config declares only text, choice and real).
final _registry = <CustomColumn>[
  CustomColumn('tag', CustomColumnType.text, (r) => r.tag, (t) => t.serialNo),
  CustomColumn('grade', CustomColumnType.choice, (r) => r.gradeSubtype, (t) => t.serialNo),
  CustomColumn('qty', CustomColumnType.int, (r) => r.quantity, (t) => t.serialNo),
  CustomColumn('cost', CustomColumnType.real, (r) => r.paidTotal, (t) => t.serialNo),
  CustomColumn('wish', CustomColumnType.bool, (r) => r.groupWishlist, (t) => t.serialNo),
  CustomColumn('when', CustomColumnType.date, (r) => r.dateAdded, (t) => t.serialNo),
];

MergedItem _item(int id, {String? tag, int? qty, double? cost, bool? wish, DateTime? when}) =>
    MergedItem(
      id: id,
      importedId: '$id',
      name: 'N$id',
      tag: tag,
      quantity: qty,
      paidTotal: cost,
      groupWishlist: wish,
      dateAdded: when,
    );

List<int> _order(List<MergedItem> items) => [for (final i in items) i.id];

void main() {
  test('custom id is prefixed and resolves through the registry', () {
    expect(customId('qty'), 'cf.qty');
    expect(customColumnFor('cf.qty', _registry)?.name, 'qty');
    expect(customColumnFor('cf.gone', _registry), isNull);
    expect(customColumnFor('qty', _registry), isNull);
    expect(sortKeyLabel('cf.cost', _registry), 'cost');
    expect(sortKeyLabel('cf.gone', _registry), 'cf.gone');
    expect(sortKeyLabel('bogus', _registry), 'bogus');
    expect(sortKeyLabel('value', _registry), 'Value');
  });

  test('column and sort id lists: built-ins first, dates sortable (f)', () {
    final cols = columnIdsFor(_registry);
    expect(cols.sublist(0, sortKeyIds.length), sortKeyIds);
    expect(cols.sublist(sortKeyIds.length).first, 'cf.tag');
    expect(cols, contains('cf.when'));
    expect(sortableIdsFor(_registry), contains('cf.when'));
    expect(sortableIdsFor(_registry), contains('cf.wish'));
  });

  test('cell text per type; date is the calendar date only', () {
    final i = _item(1,
        tag: 'x', qty: 3, cost: 2.5, wish: false, when: DateTime(2026, 3, 7, 23, 59));
    String? t(String n) => cellText(i, customId(n), registry: _registry);
    expect(t('tag'), 'x');
    expect(t('qty'), '3');
    expect(t('cost'), '2.5');
    expect(t('wish'), 'No');
    expect(t('when'), '2026-03-07');
    expect(t('grade'), isNull);
    expect(cellText(i, 'cf.gone', registry: _registry), isNull);
  });

  test('sort: text case-insensitive, numeric, bool false first, nulls last', () {
    final items = [
      _item(1, tag: 'b', qty: 10, wish: true),
      _item(2, tag: 'A', qty: 9, wish: false),
      _item(3),
      _item(4, tag: 'c', qty: 100, wish: false),
    ];
    List<int> s(String k, bool asc) =>
        _order(sortItems(items, customId(k), asc, registry: _registry));
    expect(s('tag', true), [2, 1, 4, 3]);
    expect(s('tag', false), [4, 1, 2, 3]);
    expect(s('qty', true), [2, 1, 4, 3]);
    expect(s('qty', false), [4, 1, 2, 3]);
    expect(s('wish', true), [2, 4, 1, 3]);
    expect(s('wish', false), [1, 2, 4, 3]);
  });

  test('sort: real compares numerically', () {
    final items = [_item(1, cost: 10), _item(2, cost: 9.5)];
    expect(_order(sortItems(items, 'cf.cost', true, registry: _registry)), [2, 1]);
  });

  test('sort: removed and unknown keys leave the order unchanged', () {
    final items = [_item(2, when: DateTime(2026)), _item(1, when: DateTime(2025))];
    for (final k in ['cf.gone', 'bogus']) {
      expect(_order(sortItems(items, k, true, registry: _registry)), [2, 1]);
    }
  });

  test('parseColumnIds keeps declared custom ids and skips removed ones', () {
    expect(
      parseColumnIds('["name","cf.qty","cf.gone","bogus","cf.qty"]', ['value'],
          registry: _registry),
      ['name', 'cf.qty'],
    );
    expect(parseColumnIds('["cf.gone"]', ['value'], registry: _registry), ['value']);
    expect(parseColumnIds('["cf.qty"]', ['value'], registry: const []), ['value']);
  });

  testWidgets('choosing a custom column shows its label: value cell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Tall surface so every dialog row, custom ones last, is on screen.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = _item(1, qty: 7);
    var cols = ['name', 'extra', 'value'];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Column(children: [
            ItemListStrip(
              prefsKeyPrefix: 't',
              filtered: [item],
              whole: [item],
              sortKey: 'name',
              ascending: true,
              onChanged: (k, a) {},
              columns: cols,
              defaultColumns: const ['name', 'extra', 'value'],
              onColumnsChanged: (c) => setState(() => cols = c),
              registry: _registry,
            ),
            ItemRow(item: item, columns: cols, registry: _registry),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('qty: 7'), findsNothing);
    await tester.tap(find.byKey(const Key('columns-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'qty'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('qty: 7'), findsOneWidget);
  });
}
