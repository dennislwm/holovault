import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/override_convert.dart';

import '../tool/generate_overrides_schema.dart';

Map<String, dynamic> _e(int id, String name, String type) =>
    {'id': id, 'name': name, 'type': type};

const _types = ['text', 'choice', 'bool', 'int', 'real', 'date'];

// REQ-055 (b), written out here independently of the generator's table.
const _lossless = <String, Set<String>>{
  'bool': {'text', 'choice', 'int', 'real'},
  'int': {'text', 'choice', 'real'},
  'real': {'text', 'choice'},
  'date': {'text', 'choice'},
};

OverrideStep _retype(int id, String from, String to, {bool clear = false}) =>
    (id: id, kind: 'retype', type: to, from: from, clear: clear);

void main() {
  group('REQ-055 the type-change pair table', () {
    Map<String, dynamic> plan(String from, String to, {Set<int> accept = const {}}) =>
        planSnapshot(
          [_e(1, 'a', to)],
          planSnapshot([_e(1, 'a', from)], null),
          accept: accept,
        );

    test('every pair: swap and lossless pairs pass, all others are refused', () {
      for (final from in _types) {
        for (final to in _types.where((t) => t != from)) {
          final swap = {'text', 'choice'}.containsAll([from, to]);
          final lossless = _lossless[from]?.contains(to) ?? false;
          if (swap) {
            final p = plan(from, to);
            expect(p['steps'], isEmpty, reason: '$from to $to');
            expect(p['counter'], 0, reason: '$from to $to');
          } else if (lossless) {
            final p = plan(from, to);
            expect(p['steps'], [
              {'id': 1, 'kind': 'retype', 'from': from, 'to': to, 'clear': false},
            ], reason: '$from to $to');
            expect(p['counter'], 1, reason: '$from to $to');
          } else {
            expect(() => plan(from, to), throwsArgumentError, reason: '$from to $to');
          }
        }
      }
    });

    test('the refusal names the id, both types and the flag', () {
      expect(
        () => plan('text', 'int'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('id 1'), contains('text to int'), contains('--accept 1')),
          ),
        ),
      );
    });

    test('--accept turns a refused change into a retype that clears', () {
      final p = plan('text', 'int', accept: {1});
      expect(p['steps'], [
        {'id': 1, 'kind': 'retype', 'from': 'text', 'to': 'int', 'clear': true},
      ]);
      expect(p['counter'], 1);
      expect((p['columns'] as Map)['1'], {'name': 'a', 'type': 'int'});
    });

    test('--accept on a change that needs none, or on no change, is an error', () {
      expect(() => plan('int', 'real', accept: {1}), throwsArgumentError);
      expect(() => plan('text', 'text', accept: {1}), throwsArgumentError);
      expect(() => plan('text', 'int', accept: {1, 9}), throwsArgumentError);
    });

    test('--accept lets an id edit through as a new, empty field', () {
      final base = planSnapshot([_e(1, 'a', 'text'), _e(2, 'b', 'real')], null);
      final entries = [_e(1, 'a', 'text'), _e(100, 'b', 'real')];
      expect(() => planSnapshot(entries, base), throwsArgumentError);
      final p = planSnapshot(entries, base, accept: {100});
      expect(p['steps'], [
        {'id': 100, 'kind': 'add', 'type': 'real'},
      ]);
      expect(p['removed'], {'2': {'name': 'b', 'type': 'real'}});
    });

    test('a removed id added back with a lossless type is a retype from its removed type', () {
      final base = planSnapshot([_e(1, 'a', 'text'), _e(2, 'b', 'int')], null);
      final removed = planSnapshot([_e(1, 'a', 'text')], base);
      final back = planSnapshot([_e(1, 'a', 'text'), _e(2, 'b', 'real')], removed);
      expect(back['steps'], [
        {'id': 2, 'kind': 'retype', 'from': 'int', 'to': 'real', 'clear': false},
      ]);
      expect(back['removed'], isEmpty);
    });

    test('a refused change writes no step: the previous snapshot is untouched', () {
      final base = planSnapshot([_e(1, 'a', 'text')], null);
      expect(() => planSnapshot([_e(1, 'a', 'int')], base), throwsArgumentError);
      expect(base['steps'], isEmpty);
      expect((base['columns'] as Map)['1'], {'name': 'a', 'type': 'text'});
    });

    test('a retype step is generated with its from type and clear flag', () {
      final entries = [_e(1, 'a', 'text'), _e(2, 'b', 'int')];
      final base = planSnapshot([_e(1, 'a', 'text'), _e(2, 'b', 'real')], null);
      final cleared = generateOverridesSchema(
        entries,
        planSnapshot(entries, base, accept: {2}),
      );
      expect(cleared, contains("(id: 2, kind: 'retype', type: 'int', from: 'real', clear: true),"));
      expect(cleared, contains('const overrideCounter = 1;'));

      final widened = [_e(1, 'a', 'text'), _e(2, 'b', 'real')];
      final from = planSnapshot([_e(1, 'a', 'text'), _e(2, 'b', 'int')], null);
      final kept = generateOverridesSchema(widened, planSnapshot(widened, from));
      expect(kept, contains("(id: 2, kind: 'retype', type: 'real', from: 'int', clear: false),"));
    });
  });

  group('REQ-055 --accept on the command line', () {
    test('parses repeated ids; anything else is an error', () {
      expect(parseAccept([]), isEmpty);
      expect(parseAccept(['--accept', '3', '--accept', '5']), {3, 5});
      for (final bad in [
        ['--accept'],
        ['--accept', 'x'],
        ['--accept', '0'],
        ['--bogus'],
        ['3'],
      ]) {
        expect(() => parseAccept(bad), throwsArgumentError, reason: '$bad');
      }
    });
  });

  group('REQ-055 value conversion', () {
    test('each lossless pair converts as the REQ says', () {
      final local = DateTime(2026, 2, 3, 23, 30);
      final secs = local.millisecondsSinceEpoch ~/ 1000;
      final cases = <(Object, String, String, Object)>[
        (1, 'bool', 'text', 'true'),
        (0, 'bool', 'choice', 'false'),
        (1, 'bool', 'int', 1),
        (0, 'bool', 'int', 0),
        (1, 'bool', 'real', 1.0),
        (0, 'bool', 'real', 0.0),
        (7, 'int', 'text', '7'),
        (-7, 'int', 'choice', '-7'),
        (7, 'int', 'real', 7.0),
        (3.0, 'real', 'text', '3.0'),
        (1.5, 'real', 'choice', '1.5'),
        (secs, 'date', 'text', '2026-02-03'),
        (secs, 'date', 'choice', '2026-02-03'),
      ];
      for (final (v, from, to, want) in cases) {
        final got = convertOverrideValue(v, from, to);
        expect(got, want, reason: '$from $v to $to');
        expect(got.runtimeType, want.runtimeType, reason: '$from $v to $to');
      }
    });

    test('null stays null; a wrong-shaped value or a refused pair throws', () {
      expect(convertOverrideValue(null, 'int', 'real'), isNull);
      expect(() => convertOverrideValue(5, 'bool', 'int'), throwsStateError);
      expect(() => convertOverrideValue('x', 'int', 'real'), throwsStateError);
      expect(() => convertOverrideValue('x', 'text', 'int'), throwsStateError);
    });
  });

  group('REQ-055 retype and clear on a real store', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('holovault_retype');
      file = File('${dir.path}/t.sqlite');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    AppDatabase open() => AppDatabase.withExecutor(NativeDatabase(file));

    Future<Map<String, Object?>> row(AppDatabase db, String id) async =>
        (await db
                .customSelect(
                  "SELECT * FROM collection_item_overrides WHERE imported_id = '$id'",
                )
                .getSingle())
            .data;

    Future<Map<String, String>> columns(AppDatabase db) async => {
          for (final r in await db.customSelect('PRAGMA table_info(collection_item_overrides)').get())
            r.read<String>('name'): r.read<String>('type'),
        };

    Future<Object?> counter(AppDatabase db) async =>
        (await db.customSelect('SELECT value FROM override_counter').getSingle()).data['value'];

    test('a converting retype changes the column, keeps the other fields, rebuilds the view', () async {
      final db = open();
      await db.saveCustomFields('c1', {'serialNo': 'S1', 'addCost': 12.5});
      await db.saveCustomFields('c2', {'addCost': 3.0});
      await db.replayOverrideSteps(from: 0, target: 1, steps: [_retype(3, 'real', 'text')]);
      expect((await columns(db))['cf3'], 'TEXT');
      expect((await columns(db)).keys, isNot(contains('cf3_new')));
      expect((await row(db, 'c1'))['cf3'], '12.5');
      expect((await row(db, 'c2'))['cf3'], '3.0');
      expect((await row(db, 'c1'))['cf1'], 'S1');
      expect(await db.customSelect('SELECT imported_id FROM merged_items').get(), isEmpty);
      expect(await counter(db), 1);
      await db.close();
    });

    test('a null stays null; a date becomes its local day', () async {
      final db = open();
      await db.saveCustomFields('c1', {'eventDate': DateTime(2026, 2, 3, 23, 30)});
      await db.saveCustomFields('c2', {'serialNo': 'only'});
      await db.replayOverrideSteps(from: 0, target: 1, steps: [_retype(5, 'date', 'text')]);
      expect((await row(db, 'c1'))['cf5'], '2026-02-03');
      expect((await row(db, 'c2'))['cf5'], isNull);
      await db.close();
    });

    test('a clearing retype empties the field and keeps the others', () async {
      final db = open();
      await db.saveCustomFields('c1', {'serialNo': 'S1', 'addCost': 12.5});
      await db.replayOverrideSteps(
        from: 0,
        target: 1,
        steps: [_retype(3, 'real', 'int', clear: true)],
      );
      expect((await columns(db))['cf3'], 'INTEGER');
      expect((await row(db, 'c1'))['cf3'], isNull);
      expect((await row(db, 'c1'))['cf1'], 'S1');
      await db.close();
    });

    test('bool to int drops the 0-or-1 check, so a new int value fits', () async {
      final db = open();
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement(
        'ALTER TABLE collection_item_overrides ADD COLUMN cf7 INTEGER CHECK (cf7 IN (0, 1))',
      );
      await db.customStatement("INSERT INTO collection_item_overrides (imported_id, cf7) VALUES ('c1', 1)");
      await db.customStatement("INSERT INTO collection_item_overrides (imported_id, cf7) VALUES ('c2', 0)");
      await db.replayOverrideSteps(from: 0, target: 1, steps: [_retype(7, 'bool', 'int')]);
      expect((await row(db, 'c1'))['cf7'], 1);
      expect((await row(db, 'c2'))['cf7'], 0);
      await db.customStatement("UPDATE collection_item_overrides SET cf7 = 5 WHERE imported_id = 'c1'");
      expect((await row(db, 'c1'))['cf7'], 5);
      await db.close();
    });

    test('a clearing retype to bool gives a column that holds only 0, 1 or null', () async {
      final db = open();
      await db.saveCustomFields('c1', {'serialNo': 'S1'});
      await db.replayOverrideSteps(
        from: 0,
        target: 1,
        steps: [_retype(1, 'text', 'bool', clear: true)],
      );
      expect((await columns(db))['cf1'], 'INTEGER');
      expect((await row(db, 'c1'))['cf1'], isNull);
      await db.customStatement("UPDATE collection_item_overrides SET cf1 = 1 WHERE imported_id = 'c1'");
      await expectLater(
        db.customStatement("UPDATE collection_item_overrides SET cf1 = 5 WHERE imported_id = 'c1'"),
        throwsA(anything),
      );
      await db.close();
    });

    test('two steps on one id in one replay chain: bool to int to real', () async {
      final db = open();
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement(
        'ALTER TABLE collection_item_overrides ADD COLUMN cf7 INTEGER CHECK (cf7 IN (0, 1))',
      );
      await db.customStatement("INSERT INTO collection_item_overrides (imported_id, cf7) VALUES ('c1', 1)");
      await db.customStatement("INSERT INTO collection_item_overrides (imported_id, cf7) VALUES ('c2', 0)");
      await db.replayOverrideSteps(
        from: 0,
        target: 2,
        steps: [_retype(7, 'bool', 'int'), _retype(7, 'int', 'real')],
      );
      expect((await columns(db))['cf7'], 'REAL');
      expect((await row(db, 'c1'))['cf7'], 1.0);
      expect((await row(db, 'c2'))['cf7'], 0.0);
      expect(await counter(db), 2);
      await db.close();
    });

    test('a value that cannot convert rolls the whole step back', () async {
      final db = open();
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('ALTER TABLE collection_item_overrides ADD COLUMN cf7 INTEGER');
      await db.customStatement("INSERT INTO collection_item_overrides (imported_id, cf7) VALUES ('c1', 5)");
      await expectLater(
        db.replayOverrideSteps(from: 0, target: 1, steps: [_retype(7, 'bool', 'int')]),
        throwsA(isA<StateError>()),
      );
      expect((await columns(db)).keys, contains('cf7'));
      expect((await columns(db)).keys, isNot(contains('cf7_new')));
      expect((await row(db, 'c1'))['cf7'], 5);
      expect(await counter(db), 0);
      await db.close();
    });

    test('a retype of a missing column fails loudly and changes nothing', () async {
      final db = open();
      await expectLater(
        db.replayOverrideSteps(from: 0, target: 1, steps: [_retype(99, 'int', 'real')]),
        throwsA(isA<StateError>()),
      );
      expect(await counter(db), 0);
      await db.close();
    });
  });
}
