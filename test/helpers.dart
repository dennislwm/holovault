import 'package:drift/drift.dart' show DriftSqlType, GeneratedColumn, TypeConverter, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/database/overrides_schema.dart';
import 'package:holovault/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IntAsReal extends TypeConverter<int?, double?> {
  const _IntAsReal();

  @override
  int? fromSql(double? fromDb) => fromDb?.toInt();

  @override
  double? toSql(int? value) => value?.toDouble();
}

class _BoolAsText extends TypeConverter<bool?, String?> {
  const _BoolAsText();

  @override
  bool? fromSql(String? fromDb) => fromDb == null ? null : fromDb == '1';

  @override
  String? toSql(bool? value) => value == null ? null : value ? '1' : '0';
}

/// A fixed custom-field config for tests, independent of the app's real
/// generated config. Values come from stable built-in merged-item fields.
final testCustomColumns = <CustomColumn>[
  (
    id: null,
    name: 'testText',
    type: CustomColumnType.text,
    value: (r) => r.tag,
    column: (t) => GeneratedColumn<String>('cf1', t.aliasedName, true, type: DriftSqlType.string)
  ),
  (
    id: null,
    name: 'testChoice',
    type: CustomColumnType.choice,
    value: (r) => r.gradeSubtype,
    column: (t) => GeneratedColumn<String>('cf2', t.aliasedName, true, type: DriftSqlType.string)
  ),
  (
    id: null,
    name: 'testInteger',
    type: CustomColumnType.int,
    value: (r) => r.quantity,
    column: (t) => GeneratedColumn<double>('cf4', t.aliasedName, true, type: DriftSqlType.double)
        .withConverter<int?>(const _IntAsReal())
  ),
  (
    id: null,
    name: 'testReal',
    type: CustomColumnType.real,
    value: (r) => r.paidTotal,
    column: (t) => GeneratedColumn<double>('cf3', t.aliasedName, true, type: DriftSqlType.double)
  ),
  (
    id: null,
    name: 'testBool',
    type: CustomColumnType.bool,
    value: (r) => r.groupWishlist,
    column: (t) => GeneratedColumn<String>('cf6', t.aliasedName, true, type: DriftSqlType.string)
        .withConverter<bool?>(const _BoolAsText())
  ),
  (
    id: null,
    name: 'testDate',
    type: CustomColumnType.date,
    value: (r) => r.dateAdded,
    column: (t) => GeneratedColumn<DateTime>('cf5', t.aliasedName, true, type: DriftSqlType.dateTime)
  ),
];

typedef LiveFieldSample = ({
  CustomColumn column,
  String sqlName,
  Object value,
});

Object sampleCustomValue(CustomColumnType type, {int variant = 0}) => switch (type) {
  CustomColumnType.text => variant == 0 ? 'Fixture text' : 'Changed text',
  CustomColumnType.choice => variant == 0 ? 'Fixture choice' : 'Changed choice',
  CustomColumnType.int => variant == 0 ? 7 : 11,
  CustomColumnType.real => variant == 0 ? 1.5 : 2.5,
  CustomColumnType.bool => variant == 0 ? false : true,
  CustomColumnType.date => variant == 0
      ? DateTime(2026, 2, 3, 4, 5)
      : DateTime(2026, 11, 6, 13, 45, 30),
};

Map<CustomColumnType, LiveFieldSample>? liveFieldsOrSkip(
  AppDatabase db,
  Set<CustomColumnType> required, {
  required String testName,
  int variant = 0,
}) {
  final out = <CustomColumnType, LiveFieldSample>{};
  for (final type in required) {
    CustomColumn? selected;
    for (final column in customColumns) {
      if (column.type == type) {
        selected = column;
        break;
      }
    }
    if (selected == null) {
      markTestSkipped('REQ-057 SKIP: $testName requires a live ${type.name} field');
      return null;
    }
    expect(selected, isNotNull);
    expect(selected.type, type);
    expect(selected.id, isNotNull);
    final sqlName = selected.column(db.collectionItemOverrides).name;
    expect(sqlName, 'cf${selected.id}');
    out[type] = (
      column: selected,
      sqlName: sqlName,
      value: sampleCustomValue(type, variant: variant),
    );
  }
  return out;
}

LiveFieldSample? firstLiveFieldOrSkip(
  AppDatabase db, {
  required String testName,
}) {
  CustomColumn? first;
  for (final column in customColumns) {
    first = column;
    break;
  }
  if (first == null) {
    markTestSkipped('REQ-057 SKIP: $testName requires at least one live field');
    return null;
  }
  return liveFieldsOrSkip(db, {first.type}, testName: testName)?[first.type];
}

/// Owns an in-memory database per test. Construct inside `main()` so the
/// `setUp` registers while the file's tests are declared.
class DbFixture {
  late AppDatabase db;

  DbFixture() {
    setUp(() {
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
    });
  }
}

/// Adds the preferences reset and the screen pumps widget tests share.
class WidgetFixture extends DbFixture {
  WidgetFixture() {
    // ADR-15: ValueTrendScreen mounts eagerly inside HolovaultShell, so its
    // SharedPreferences.getInstance() runs even on Collection-only tests.
    setUp(() => SharedPreferences.setMockInitialValues({}));
  }

  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(HolovaultApp(database: db));
    await tester.pumpAndSettle();
  }
}

Future<void> disposeAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// REQ-034 (ADR-19): drives the shared clause-builder bottom sheet
/// (`SearchFilterBar`'s `showAddClauseSheet`): field, then operator, then
/// value, then Add. `scroll` first scrolls the Field menu to [field], for
/// custom fields that sit below the built-ins' fold.
Future<void> addClause(
  WidgetTester tester, {
  required String field,
  required String op,
  required String value,
  bool scroll = false,
}) async {
  await tester.tap(find.text('Add clause'));
  await tester.pumpAndSettle();
  // .last on each label -- the bottom sheet renders on top of (after) any
  // same-named Text already in the screen behind it (e.g. BestReturnsScreen's
  // "Value" DataColumn header), so the sheet's own label is always the last
  // match in tree order.
  await tester.tap(find.text('Field').last);
  await tester.pumpAndSettle();
  if (scroll) {
    await tester.scrollUntilVisible(
      find.text(field),
      100,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.tap(find.text(field).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Operator').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(op).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Value').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add').last);
  await tester.pumpAndSettle();
}

Value<T> _v<T extends Object>(T? x) =>
    x == null ? const Value.absent() : Value(x);

/// Upserts one collection item with plain (unwrapped) values; an omitted
/// field is left absent, exactly as `CollectionItemsCompanion.insert` does.
// ponytail: only the columns tests set so far; add a parameter when a test needs one.
Future<void> seedItem(
  AppDatabase db, {
  required String importedId,
  required String name,
  String? setName,
  String? discriminator,
  String? rarity,
  int? quantity,
  double? valueTotal,
  double? valuePerUnit,
  double? paidTotal,
  double? paidPerUnit,
  String? gradeType,
  String? gradeSubtype,
  DateTime? dateAdded,
}) =>
    db.upsertItem(
      CollectionItemsCompanion.insert(
        importedId: importedId,
        name: name,
        setName: _v(setName),
        discriminator: _v(discriminator),
        rarity: _v(rarity),
        quantity: _v(quantity),
        valueTotal: _v(valueTotal),
        valuePerUnit: _v(valuePerUnit),
        paidTotal: _v(paidTotal),
        paidPerUnit: _v(paidPerUnit),
        gradeType: _v(gradeType),
        gradeSubtype: _v(gradeSubtype),
        dateAdded: _v(dateAdded),
      ),
    );
