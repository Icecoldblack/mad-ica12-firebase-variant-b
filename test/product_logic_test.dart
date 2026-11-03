import 'package:flutter_test/flutter_test.dart';
import 'package:my_product_app/product_logic.dart';

/// Variant B fixtures from campus_products_variant_b.csv
const fixtures = <String, double>{
  'Maple Notebook': 9.75,
  'Campus Pen Set': 16.50,
  'Study Lamp': 29.00,
  'maple Bookmark': 4.25,
  'Welcome Sample': 0.00,
};

List<String> run({String query = '', double? min, double? max}) {
  final out = fixtures.entries
      .where((e) => matchesFilters(
          name: e.key, price: e.value, query: query, min: min, max: max))
      .map((e) => e.key)
      .toList()
    ..sort();
  return out;
}

void main() {
  group('T4 search (case insensitive substring)', () {
    test('mApLe returns both maple products', () {
      expect(run(query: 'mApLe'), ['Maple Notebook', 'maple Bookmark']);
    });
    test('book matches mid word (substring, not prefix)', () {
      expect(run(query: 'book'), ['Maple Notebook', 'maple Bookmark']);
    });
    test('nonexistent name returns nothing', () {
      expect(run(query: 'zzz-not-here'), isEmpty);
    });
    test('empty and whitespace query returns all five', () {
      expect(run().length, 5);
      expect(run(query: '   ').length, 5);
    });
  });

  group('T5 price range (inclusive) and combination', () {
    test('min 4.25 max 16.50 returns 3 inclusive', () {
      expect(run(min: 4.25, max: 16.50),
          ['Campus Pen Set', 'Maple Notebook', 'maple Bookmark']);
    });
    test('range combined with search maple returns 2', () {
      expect(run(query: 'maple', min: 4.25, max: 16.50),
          ['Maple Notebook', 'maple Bookmark']);
    });
    test('min equals max 9.75 returns exactly Maple Notebook', () {
      expect(run(min: 9.75, max: 9.75), ['Maple Notebook']);
    });
    test('zero price is included by max 0', () {
      expect(run(max: 0), ['Welcome Sample']);
    });
    test('only min applies when max is empty', () {
      expect(run(min: 16.50), ['Campus Pen Set', 'Study Lamp']);
    });
    test('null price is excluded when a bound is set', () {
      expect(
          matchesFilters(name: 'x', price: null, query: '', min: 0), isFalse);
    });
  });

  group('T6 input validation', () {
    test('whitespace name rejected, name trimmed', () {
      expect(validateName('   ').isOk, isFalse);
      expect(validateName('  B-PINE-Test Kit ').value, 'B-PINE-Test Kit');
    });
    test('valid prices including zero', () {
      expect(validatePrice('0').value, 0);
      expect(validatePrice('0.00').value, 0);
      expect(validatePrice('14.25').value, 14.25);
    });
    for (final bad in [
      '', ' ', 'abc', '-1', '-0.5', 'NaN', 'Infinity', '\$9.75', '1,000',
      '1e3', '9.', '.5'
    ]) {
      test('rejects price "$bad"', () {
        expect(validatePrice(bad).isOk, isFalse);
      });
    }
    test('empty bound means no limit', () {
      final r = validateBound('', 'Min');
      expect(r.isOk, isTrue);
      expect(r.value, isNull);
    });
    test('invalid bound reports label', () {
      expect(validateBound('abc', 'Max').error, startsWith('Max:'));
    });
    test('min greater than max rejected', () {
      expect(validateRange(20, 10), isNotNull);
      expect(validateRange(9.75, 9.75), isNull);
    });
    test('readPrice accepts int and double, rejects strings', () {
      expect(readPrice(9), 9.0);
      expect(readPrice(9.75), 9.75);
      expect(readPrice('9.75'), isNull);
      expect(readPrice(double.nan), isNull);
    });
  });
}
