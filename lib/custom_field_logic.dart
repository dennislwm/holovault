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

/// Distinct, non-empty, sorted suggestions. Case-sensitive, no merging.
List<String> suggestionList(Iterable<String?> stored) =>
    (stored.whereType<String>().where((s) => s.isNotEmpty).toSet().toList()
      ..sort());
