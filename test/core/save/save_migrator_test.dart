import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveMigrator.migrate', () {
    test('migrate v1 rawEnvelope → v2 typed SaveEnvelope', () {
      // Build v1 disk shape from current GameState.initial minus `upgrades`.
      final templateGs = GameState.initial(
        installId: 'legacy-user',
        now: DateTime(2026, 4, 17, 12),
      ).toJson()
        ..remove('upgrades');
      // Also adjust buildings to assert preservation.
      (templateGs['buildings']! as Map<String, dynamic>)['owned'] = {
        'crumb_collector': 3,
      };

      final v1Raw = <String, dynamic>{
        'version': 1,
        'lastSavedAt': '2026-04-17T10:00:00.000',
        'gameState': templateGs,
        'checksum': 'legacy-checksum',
      };
      final migrated = SaveMigrator.migrate(v1Raw, 2);
      expect(migrated.version, 2);
      expect(migrated.gameState.upgrades.owned, isEmpty);
      expect(migrated.gameState.meta.installId, 'legacy-user');
      expect(migrated.gameState.buildings.owned['crumb_collector'], 3);
      // Checksum recomputed post-migration (not legacy hash)
      expect(migrated.checksum, isNot('legacy-checksum'));
    });

    test('migrate idempotent — v2 rawEnvelope returns typed without drift', () {
      final gs = GameState.initial(
        installId: 'x',
        now: DateTime(2026, 4, 17, 12),
      );
      final v2Raw = <String, dynamic>{
        'version': 2,
        'lastSavedAt': '2026-04-17T10:00:00.000',
        'gameState': gs.toJson(),
        'checksum': 'any',
      };
      final migrated = SaveMigrator.migrate(v2Raw, 2);
      expect(migrated.version, 2);
      expect(migrated.gameState, gs);
    });

    test('migrate throws FormatException for unreachable version', () {
      final v99Raw = <String, dynamic>{
        'version': 99,
        'lastSavedAt': '2026-04-17T10:00:00.000',
        'gameState': <String, dynamic>{},
        'checksum': '',
      };
      expect(() => SaveMigrator.migrate(v99Raw, 2), throwsFormatException);
    });
  });
}
