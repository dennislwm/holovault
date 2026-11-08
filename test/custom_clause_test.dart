import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/widgets/search_filter_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// REQ-043 (e): a registry holding every type, reading existing MergedItem
/// fields so no overrides table is needed.
final registry = <CustomColumn>[
  (id: null, name: 'txt', type: CustomColumnType.text, value: (r) => r.serialNo, column: (t) => t.serialNo),
  (id: null, name: 'pick', type: CustomColumnType.choice, value: (r) => r.preGrade, column: (t) => t.preGrade),
  (id: null, name: 'whole', type: CustomColumnType.int, value: (r) => r.quantity, column: (t) => t.serialNo),
  (id: null, name: 'dec', type: CustomColumnType.real, value: (r) => r.addCost, column: (t) => t.addCost),
  (id: null, name: 'flag', type: CustomColumnType.bool, value: (r) => r.groupWishlist, column: (t) => t.serialNo),
  (id: null, name: 'when', type: CustomColumnType.date, value: (r) => r.dateAdded, column: (t) => t.serialNo),
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

  test('picker lists built-ins then custom fields (bool included) then date fields', () {
    final ids = pickerFieldIds(const [], registry);
    expect(ids.take(SearchField.values.length), [for (final f in SearchField.values) f.name]);
    expect(
      ids.skip(SearchField.values.length),
      ['cf.txt', 'cf.pick', 'cf.whole', 'cf.dec', 'cf.flag', 'cf.when'],
    );
    expect(pickerFieldLabel('cf.flag', registry), 'flag (bool)');
    expect(pickerFieldLabel('cf.when', registry), 'when (date)');
    expect(operatorsForId('cf.when', registry), SearchOperator.values);
    expect(pickerFieldLabel('cf.pick', registry), 'pick (choice)');
    expect(pickerFieldLabel('rarity', registry), 'Rarity');
    expect(operatorsForId('cf.pick', registry).length, 2);
    expect(operatorsForId('cf.dec', registry), SearchOperator.values);
    expect(distinctValuesForId('cf.pick', items, registry), ['LP', 'NM']);
  });

  group('bool fields (REQ-046)', () {
    MergedItem w(String name, bool? v) =>
        MergedItem(id: 1, importedId: name, name: name, groupWishlist: v);
    final bools = [w('yes', true), w('no', false), w('none', null)];
    Future<List<String>> hit(SearchOperator op, String v) => names(bools, cc('flag', op, v));

    test('= and != compare the bool; null never matches, not even !=', () async {
      expect(await hit(SearchOperator.equal, 'true'), ['yes']);
      expect(await hit(SearchOperator.equal, 'false'), ['no']);
      expect(await hit(SearchOperator.notEqual, 'true'), ['no']);
      expect(await hit(SearchOperator.notEqual, 'false'), ['yes']);
    });

    test('a clause value other than true or false never matches or throws', () async {
      for (final v in ['', 'TRUE', '1', 'yes', 'true ']) {
        for (final op in SearchOperator.values) {
          expect(await hit(op, v), isEmpty, reason: '$op "$v"');
        }
      }
    });

    test('operators are = and != only; values are fixed; JSON keeps the text', () {
      expect(operatorsForId('cf.flag', registry), [SearchOperator.equal, SearchOperator.notEqual]);
      expect(distinctValuesForId('cf.flag', [w('yes', true)], registry), ['true', 'false']);
      final back = SearchClause.tryFromJson(
        jsonDecode(jsonEncode(cc('flag', SearchOperator.equal, 'true').toJson()))
            as Map<String, dynamic>,
        registry,
      )!;
      expect(back.value, 'true');
      expect(back.customFieldId, 'cf.flag');
    });
  });

  group('date fields (f)', () {
    MergedItem at(String name, DateTime? d) => MergedItem(
          id: 1,
          importedId: name,
          name: name,
          dateAdded: d,
        );
    final days = [
      at('prev', DateTime(2025, 5, 31, 23, 59)),
      at('start', DateTime(2025, 6, 1, 0, 0)),
      at('end', DateTime(2025, 6, 1, 23, 59)),
      at('next', DateTime(2025, 6, 2, 0, 0)),
      at('none', null),
    ];
    Future<List<String>> hit(SearchOperator op, String v) => names(days, cc('when', op, v));

    test('every operator compares calendar days, never time of day', () async {
      expect(await hit(SearchOperator.equal, '2025-06-01'), ['start', 'end']);
      expect(await hit(SearchOperator.notEqual, '2025-06-01'), ['prev', 'next']);
      expect(await hit(SearchOperator.greaterThan, '2025-06-01'), ['next']);
      expect(await hit(SearchOperator.greaterThanOrEqual, '2025-06-01'), ['start', 'end', 'next']);
      expect(await hit(SearchOperator.lessThan, '2025-06-01'), ['prev']);
      expect(await hit(SearchOperator.lessThanOrEqual, '2025-06-01'), ['prev', 'start', 'end']);
    });

    test('an invalid or empty clause value never matches or throws', () async {
      for (final v in ['', 'abc', '2025-6-1', '2025-02-31', '2025-06-01 10:00']) {
        for (final op in SearchOperator.values) {
          expect(await hit(op, v), isEmpty, reason: '$op "$v"');
        }
      }
    });

    test('a UTC item value is converted with toLocal before comparing', () async {
      final utc = DateTime.utc(2025, 6, 1, 23, 59);
      final local = utc.toLocal();
      final key = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(formatDay(utc), key);
      expect(await names([at('u', utc)], cc('when', SearchOperator.equal, key)), ['u']);
    });

    test('sort ignores time of day, nulls last both ways, ties stable', () {
      expect(sortableIdsFor(registry), contains('cf.when'));
      List<String> s(bool asc) =>
          sortItems(days.reversed.toList(), 'cf.when', asc, registry: registry)
              .map((i) => i.name)
              .toList();
      // 'end' and 'start' share a day: incoming (reversed) order is kept.
      expect(s(true), ['prev', 'end', 'start', 'next', 'none']);
      expect(s(false), ['next', 'end', 'start', 'prev', 'none']);
    });
  });

  testWidgets('a date clause is added through the SDK date dialog and narrows the list',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Tall surface: the date entry is the last item of the Field menu.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dated = [
      MergedItem(id: 1, importedId: 'a', name: 'a', dateAdded: DateTime(2020, 1, 1, 23, 59)),
      MergedItem(id: 2, importedId: 'b', name: 'b', dateAdded: DateTime(2020, 1, 2)),
    ];
    var shown = dated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchFilterBar(
            prefsKeyPrefix: 'd',
            items: dated,
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
    await tester.scrollUntilVisible(
      find.text('when (date)'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('when (date)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('=').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    // The dialog opens on today; type mode is a toggle in the same dialog.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '01/01/2020');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('2020-01-01'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(shown.map((i) => i.name), ['a']);
    expect(find.text('when = 2020-01-01'), findsOneWidget);
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
    // 11 built-ins come first: the custom entry is below the fold of the menu.
    await addClause(tester, field: 'pick (choice)', op: '=', value: 'NM', scroll: true);

    expect(shown.map((i) => i.name), ['a']);
    expect(find.text('pick = NM'), findsOneWidget);
  });
}
