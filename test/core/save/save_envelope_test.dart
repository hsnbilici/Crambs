import 'package:crumbs/core/save/save_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveEnvelope', () {
    test('construction + equality', () {
      const e1 = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: {'x': 1},
        checksum: 'abc',
      );
      const e2 = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: {'x': 1},
        checksum: 'abc',
      );
      expect(e1, equals(e2));
    });

    test('fromJson(toJson(x)) roundtrip', () {
      const e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: {
          'meta': {'installId': 'id-1'},
        },
        checksum: 'hash',
      );
      final restored = SaveEnvelope.fromJson(e.toJson());
      expect(restored, equals(e));
    });
  });
}
