import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/widgets/item_list_strip.dart';
import 'package:holovault/widgets/item_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

final _registry = testCustomColumns;

MergedItem _item(int id,
        {String? tag, int? qty, double? cost, bool? wish, DateTime? when}) =>
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
    expect(customId('testInteger'), 'cf.testInteger');
    expect(customColumnFor('cf.testInteger', _registry)?.name, 'testInteger');
    expect(customColumnFor('cf.gone', _registry), isNull);
    expect(customColumnFor('testInteger', _registry), isNull);
    expect(sortKeyLabel('cf.testReal', _registry), 'testReal');
    expect(sortKeyLabel('cf.gone', _registry), 'cf.gone');
    expect(sortKeyLabel('bogus', _registry), 'bogus');
    expect(sortKeyLabel('value', _registry), 'Value');
  });

  test('column and sort id lists: built-ins first, dates sortable (f)', () {
    final cols = columnIdsFor(_registry);
    expect(cols.sublist(0, sortKeyIds.length), sortKeyIds);
    expect(cols.sublist(sortKeyIds.length).first, 'cf.testText');
    expect(cols, contains('cf.testDate'));
    expect(sortableIdsFor(_registry), contains('cf.testDate'));
    expect(sortableIdsFor(_registry), contains('cf.testBool'));
  });

  test('cell text per type; date is the calendar date only', () {
    final i = _item(1,
        tag: 'x',
        qty: 3,
        cost: 2.5,
        wish: false,
        when: DateTime(2026, 3, 7, 23, 59));
    String? t(String n) => cellText(i, customId(n), registry: _registry);
    expect(t('testText'), 'x');
    expect(t('testInteger'), '3');
    expect(t('testReal'), '2.5');
    expect(t('testBool'), 'No');
    expect(t('testDate'), '2026-03-07');
    expect(t('testChoice'), isNull);
    expect(cellText(i, 'cf.gone', registry: _registry), isNull);
  });

  test('sort: text case-insensitive, numeric, bool false first, nulls last',
      () {
    final items = [
      _item(1, tag: 'b', qty: 10, wish: true),
      _item(2, tag: 'A', qty: 9, wish: false),
      _item(3),
      _item(4, tag: 'c', qty: 100, wish: false),
    ];
    List<int> s(String k, bool asc) =>
        _order(sortItems(items, customId(k), asc, registry: _registry));
    expect(s('testText', true), [2, 1, 4, 3]);
    expect(s('testText', false), [4, 1, 2, 3]);
    expect(s('testInteger', true), [2, 1, 4, 3]);
    expect(s('testInteger', false), [4, 1, 2, 3]);
    expect(s('testBool', true), [2, 4, 1, 3]);
    expect(s('testBool', false), [1, 2, 4, 3]);
  });

  test('sort: removed and unknown keys leave the order unchanged', () {
    final items = [
      _item(2, when: DateTime(2026)),
      _item(1, when: DateTime(2025))
    ];
    for (final k in ['cf.gone', 'bogus']) {
      expect(_order(sortItems(items, k, true, registry: _registry)), [2, 1]);
    }
  });

  test('parseColumnIds keeps declared custom ids and skips removed ones', () {
    expect(
      parseColumnIds(
          '["name","cf.testInteger","cf.gone","bogus","cf.testInteger"]',
          ['value'],
          registry: _registry),
      ['name', 'cf.testInteger'],
    );
    expect(parseColumnIds('["cf.gone"]', ['value'], registry: _registry),
        ['value']);
    expect(parseColumnIds('["cf.testInteger"]', ['value'], registry: const []),
        ['value']);
  });

  // REQ-045 (iv): mounts a strip over stored prefs; returns what it reported.
  Future<({List<(String, bool)> sorts, List<List<String>> cols})> mountStrip(
    WidgetTester tester,
    Map<String, Object> stored,
  ) async {
    SharedPreferences.setMockInitialValues(stored);
    final sorts = <(String, bool)>[];
    final cols = <List<String>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ItemListStrip(
          prefsKeyPrefix: 't',
          filtered: const [],
          whole: const [],
          sortKey: 'name',
          ascending: true,
          onChanged: (k, a) => sorts.add((k, a)),
          columns: const ['value'],
          defaultColumns: const ['value'],
          onColumnsChanged: cols.add,
          registry: _registry,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (sorts: sorts, cols: cols);
  }

  testWidgets(
      'REQ-045 (iv): a stored custom column and sort key are restored on mount',
      (
    tester,
  ) async {
    final r = await mountStrip(tester, {
      't_sort_key': 'cf.testInteger',
      't_sort_asc': false,
      't_columns': '["name","cf.testInteger"]',
    });
    expect(r.sorts, [('cf.testInteger', false)]);
    expect(r.cols, [
      ['name', 'cf.testInteger'],
    ]);
  });

  testWidgets(
      'REQ-045 (iv): a stored removed custom sort id keeps the host initial value',
      (
    tester,
  ) async {
    final r = await mountStrip(tester, {
      't_sort_key': 'cf.gone',
      't_sort_asc': false,
    });
    expect(r.sorts, isEmpty);
  });

  testWidgets('choosing a custom column shows its label: value cell',
      (tester) async {
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
    expect(find.text('testInteger: 7'), findsNothing);
    await tester.tap(find.byKey(const Key('columns-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'testInteger'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('testInteger: 7'), findsOneWidget);
  });
}
