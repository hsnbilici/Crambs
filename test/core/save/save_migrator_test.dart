import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveMigrator', () {
    test('migrate v1 → v1 no-op', () {
      const e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: {'x': 1},
        checksum: 'c',
      );
      final migrated = SaveMigrator.migrate(e, targetVersion: 1);
      expect(migrated, equals(e));
    });

    test('migrate future version throws UnsupportedError', () {
      const e = SaveEnvelope(
        version: 3,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: {},
        checksum: 'c',
      );
      expect(
        () => SaveMigrator.migrate(e, targetVersion: 1),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
