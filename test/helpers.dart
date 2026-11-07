import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Value<T> _v<T extends Object>(T? x) => x == null ? const Value.absent() : Value(x);

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
}) => db.upsertItem(
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
