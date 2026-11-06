import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/widgets/search_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-043 (e): a registry holding every type, reading existing MergedItem
/// fields so no overrides table is needed.
final registry = <CustomColumn>[
  CustomColumn('txt', CustomColumnType.text, (r) => r.serialNo, (t) => t.serialNo),
  CustomColumn('pick', CustomColumnType.choice, (r) => r.preGrade, (t) => t.preGrade),
  CustomColumn('whole', CustomColumnType.int, (r) => r.quantity, (t) => t.serialNo),
  CustomColumn('dec', CustomColumnType.real, (r) => r.addCost, (t) => t.addCost),
  CustomColumn('flag', CustomColumnType.bool, (r) => r.groupWishlist, (t) => t.serialNo),
  CustomColumn('when', CustomColumnType.date, (r) => r.dateAdded, (t) => t.serialNo),
];

MergedItem item(String name, {String? txt, String? pick, int? whole, double? dec}) =>
    MergedItem(
      id: 1,
      importedId: name,
      name: name,
      serialNo: txt,
      preGrade: pick,
      quantity: whole,
      addCost: dec,
    );

Future<List<String>> names(List<MergedItem> items, SearchClause c) async {
  final r = await filterCollectionItems(
    items,
    searchTerm: '',
    clauses: [c],
    registry: registry,
  );
  return r.map((i) => i.name).toList();
}

SearchClause cc(String name, SearchOperator op, String v) =>
    SearchClause.custom(customFieldId: customId(name), op: op, value: v);

void main() {
  final items = [
    item('a', txt: 'X1', pick: 'NM', whole: 2, dec: 1.5),
    item('b', txt: 'X2', pick: 'LP', whole: 5, dec: 9.0),
    item('c'),
  ];

  test('custom text and choice clauses use = and != on the value; null never matches', () async {
    expect(await names(items, cc('txt', SearchOperator.equal, 'X1')), ['a']);
    expect(await names(items, cc('pick', SearchOperator.notEqual, 'NM')), ['b']);
  });

  test('custom int and real clauses compare numerically; null never matches', () async {
    expect(await names(items, cc('whole', SearchOperator.greaterThan, '3')), ['b']);
    expect(await names(items, cc('dec', SearchOperator.lessThanOrEqual, '1.5')), ['a']);
    expect(await names(items, cc('dec', SearchOperator.notEqual, '1.5')), ['b']);
  });

  test('a clause with a custom id round-trips through JSON; built-ins keep their name', () {
    final c = cc('pick', SearchOperator.equal, 'NM');
    final back = SearchClause.tryFromJson(
      jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
      registry,
    )!;
    expect(back.customFieldId, 'cf.pick');
    expect(back.field, isNull);
    expect(back.value, 'NM');
    expect(
      const SearchClause(field: SearchField.rarity, op: SearchOperator.equal, value: 'x').toJson()['field'],
      'rarity',
    );
  });

  test('a clause or preset naming a removed custom id is skipped, others load', () {
    final gone = {'field': 'cf.gone', 'op': 'equal', 'value': 'x'};
    final ok = {'field': 'cf.pick', 'op': 'equal', 'value': 'NM'};
    final builtIn = {'field': 'rarity', 'op': 'equal', 'value': 'Holo'};
    expect(SearchClause.tryFromJson(gone, registry), isNull);
    expect(SearchClause.tryFromJson(ok, registry), isNotNull);
    expect(SearchClause.tryFromJson(builtIn, registry), isNotNull);
    Map<String, dynamic> preset(String n, List<Map<String, String>> cs) =>
        {'name': n, 'searchTerm': '', 'clauses': cs};
    expect(FilterPreset.tryFromJson(preset('p', [ok, gone]), registry), isNull);
    final loaded = FilterPreset.tryFromJson(preset('q', [ok, builtIn]), registry)!;
    expect(loaded.clauses.length, 2);
  });

  test('picker lists built-ins then declared custom fields, without bool and date', () {
    final ids = pickerFieldIds(const [], registry);
    expect(ids.take(SearchField.values.length), [for (final f in SearchField.values) f.name]);
    expect(ids.skip(SearchField.values.length), ['cf.txt', 'cf.pick', 'cf.whole', 'cf.dec']);
    expect(pickerFieldLabel('cf.pick', registry), 'pick (choice)');
    expect(pickerFieldLabel('rarity', registry), 'Rarity');
    expect(operatorsForId('cf.pick', registry).length, 2);
    expect(operatorsForId('cf.dec', registry), SearchOperator.values);
    expect(distinctValuesForId('cf.pick', items, registry), ['LP', 'NM']);
  });

  testWidgets('adding a clause on a custom field narrows the list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var shown = items;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilterBar(
            prefsKeyPrefix: 't',
            items: items,
            registry: registry,
            onFiltered: (f) => shown = f,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add clause'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field').last);
    await tester.pumpAndSettle();
    // 11 built-ins come first: the custom entry is below the fold of the menu.
    await tester.scrollUntilVisible(
      find.text('pick (choice)'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('pick (choice)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('=').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Value').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NM').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(shown.map((i) => i.name), ['a']);
    expect(find.text('pick = NM'), findsOneWidget);
  });
}
