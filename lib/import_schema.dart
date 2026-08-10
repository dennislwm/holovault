import 'package:json_schema/json_schema.dart';

/// ADR-11, Option 1: patterns match the string shape a value must have to
/// survive the coercion in `_rowToCompanion` (`int.parse`/`double.parse`/
/// `bool.parse`/`DateTime.parse`) -- every parsed row value arrives as a
/// `String?` (see `parseImportFile`), never a real JSON number/bool, so
/// this validates string shape, not JSON type.
const _integerPattern = r'^-?[0-9]+$';
const _decimalPattern = r'^-?[0-9]+(\.[0-9]+)?$';
// REQ-012: the real ShinyExport exporter emits the literal string
// "Unavailable" for value_total/value_per_unit on a card with no listed
// market value -- accept it here, coerced to null in _rowToCompanion.
const _decimalOrUnavailablePattern = r'^(-?[0-9]+(\.[0-9]+)?|Unavailable)$';
const _boolPattern = r'^(true|false)$';
const _dateTimePattern = r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}:\d{2}(\.\d+)?)?Z?$';

const _nullableStringPatternProperty = {
  'type': ['string', 'null'],
};

final JsonSchema importRowSchema = JsonSchema.create({
  'type': 'object',
  'properties': {
    'quantity': {..._nullableStringPatternProperty, 'pattern': _integerPattern},
    'value_total': {..._nullableStringPatternProperty, 'pattern': _decimalOrUnavailablePattern},
    'value_per_unit': {..._nullableStringPatternProperty, 'pattern': _decimalOrUnavailablePattern},
    'paid_total': {..._nullableStringPatternProperty, 'pattern': _decimalPattern},
    'paid_per_unit': {..._nullableStringPatternProperty, 'pattern': _decimalPattern},
    'group_wishlist': {..._nullableStringPatternProperty, 'pattern': _boolPattern},
    'date_added': {..._nullableStringPatternProperty, 'pattern': _dateTimePattern},
  },
});

/// Returns one "field: reason" message per failed field, empty if [row]
/// coerces cleanly.
List<String> validateRow(Map<String, String?> row) {
  return importRowSchema
      .validate(row)
      .errors
      .map((e) => '${e.instancePath}: ${e.message}')
      .toList();
}
