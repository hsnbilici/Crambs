import 'dart:convert';

import 'package:crumbs/core/save/checksum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Checksum.of', () {
    test('empty map → constant hash (sha256 hex length 64)', () {
      final h = Checksum.of({});
      expect(h.length, 64);
      expect(h, Checksum.of({}));
    });

    test('canonical: key order invariant (top level)', () {
      final h1 = Checksum.of({'a': 1, 'b': 2});
      final h2 = Checksum.of({'b': 2, 'a': 1});
      expect(h1, equals(h2));
    });

    test('nested map key order invariant', () {
      final h1 = Checksum.of({'outer': {'a': 1, 'b': 2}});
      final h2 = Checksum.of({'outer': {'b': 2, 'a': 1}});
      expect(h1, equals(h2));
    });

    test('list order IS significant', () {
      final h1 = Checksum.of({'l': [1, 2, 3]});
      final h2 = Checksum.of({'l': [3, 2, 1]});
      expect(h1, isNot(equals(h2)));
    });

    test('value change changes hash', () {
      expect(
        Checksum.of({'a': 1}),
        isNot(equals(Checksum.of({'a': 2}))),
      );
    });

    test('shipping gate: toJson → fromJson → toJson checksum identical', () {
      const json1 = {
        'version': 1,
        'buildings': {
          'owned': {'crumb_collector': 3, 'bakery': 1},
        },
      };
      final h1 = Checksum.of(json1);
      final decoded = jsonDecode(jsonEncode(json1)) as Map<String, dynamic>;
      final h2 = Checksum.of(decoded);
      expect(h1, equals(h2));
    });
  });
}
