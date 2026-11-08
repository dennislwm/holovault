// REQ-055 (b): converting one stored override value when a field's type
// changes. Pure: no I/O. Stored forms: text and choice a String, bool the int
// 0 or 1, int an int, real a double, date a unix-seconds int (drift's default).

String _two(int n) => n.toString().padLeft(2, '0');

/// Local calendar date as yyyy-MM-dd (the cell text, the clause value, and a
/// date converted to text).
String formatLocalDay(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}';
}

/// [v] converted from type [from] to type [to], or null when [v] is null.
/// Only the lossless pairs exist (the generator refuses the rest); a stored
/// value of the wrong shape, or a pair that is not lossless, throws.
Object? convertOverrideValue(Object? v, String from, String to) {
  if (v == null) return null;
  final text = to == 'text' || to == 'choice';
  Never bad() => throw StateError('cannot convert $from value $v to $to');
  switch (from) {
    case 'bool':
      if (v != 0 && v != 1) bad();
      final b = v == 1;
      if (text) return b ? 'true' : 'false';
      if (to == 'int') return b ? 1 : 0;
      if (to == 'real') return b ? 1.0 : 0.0;
    case 'int':
      if (v is! int) bad();
      if (text) return v.toString();
      if (to == 'real') return v.toDouble();
    case 'real':
      if (v is! num) bad();
      if (text) return v.toDouble().toString();
    case 'date':
      if (v is! int) bad();
      if (text) return formatLocalDay(DateTime.fromMillisecondsSinceEpoch(v * 1000));
  }
  bad();
}
