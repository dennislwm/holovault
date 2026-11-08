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

void main() {
  final configFile = File('overrides_config.json');
  final config = configFile.existsSync()
      ? jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final extraColumns = (config['extraColumns'] as List? ?? [])
      .cast<Map<String, dynamic>>();

  File('lib/database/overrides_schema.dart')
      .writeAsStringSync(generateOverridesSchema(extraColumns));
  stdout.writeln(
    'Wrote lib/database/overrides_schema.dart (${extraColumns.length} extra column(s))',
  );
}

/// Pure: declared columns in, generated Dart source out (tested directly).
String generateOverridesSchema(List<Map<String, dynamic>> extraColumns) {
  validateEntries(extraColumns);
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
    ..writeln('// REQ-055: bumped by the generator when a column is added or retyped.')
    ..writeln('// ponytail: fixed at 0 until the snapshot slice drives it.')
    ..writeln('const overrideCounter = 0;')
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
