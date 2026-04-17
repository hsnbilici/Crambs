import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/upgrade_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveEnvelope', () {
    test('construction + equality', () {
      final gs = GameState.initial(
        installId: 'eq',
        now: DateTime(2026, 4, 17, 12),
      );
      final e1 = SaveEnvelope(
        version: 2,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'abc',
      );
      final e2 = SaveEnvelope(
        version: 2,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'abc',
      );
      expect(e1, equals(e2));
    });

    test('fromJson(toJson(x)) roundtrip', () {
      final gs = GameState.initial(
        installId: 'id-1',
        now: DateTime(2026, 4, 17, 12),
      );
      final e = SaveEnvelope(
        version: 2,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'hash',
      );
      final restored = SaveEnvelope.fromJson(e.toJson());
      expect(restored, equals(e));
    });

    test('SaveEnvelope typed GameState roundtrip — upgrades preserved', () {
      final gs = GameState.initial(
        installId: 'typed',
        now: DateTime(2026, 4, 17, 12),
      ).copyWith(
        upgrades: const UpgradeState(owned: {'golden_recipe_i': true}),
      );
      final envelope = SaveEnvelope(
        version: 2,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: gs,
        checksum: 'dummy',
      );
      final restored = SaveEnvelope.fromJson(envelope.toJson());
      expect(restored.gameState.upgrades.owned, {'golden_recipe_i': true});
      expect(restored.version, 2);
      expect(restored.gameState.meta.installId, 'typed');
    });
  });
}
