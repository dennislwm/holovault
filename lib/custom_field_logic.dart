// REQ-043 (b): pure helpers for the custom-field inputs.

/// Validator for custom real/int inputs. Empty is valid (stores null).
/// Dot-decimal only; no range limits. Returns a short message or null.
String? validateNumber(String? text, {required bool whole}) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return null;
  final ok = whole ? int.tryParse(t) != null : _decimal.hasMatch(t);
  if (ok) return null;
  return whole ? 'Enter a whole number' : 'Enter a number';
}

final _decimal = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$');

/// Parses text already accepted by [validateNumber]; empty gives null.
num? parseNumber(String? text, {required bool whole}) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return null;
  return whole ? int.parse(t) : double.parse(t);
}

/// REQ-055: stable non-zero 31-bit FNV-1a fingerprint of the declared custom
/// fields (each entry `name:type`, order matters), stamped into the database.
int configFingerprint(Iterable<String> entries) {
  var h = 0x811c9dc5;
  for (final u in entries.join(';').codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

/// Distinct, non-empty, sorted suggestions. Case-sensitive, no merging.
List<String> suggestionList(Iterable<String?> stored) =>
    (stored.whereType<String>().where((s) => s.isNotEmpty).toSet().toList()
      ..sort());
