/// Pure logic for the Campus Supply Desk (Variant B).
///
/// Kept free of Flutter and Firebase imports so it can be unit tested
/// without an emulator or a Firestore connection.
library;

/// Result of validating a single text field.
class ParseResult<T> {
  final T? value;
  final String? error;
  const ParseResult.ok(this.value) : error = null;
  const ParseResult.fail(this.error) : value = null;
  bool get isOk => error == null;
}

/// Validates a product name: trimmed and nonempty.
ParseResult<String> validateName(String? raw) {
  final name = (raw ?? '').trim();
  if (name.isEmpty) {
    return const ParseResult.fail('Name cannot be empty or only spaces.');
  }
  return ParseResult.ok(name);
}

/// Accepts plain decimal amounts such as 9.75, 0, or 14.
/// Rejects currency symbols, grouping commas, exponents, NaN and Infinity.
final RegExp _plainDecimal = RegExp(r'^\d+(\.\d+)?$');

/// Validates a required price: finite, nonnegative number. Zero is valid.
ParseResult<double> validatePrice(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return const ParseResult.fail('Price is required.');
  }
  if (text.startsWith('-')) {
    return const ParseResult.fail('Price cannot be negative.');
  }
  if (!_plainDecimal.hasMatch(text)) {
    return const ParseResult.fail(
        'Enter a plain number like 9.75 (no symbols, commas, NaN or Infinity).');
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) {
    return const ParseResult.fail('Price must be a finite number.');
  }
  return ParseResult.ok(value);
}

/// Validates an optional filter bound. Empty means "no limit" (null value).
ParseResult<double?> validateBound(String? raw, String label) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return const ParseResult.ok(null);
  final parsed = validatePrice(text);
  if (!parsed.isOk) return ParseResult.fail('$label: ${parsed.error}');
  return ParseResult.ok(parsed.value);
}

/// Checks that min is not greater than max when both are supplied.
String? validateRange(double? min, double? max) {
  if (min != null && max != null && min > max) {
    return 'Minimum price cannot be greater than maximum price.';
  }
  return null;
}

/// Reads a numeric price from Firestore data, tolerating int or double.
double? readPrice(Object? raw) {
  if (raw is num && raw.isFinite) return raw.toDouble();
  return null;
}

/// True when a product passes the search and inclusive price range together.
///
/// Search is a case insensitive SUBSTRING match (Variant B): "book" matches
/// both "Maple Notebook" and "maple Bookmark". An empty query matches all.
bool matchesFilters({
  required String name,
  required double? price,
  required String query,
  double? min,
  double? max,
}) {
  final q = query.trim().toLowerCase();
  if (q.isNotEmpty && !name.trim().toLowerCase().contains(q)) return false;
  if (min != null || max != null) {
    if (price == null) return false;
    if (min != null && price < min) return false;
    if (max != null && price > max) return false;
  }
  return true;
}
