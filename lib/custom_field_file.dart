import 'dart:convert';

import 'database/database.dart';
import 'database/overrides_schema.dart';

/// REQ-047 (ADR-23 Option 1): the custom-field export file. Pure: no I/O.
const customFieldsFormat = 'holovault-custom-fields';
const customFieldsVersion = 1;

/// One overrides row as read from the table: the key and typed raw values.
typedef OverrideRowData = ({String importedId, Map<String, Object?> values});

/// REQ-055: the key of a field in the file is `cf<id>`, so a rename does not
/// change it. A column with no id (test registries only) keeps its name.
String customFileKey(CustomColumn c) => c.id == null ? c.name : 'cf${c.id}';

Object? _encode(CustomColumn c, Object? v) {
  if (v == null) return null;
  return c.type == CustomColumnType.date
      ? (v as DateTime).toIso8601String()
      : v;
}

/// Builds the file text: every declared column for every row (null if unset),
/// declared columns only, stable key order, 2-space indent.
String buildCustomFieldsFile(
  List<OverrideRowData> rows, [
  List<CustomColumn>? registry,
]) {
  final cols = registry ?? customColumns;
  final doc = {
    'format': customFieldsFormat,
    'version': customFieldsVersion,
    'rows': [
      for (final r in rows)
        {
          'importedId': r.importedId,
          'values': {for (final c in cols) customFileKey(c): _encode(c, r.values[c.name])},
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}

/// Result of [parseCustomFieldsFile]: rows on success, else [refusal].
class CustomFieldsParse {
  final List<OverrideRowData>? rows;
  final String? refusal;
  const CustomFieldsParse.ok(List<OverrideRowData> this.rows) : refusal = null;
  const CustomFieldsParse.refused(String this.refusal) : rows = null;
}

/// Parses and validates the whole file before anything is written. Keys not
/// in the registry are skipped; declared columns absent from a row's values
/// are absent from the result (left untouched on import).
CustomFieldsParse parseCustomFieldsFile(
  String text, [
  List<CustomColumn>? registry,
]) {
  final cols = {for (final c in registry ?? customColumns) customFileKey(c): c};
  const bad = CustomFieldsParse.refused;
  final Object? doc;
  try {
    doc = jsonDecode(text);
  } catch (_) {
    return bad('the file is not valid JSON');
  }
  if (doc is! Map || doc['format'] != customFieldsFormat) {
    return bad('the file is not a $customFieldsFormat file');
  }
  if (doc['version'] != customFieldsVersion) {
    return bad('unknown format version ${doc['version']}');
  }
  final rows = doc['rows'];
  if (rows is! List) return bad('the file has no rows list');
  final seen = <String>{};
  final out = <OverrideRowData>[];
  for (var i = 0; i < rows.length; i++) {
    final n = 'row ${i + 1}';
    final row = rows[i];
    if (row is! Map) return bad('$n is not an object');
    final id = row['importedId'];
    if (id is! String || id.isEmpty) return bad('$n has no importedId');
    if (!seen.add(id)) return bad('$n repeats importedId $id');
    final values = row['values'];
    if (values is! Map) return bad('$n has no values object');
    final parsed = <String, Object?>{};
    for (final e in values.entries) {
      final c = cols[e.key];
      if (c == null) continue;
      final v = e.value;
      final Object? typed;
      switch (c.type) {
        case CustomColumnType.text:
        case CustomColumnType.choice:
          typed = v is String ? v : (v == null ? null : _bad);
        case CustomColumnType.int:
          typed = v is num && v == v.truncate() ? v.toInt() : (v == null ? null : _bad);
        case CustomColumnType.real:
          typed = v is num ? v.toDouble() : (v == null ? null : _bad);
        case CustomColumnType.bool:
          typed = v is bool ? v : (v == null ? null : _bad);
        case CustomColumnType.date:
          typed = v is String ? (DateTime.tryParse(v) ?? _bad) : (v == null ? null : _bad);
      }
      if (identical(typed, _bad)) {
        return bad('$n field ${c.name} does not fit its ${c.type.name} type');
      }
      parsed[c.name] = typed;
    }
    out.add((importedId: id, values: parsed));
  }
  return CustomFieldsParse.ok(out);
}

/// REQ-048: parse the whole file, then write it in one transaction. Returns
/// the message to show; a refusal writes nothing. Other errors propagate.
Future<String> importCustomFieldsText(
  AppDatabase db,
  String text, [
  List<CustomColumn>? registry,
]) async {
  final cols = registry ?? customColumns;
  final parsed = parseCustomFieldsFile(text, cols);
  if (parsed.rows == null) {
    return 'Custom field import refused: ${parsed.refusal}';
  }
  await db.importCustomFieldRows(parsed.rows!, registry: cols);
  return 'Imported ${parsed.rows!.length} custom field row(s)';
}

// Sentinel for "value does not fit".
final Object _bad = Object();
