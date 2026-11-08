// Reads overrides_config.json (developer-declared) and writes
// lib/database/overrides_schema.dart -- a real Dart source file drift's own
// build_runner then processes, so extra columns become compile-time-known
// before drift's codegen runs (ADR-03, Option 3).
//
// Regenerate after any config change:
//   dart run tool/generate_overrides_schema.dart
//   flutter pub run build_runner build --delete-conflicting-outputs
// Or just: make gen-overrides
import 'dart:convert';
import 'dart:io';

// REQ-055: `{sql}` is replaced by `.named('cf<id>')`, so the physical column
// follows the entry's permanent id while the Dart getter follows its name.
const _columnTemplates = {
  'text': 'TextColumn get {name} => text(){sql}.nullable()();',
  'bool': 'BoolColumn get {name} => boolean(){sql}.nullable()();',
  'int': 'IntColumn get {name} => integer(){sql}.nullable()();',
  'real': 'RealColumn get {name} => real(){sql}.nullable()();',
  // REQ-043: choice stores as text (the type only changes the editor input
  // and the registry entry); date is a nullable date-time.
  'choice': 'TextColumn get {name} => text(){sql}.nullable()();',
  'date': 'DateTimeColumn get {name} => dateTime(){sql}.nullable()();',
};

final _identifier = RegExp(r'^[a-z][A-Za-z0-9]*$');

/// REQ-055 (f): every entry needs a positive integer `id` and a `name`, both
/// unique. The name becomes a Dart getter, so it must be a lower-camel
/// identifier (slice 1 ceiling: a rename changes the getter, so code that
/// names the getter directly needs the same edit). Fails before any output.
void validateEntries(List<Map<String, dynamic>> entries) {
  final ids = <int>{};
  final names = <String>{};
  for (final e in entries) {
    final id = e['id'];
    final name = e['name'];
    if (id is! int || id < 1) {
      throw ArgumentError(
        'overrides_config.json: entry ${name ?? e} needs a positive integer "id", got $id',
      );
    }
    if (!ids.add(id)) {
      throw ArgumentError('overrides_config.json: duplicate id $id');
    }
    if (name is! String || !_identifier.hasMatch(name)) {
      throw ArgumentError(
        'overrides_config.json: id $id needs a "name" that is a lower-camel '
        'identifier (letters and digits, starting with a lowercase letter), got $name',
      );
    }
    if (!names.add(name)) {
      throw ArgumentError('overrides_config.json: duplicate name "$name"');
    }
  }
}

// A type change between these two needs no physical change (same column).
const _swappable = {'text', 'choice'};

/// REQ-055 (b): the type changes that keep every stored value, by old type.
/// Anything else is refused unless the id is accepted (which clears it).
const _lossless = {
  'bool': {'text', 'choice', 'int', 'real'},
  'int': {'text', 'choice', 'real'},
  'real': {'text', 'choice'},
  'date': {'text', 'choice'},
};

Map<String, dynamic> _plain(Object? m) => Map<String, dynamic>.from(m as Map);

/// The step for a type change on id [k], or null when the snapshot alone
/// changes (same type, or a text/choice swap). A lossless pair is a `retype`
/// that converts; any other pair throws, unless [k] is accepted, which makes
/// it a `retype` that clears the field's values (and marks it in [used]).
Map<String, dynamic>? _typeChange(
  String k,
  String from,
  String to,
  Set<int> accept,
  Set<int> used,
) {
  if (from == to || (_swappable.contains(from) && _swappable.contains(to))) {
    return null;
  }
  final id = int.parse(k);
  if (_lossless[from]?.contains(to) ?? false) {
    return {'id': id, 'kind': 'retype', 'from': from, 'to': to, 'clear': false};
  }
  if (accept.contains(id)) {
    used.add(id);
    return {'id': id, 'kind': 'retype', 'from': from, 'to': to, 'clear': true};
  }
  throw ArgumentError(
    'overrides_config.json: id $k changed type from $from to $to, which cannot '
    'keep its stored values. Change it back, use a new id, or run '
    '`make gen-overrides ARGS="--accept $k"` to clear that field\'s values',
  );
}

/// REQ-055 (a), (b), (d), (e): the next snapshot from the config and the
/// previous snapshot (null = first run: the current config is the baseline,
/// counter 0, no steps). The snapshot holds the counter, each live id's name
/// and type, a map of removed ids to their last name and type, and the ordered
/// steps (step N is counter N). A new id appends an `add` step and bumps the
/// counter; a rename, a removal, a restore of a removed id with its type, and
/// a text/choice swap change the snapshot only. A lossless type change appends
/// a converting `retype` step. Any other type change, and an id edit (a removed
/// id and a new id with the same name and type), throw, unless the id is in
/// [accept] (the `--accept` flag): then the retype clears the field, and the
/// id edit becomes a new empty field. An accepted id with nothing to accept
/// throws, so a typo cannot pass silently.
/// Pure; the caller writes the file only after this returns.
Map<String, dynamic> planSnapshot(
  List<Map<String, dynamic>> entries,
  Map<String, dynamic>? previous, {
  Set<int> accept = const {},
}) {
  validateEntries(entries);
  final used = <int>{};
  final cols = <String, Map<String, dynamic>>{};
  final removed = <String, Map<String, dynamic>>{};
  final steps = <Map<String, dynamic>>[];
  var counter = 0;
  if (previous != null) {
    counter = previous['counter'] as int;
    (previous['columns'] as Map).forEach((k, v) => cols['$k'] = _plain(v));
    (previous['removed'] as Map).forEach((k, v) => removed['$k'] = _plain(v));
    steps.addAll((previous['steps'] as List).map(_plain));
  }
  final current = {for (final e in entries) '${e['id']}': e};
  if (previous == null) {
    for (final e in entries) {
      cols['${e['id']}'] = {'name': e['name'], 'type': e['type']};
    }
  } else {
    final gone = {
      for (final k in cols.keys)
        if (!current.containsKey(k)) k: cols[k]!,
    };
    cols.removeWhere((k, _) => gone.containsKey(k));
    removed.addAll(gone);
    final fresh = <String, Map<String, dynamic>>{};
    for (final MapEntry(key: k, value: e) in current.entries) {
      final type = e['type'] as String;
      final prior = cols[k] ?? removed[k];
      if (prior != null) {
        final step = _typeChange(k, prior['type'] as String, type, accept, used);
        if (step != null) {
          steps.add(step);
          counter++;
        }
        removed.remove(k);
      } else {
        fresh[k] = e;
      }
      cols[k] = {'name': e['name'], 'type': type};
    }
    for (final MapEntry(key: ok, value: o) in gone.entries) {
      for (final MapEntry(key: nk, value: n) in fresh.entries) {
        if (o['name'] == n['name'] && o['type'] == n['type']) {
          if (accept.contains(int.parse(nk))) {
            used.add(int.parse(nk));
            continue;
          }
          throw ArgumentError(
            'overrides_config.json: id $ok is gone and id $nk has the same name '
            'and type; an id cannot be edited. To start a new field with that '
            'name, delete the entry and run the generator, then add it back '
            'later, or run `make gen-overrides ARGS="--accept $nk"` to keep id '
            '$nk as a new, empty field',
          );
        }
      }
    }
    for (final MapEntry(key: k, value: e) in fresh.entries) {
      steps.add({'id': int.parse(k), 'kind': 'add', 'type': e['type']});
      counter++;
    }
  }
  final unused = accept.difference(used);
  if (unused.isNotEmpty) {
    throw ArgumentError(
      '--accept ${unused.join(', ')} names no rejected change; nothing was written',
    );
  }
  Map<String, dynamic> byId(Map<String, Map<String, dynamic>> m) => {
        for (final k in (m.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)))))
          k: m[k],
      };
  return {
    'counter': counter,
    'columns': byId(cols),
    'removed': byId(removed),
    'steps': steps,
  };
}

// ponytail: drift's Table DSL class has no `$columns`-style introspection
// (only the generated TableInfo does, which a View's abstract getter can't
// see at declaration time) -- so CollectionItems' column list is mirrored
// here by hand. Ceiling: this drifts out of sync if database.dart's
// CollectionItems columns change without updating this list too. Upgrade
// path if that bites: switch to selecting `collectionItems.id` etc.
// individually generated from a shared column-name source, or accept the
// view only ever exposing a curated subset instead of "all" columns.
const _collectionItemsColumns = [
  'id', 'importedId', 'name', 'extra', 'setName', 'brandName',
  'discriminator', 'rarity', 'quantity', 'valueTotal', 'valuePerUnit',
  'valueCurrency', 'paidTotal', 'paidPerUnit', 'paidCurrency', 'gradeType',
  'gradeSubtype', 'groupName', 'groupWishlist', 'tcgplayerId',
  'pricechartingId', 'doubleholoId', 'dateAdded', 'tag',
];

/// `--accept <id>` (repeatable): the ids whose rejected change this run
/// accepts. Anything else on the command line is an error.
Set<int> parseAccept(List<String> args) {
  final out = <int>{};
  for (var i = 0; i < args.length; i++) {
    final id = args[i] == '--accept' && i + 1 < args.length
        ? int.tryParse(args[++i])
        : null;
    if (id == null || id < 1) {
      throw ArgumentError('usage: generate_overrides_schema.dart [--accept <id>]...');
    }
    out.add(id);
  }
  return out;
}

void main(List<String> args) {
  final accept = parseAccept(args);
  final configFile = File('overrides_config.json');
  final config = configFile.existsSync()
      ? jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final extraColumns = (config['extraColumns'] as List? ?? [])
      .cast<Map<String, dynamic>>();

  // REQ-055: the committed snapshot of the last accepted config. Planning
  // happens first, so a rejected change writes neither file.
  final snapshotFile = File('overrides_snapshot.json');
  final previous = snapshotFile.existsSync()
      ? jsonDecode(snapshotFile.readAsStringSync()) as Map<String, dynamic>
      : null;
  final snapshot = planSnapshot(extraColumns, previous, accept: accept);
  final source = generateOverridesSchema(extraColumns, snapshot);

  File('lib/database/overrides_schema.dart').writeAsStringSync(source);
  snapshotFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n',
  );
  stdout.writeln(
    'Wrote lib/database/overrides_schema.dart (${extraColumns.length} extra column(s), '
    'counter ${snapshot['counter']}) and overrides_snapshot.json',
  );
}

/// Pure: declared columns in, generated Dart source out (tested directly).
/// [snapshot] is [planSnapshot]'s result; omitted, the config is its own
/// baseline (counter 0, no steps, no orphans).
String generateOverridesSchema(
  List<Map<String, dynamic>> extraColumns, [
  Map<String, dynamic>? snapshot,
]) {
  validateEntries(extraColumns);
  final snap = snapshot ?? planSnapshot(extraColumns, null);
  final removed = (snap['removed'] as Map).map((k, v) => MapEntry('$k', _plain(v)));
  final orphanLines = removed.entries.map((o) {
    final template = _columnTemplates[o.value['type']]!;
    return '  ${template.replaceAll('{name}', 'orphan${o.key}').replaceAll('{sql}', ".named('cf${o.key}')")}';
  }).join('\n');
  final columnLines = extraColumns.map((col) {
    final name = col['name'] as String;
    final type = col['type'] as String;
    final template = _columnTemplates[type];
    if (template == null) {
      throw ArgumentError(
        'overrides_config.json: unknown type "$type" for column "$name" '
        '(expected one of ${_columnTemplates.keys.join(', ')})',
      );
    }
    return '  ${template.replaceAll('{name}', _camelCase(name)).replaceAll('{sql}', ".named('cf${col['id']}')")}';
  }).join('\n');

  final registryLines = extraColumns.map((col) {
    final name = col['name'] as String;
    final field = _camelCase(name);
    return "  (id: ${col['id']}, name: '$name', type: CustomColumnType.${col['type']}, "
        'value: (r) => r.$field, column: (t) => t.$field),';
  }).join('\n');

  final selectBaseCols =_collectionItemsColumns
      .map((name) => '    collectionItems.$name,')
      .join('\n');

  final stepLines = (snap['steps'] as List).map((s) {
    final m = _plain(s);
    // `type` is the type after the step; `from` is the type before a retype.
    return "  (id: ${m['id']}, kind: '${m['kind']}', type: '${m['to'] ?? m['type']}', "
        "from: '${m['from'] ?? ''}', clear: ${m['clear'] ?? false}),";
  }).join('\n');

  final columnSwitch = [
    for (final col in extraColumns)
      '      ${col['id']} => t.${_camelCase(col['name'] as String)},',
    for (final k in removed.keys) '      $k => t.orphan$k,',
  ].join('\n');

  final selectExtraCols = extraColumns
      .map((col) => '    collectionItemOverrides.${_camelCase(col['name'] as String)},')
      .join('\n');

  final buffer = StringBuffer()
    ..writeln('// GENERATED by tool/generate_overrides_schema.dart from')
    ..writeln('// overrides_config.json -- do not hand-edit. Regenerate:')
    ..writeln('//   make gen-overrides')
    ..writeln("import 'package:drift/drift.dart';")
    ..writeln("import 'database.dart';")
    ..writeln()
    ..writeln('class CollectionItemOverrides extends Table {')
    ..writeln('  TextColumn get importedId => text().unique()();')
    ..write(columnLines.isEmpty ? '' : '$columnLines\n')
    ..write(orphanLines.isEmpty
        ? ''
        : '  // REQ-055 (d): removed ids keep their column and values, declared here\n'
            '  // so drift matches the physical table; not in the registry or the view.\n')
    ..write(orphanLines.isEmpty ? '' : '$orphanLines\n')
    ..writeln('}')
    ..writeln()
    ..writeln('abstract class MergedItems extends View {')
    ..writeln('  CollectionItems get collectionItems;')
    ..writeln('  CollectionItemOverrides get collectionItemOverrides;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Query as() => select([')
    ..write(selectBaseCols)
    ..writeln()
    ..write(selectExtraCols.isEmpty ? '' : '$selectExtraCols\n')
    ..writeln('  ]).from(collectionItems).join([')
    ..writeln('    leftOuterJoin(')
    ..writeln('      collectionItemOverrides,')
    ..writeln('      collectionItemOverrides.importedId.equalsExp(collectionItems.importedId),')
    ..writeln('    ),')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('// REQ-043: registry of the declared custom columns. `type` is here')
    ..writeln('// because drift column info cannot tell choice from text. `value`')
    ..writeln('// reads the merged row (no reflection in Flutter); `column` is the')
    ..writeln('// overrides-table column (migration, choice suggestion query).')
    ..writeln('enum CustomColumnType { text, bool, int, real, choice, date }')
    ..writeln()
    ..writeln('// REQ-055: `id` is the permanent config id (null for a derived column).')
    ..writeln('typedef CustomColumn = ({int? id, String name, CustomColumnType type, '
        'Object? Function(MergedItem) value, '
        'GeneratedColumn Function(\$CollectionItemOverridesTable) column});')
    ..writeln()
    ..writeln('// REQ-055: the counter and its ordered steps come from overrides_snapshot.json;')
    ..writeln('// step N is counter N. The app replays the steps between its stored')
    ..writeln('// counter and this one.')
    ..writeln('const overrideCounter = ${snap['counter']};')
    ..writeln()
    ..writeln('const overrideSteps = <({int id, String kind, String type, String from, bool clear})>[')
    ..write(stepLines.isEmpty ? '' : '$stepLines\n')
    ..writeln('];')
    ..writeln()
    ..writeln('/// The overrides-table column of config id [id], live or removed; null if none.')
    ..writeln('GeneratedColumn? overrideColumn(\$CollectionItemOverridesTable t, int id) =>')
    ..writeln('    switch (id) {')
    ..write(columnSwitch.isEmpty ? '' : '$columnSwitch\n')
    ..writeln('      _ => null,')
    ..writeln('    };')
    ..writeln()
    ..writeln('final customColumns = <CustomColumn>[')
    ..write(registryLines.isEmpty ? '' : '$registryLines\n')
    ..writeln('];');

  return buffer.toString();
}

String _camelCase(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
