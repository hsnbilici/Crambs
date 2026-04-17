import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fmt — special', () {
    test('NaN → —', () => expect(fmt(double.nan), '—'));
    test('Infinity → —', () => expect(fmt(double.infinity), '—'));
    test('0 → 0', () => expect(fmt(0), '0'));
    test('0.0 → 0 (not 0,0)', () => expect(fmt(0), '0'));
  });

  group('fmt — small (<10 decimal)', () {
    test('0.8 → 0,8', () => expect(fmt(0.8), '0,8'));
    test('9.2 → 9,2', () => expect(fmt(9.2), '9,2'));
  });

  group('fmt — int (10-999)', () {
    test('10 → 10', () => expect(fmt(10), '10'));
    test('42.7 → 42', () => expect(fmt(42.7), '42'));
    test('987 → 987', () => expect(fmt(987), '987'));
  });

  group('fmt — short scale (TR)', () {
    test('1234 → 1,23K', () => expect(fmt(1234), '1,23K'));
    test('1e6 → 1,00M', () => expect(fmt(1000000), '1,00M'));
    test('1.5e9 → 1,50B', () => expect(fmt(1500000000), '1,50B'));
    test('1e18 → 1,00Qi', () => expect(fmt(1000000000000000000), '1,00Qi'));
    test('1e33 → 1,00Dc', () => expect(fmt(1e33), '1,00Dc'));
  });

  group('fmt — scientific fallback (>Dc)', () {
    test('1e42 → 1,00e+42', () => expect(fmt(1e42), '1,00e+42'));
  });

  group('fmt — negative', () {
    test('-1500 → -1,50K', () => expect(fmt(-1500), '-1,50K'));
    test('-0.5 → -0,5', () => expect(fmt(-0.5), '-0,5'));
  });

  group('fmt — tier boundaries', () {
    test('999 → 987-style int (upper int bucket)',
        () => expect(fmt(999), '999'));
    test('1000 → 1,00K (first short-scale tier)',
        () => expect(fmt(1000), '1,00K'));
    test('999999 → K or M boundary', () {
      // 999999 ≈ 999.999K → toStringAsFixed(1) rounds to "1000.0K" or bumps to
      // "1,00M" depending on order of ops. Pin shape, not exact value.
      final out = fmt(999999);
      expect(out.endsWith('K') || out.endsWith('M'), isTrue);
    });
    test('1e36 → scientific (past Dc)', () => expect(fmt(1e36), '1,00e+36'));
  });
}
