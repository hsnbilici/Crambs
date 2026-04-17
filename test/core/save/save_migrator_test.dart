import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveMigrator', () {
    test('migrate v1 → v1 no-op', () {
      final gs = GameState.initial(
        installId: 'noop',
        now: DateTime(2026, 4, 17, 12),
      );
      final e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'c',
      );
      final migrated = SaveMigrator.migrate(e, targetVersion: 1);
      expect(migrated, equals(e));
    });

    test('migrate future version throws UnsupportedError', () {
      final gs = GameState.initial(
        installId: 'future',
        now: DateTime(2026, 4, 17, 12),
      );
      final e = SaveEnvelope(
        version: 3,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'c',
      );
      expect(
        () => SaveMigrator.migrate(e, targetVersion: 1),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
