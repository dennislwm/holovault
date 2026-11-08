import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/database/database.dart';

import '../tool/generate_overrides_schema.dart';
import 'helpers.dart';

Map<String, dynamic> _e(int id, String name, [String type = 'text']) =>
    {'id': id, 'name': name, 'type': type};

Map<String, dynamic> _plan(List<Map<String, dynamic>> entries, [Map<String, dynamic>? prev]) =>
    planSnapshot(entries, prev);

void main() {
  group('REQ-055 snapshot planning', () {
    final base = _plan([_e(1, 'a'), _e(2, 'b', 'real')]);

    test('the first run is the baseline: counter 0, no steps, no removed ids', () {
      expect(base['counter'], 0);
      expect(base['steps'], isEmpty);
      expect(base['removed'], isEmpty);
      expect(base['columns'], {
        '1': {'name': 'a', 'type': 'text'},
        '2': {'name': 'b', 'type': 'real'},
      });
    });

    test('the same config again changes nothing', () {
      expect(_plan([_e(1, 'a'), _e(2, 'b', 'real')], base), base);
    });

    test('a new id appends an add step and bumps the counter, in config order', () {
      final next = _plan([_e(1, 'a'), _e(2, 'b', 'real'), _e(9, 'z', 'date'), _e(7, 'y')], base);
      expect(next['counter'], 2);
      expect(next['steps'], [
        {'id': 9, 'kind': 'add', 'type': 'date'},
        {'id': 7, 'kind': 'add', 'type': 'text'},
      ]);
      expect((next['columns'] as Map).keys, ['1', '2', '7', '9']);
    });

    test('a rename and a text to choice swap change the snapshot only', () {
      final next = _plan([_e(1, 'renamed', 'choice'), _e(2, 'b', 'real')], base);
      expect(next['counter'], 0);
      expect(next['steps'], isEmpty);
      expect((next['columns'] as Map)['1'], {'name': 'renamed', 'type': 'choice'});
    });

    test('any other type change is refused', () {
      for (final to in ['int', 'bool', 'date', 'real']) {
        expect(
          () => _plan([_e(1, 'a', to), _e(2, 'b', 'real')], base),
          throwsArgumentError,
          reason: 'text to $to',
        );
      }
      expect(() => _plan([_e(1, 'a'), _e(2, 'b', 'int')], base), throwsArgumentError);
    });

    test('a removed id keeps its name and type, with no step and no bump', () {
      final next = _plan([_e(1, 'a')], base);
      expect(next['counter'], 0);
      expect(next['steps'], isEmpty);
      expect(next['removed'], {'2': {'name': 'b', 'type': 'real'}});
      expect((next['columns'] as Map).keys, ['1']);
    });

    test('a removed id added back with its type is restored with no step, under any name', () {
      final removed = _plan([_e(1, 'a')], base);
      final back = _plan([_e(1, 'a'), _e(2, 'other', 'real')], removed);
      expect(back['counter'], 0);
      expect(back['steps'], isEmpty);
      expect(back['removed'], isEmpty);
      expect((back['columns'] as Map)['2'], {'name': 'other', 'type': 'real'});
    });

    test('a removed id added back with another type is refused; a text/choice swap is not', () {
      final base2 = _plan([_e(1, 'a'), _e(2, 'b', 'choice')]);
      final removed = _plan([_e(1, 'a')], base2);
      expect(() => _plan([_e(1, 'a'), _e(2, 'b', 'int')], removed), throwsArgumentError);
      final swapped = _plan([_e(1, 'a'), _e(2, 'b', 'text')], removed);
      expect(swapped['steps'], isEmpty);
      expect(swapped['removed'], isEmpty);
    });

    test('an id edit is refused: a removed id and a new id with the same name and type', () {
      expect(() => _plan([_e(1, 'a'), _e(100, 'b', 'real')], base), throwsArgumentError);
      // A different type or name is a plain delete plus a new field.
      expect(_plan([_e(1, 'a'), _e(100, 'b', 'date')], base)['counter'], 1);
      expect(_plan([_e(1, 'a'), _e(100, 'c', 'real')], base)['counter'], 1);
    });

    test('delete in one run and add the same name later is allowed', () {
      final removed = _plan([_e(1, 'a')], base);
      final later = _plan([_e(1, 'a'), _e(100, 'b', 'real')], removed);
      expect(later['counter'], 1);
      expect(later['removed'], {'2': {'name': 'b', 'type': 'real'}});
    });
  });

  group('REQ-055 generated source from a snapshot', () {
    test('a removed id is an orphan column outside the registry and the view', () {
      final entries = [_e(1, 'a')];
      final snap = _plan(
        entries,
        _plan([_e(1, 'a'), _e(2, 'b', 'real')]),
      );
      final out = generateOverridesSchema(entries, snap);
      expect(out, contains("RealColumn get orphan2 => real().named('cf2')"));
      expect(out, contains('2 => t.orphan2,'));
      expect(out, isNot(contains('collectionItemOverrides.orphan2')));
      expect(out, isNot(contains("name: 'b'")));
    });

    test('the counter and steps come from the snapshot', () {
      final entries = [_e(1, 'a'), _e(3, 'c', 'date')];
      final snap = _plan(entries, _plan([_e(1, 'a')]));
      final out = generateOverridesSchema(entries, snap);
      expect(out, contains('const overrideCounter = 1;'));
      expect(out, contains("(id: 3, kind: 'add', type: 'date', from: '', clear: false),"));
    });
  });

  group('REQ-055 replay of add steps on a real store', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('holovault_replay');
      file = File('${dir.path}/t.sqlite');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    AppDatabase open() => AppDatabase.withExecutor(NativeDatabase(file));

    Future<Map<String, String>> columns(AppDatabase db) async => {
          for (final r in await db.customSelect('PRAGMA table_info(collection_item_overrides)').get())
            r.read<String>('name'): r.read<String>('type'),
        };

    /// A store as it was before cf6 was added: the column is dropped, the
    /// counter says 0, one value typed in cf1.
    Future<void> storeWithoutCf6({String? asType}) async {
      final db = open();
      await seedItem(db, importedId: 'c1', name: 'X');
      await db.saveCustomFields('c1', {'serialNo': 'S1'});
      await db.customStatement('DROP VIEW merged_items');
      await db.customStatement('ALTER TABLE collection_item_overrides DROP COLUMN cf6');
      if (asType != null) {
        await db.customStatement('ALTER TABLE collection_item_overrides ADD COLUMN cf6 $asType');
      }
      await db.customStatement('UPDATE override_counter SET value = 0');
      await db.close();
    }

    const step = [(id: 6, kind: 'add', type: 'choice', from: '', clear: false)];

    test('an add step adds the column, rebuilds the view, stores the counter, keeps values', () async {
      await storeWithoutCf6();
      final db = open();
      // beforeOpen ran with the generated counter 0, so cf6 is still missing.
      expect(await columns(db), isNot(contains('cf6')));
      await db.replayOverrideSteps(from: 0, target: 1, steps: step);
      expect((await columns(db))['cf6'], 'TEXT');
      expect(
        (await db.customSelect('SELECT value FROM override_counter').getSingle()).data['value'],
        1,
      );
      final merged = await db.mergedItemByImportedId('c1');
      expect(merged!.serialNo, 'S1');
      expect(merged.eventName, isNull);
      await db.close();
    });

    test('replaying a step whose column already exists with the same type is a no-op', () async {
      await storeWithoutCf6(asType: 'TEXT');
      final db = open();
      await db.replayOverrideSteps(from: 0, target: 1, steps: step);
      await db.replayOverrideSteps(from: 0, target: 1, steps: step);
      expect((await columns(db))['cf6'], 'TEXT');
      expect((await db.mergedItemByImportedId('c1'))!.serialNo, 'S1');
      await db.close();
    });

    test('a failing second step rolls back the first step\'s added column', () async {
      await storeWithoutCf6(asType: 'INTEGER');
      var db = open();
      await db.customStatement('ALTER TABLE collection_item_overrides DROP COLUMN cf5');
      await db.close();
      db = open();
      await expectLater(
        db.replayOverrideSteps(
          from: 0,
          target: 2,
          steps: const [
            (id: 5, kind: 'add', type: 'date', from: '', clear: false),
            (id: 6, kind: 'add', type: 'choice', from: '', clear: false),
          ],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await columns(db), isNot(contains('cf5')));
      await db.close();
    });

    test('a step whose column exists with a different type fails loudly and changes nothing', () async {
      await storeWithoutCf6(asType: 'INTEGER');
      final db = open();
      await expectLater(
        db.replayOverrideSteps(from: 0, target: 1, steps: step),
        throwsA(isA<StateError>()),
      );
      expect(
        (await db.customSelect('SELECT value FROM override_counter').getSingle()).data['value'],
        0,
      );
      await db.close();
    });
  });
}
