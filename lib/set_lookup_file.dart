// REQ-052 (ADR-24 Option 3): parse and validate a set_language.json file, then
// replace the stored set lookup in one transaction.
import 'dart:convert';

import 'database/database.dart';
import 'set_lookup.dart';

typedef SetLookupData = ({
  String aliasName,
  String language,
  String? tcgdexId,
  String? officialName,
});

/// Result of [parseSetLookupFile]: rows on success, else [refusal].
class SetLookupParse {
  final List<SetLookupData>? rows;
  final String? refusal;
  const SetLookupParse.ok(List<SetLookupData> this.rows) : refusal = null;
  const SetLookupParse.refused(String this.refusal) : rows = null;
}

/// Validates the whole file before anything is written. Only `shiny` aliases
/// the file resolved `exact` become lookup rows; the others are skipped.
/// `name` may be a string, an object (tcgdex, else artofpkm) or null; `id` an
/// object or null.
SetLookupParse parseSetLookupFile(String text) {
  const bad = SetLookupParse.refused;
  final Object? doc;
  try {
    doc = jsonDecode(text);
  } catch (_) {
    return bad('the file is not valid JSON');
  }
  if (doc is! List) return bad('the file is not a list of sets');
  final seen = <String>{};
  final out = <SetLookupData>[];
  for (var i = 0; i < doc.length; i++) {
    final n = 'set ${i + 1}';
    final row = doc[i];
    if (row is! Map) return bad('$n is not an object');
    final language = row['language'];
    if (language is! String || language.isEmpty) return bad('$n has no language');
    final id = row['id'];
    if (id != null && id is! Map) return bad('$n has an id that is not an object');
    final tcgdex = id is Map ? id['tcgdex'] : null;
    if (tcgdex != null && tcgdex is! String) {
      return bad('$n has a tcgdex id that is not text');
    }
    final name = row['name'];
    final String? official;
    if (name is String) {
      official = name;
    } else if (name is Map) {
      final v = name['tcgdex'] ?? name['artofpkm'];
      if (v != null && v is! String) return bad('$n has a name that is not text');
      official = v as String?;
    } else if (name == null) {
      official = null;
    } else {
      return bad('$n has a name that is not text, an object or null');
    }
    final aliases = row['alias'];
    if (aliases is! List) return bad('$n has no alias list');
    for (var j = 0; j < aliases.length; j++) {
      final a = aliases[j];
      final an = '$n alias ${j + 1}';
      if (a is! Map) return bad('$an is not an object');
      final app = a['app'];
      final aliasName = a['name'];
      final resolved = a['resolved'];
      if (app is! String) return bad('$an has no app');
      if (aliasName is! String || aliasName.isEmpty) return bad('$an has no name');
      if (resolved is! Map || resolved['by'] is! String) {
        return bad('$an has no resolved.by');
      }
      if (app != 'shiny' || resolved['by'] != 'exact') continue;
      if (!seen.add(aliasName)) return bad('$an repeats the alias name "$aliasName"');
      out.add((
        aliasName: aliasName,
        language: language,
        tcgdexId: tcgdex as String?,
        officialName: official,
      ));
    }
  }
  if (out.isEmpty) return bad('the file has no exact shiny aliases');
  return SetLookupParse.ok(out);
}

/// Parse the whole file, then write it in one transaction and reload the
/// in-memory lookup. Returns the message to show; a refusal writes nothing.
Future<String> importSetLookupText(AppDatabase db, String text) async {
  final parsed = parseSetLookupFile(text);
  if (parsed.rows == null) {
    return 'Set lookup import refused: ${parsed.refusal}';
  }
  await db.replaceSetLookup(parsed.rows!);
  await refreshSetLookup(db);
  return 'Set lookup imported: ${parsed.rows!.length} set(s)';
}
