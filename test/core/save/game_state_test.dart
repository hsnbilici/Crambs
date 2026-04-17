import 'package:crumbs/core/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState', () {
    test('initial() produces zero-state with fresh installId', () {
      final now = DateTime(2026, 4, 17, 12);
      final state = GameState.initial(now: now, installId: 'test-uuid');

      expect(state.meta.lastSavedAt, '2026-04-17T12:00:00.000');
      expect(state.meta.schemaVersion, 1);
      expect(state.meta.installId, 'test-uuid');
      expect(state.inventory.r1Crumbs, 0);
      expect(state.buildings.owned, isEmpty);
    });

    test('copyWith preserves unchanged children', () {
      final state = GameState.initial(
        now: DateTime(2026, 4, 17),
        installId: 'id-1',
      );
      final updated = state.copyWith(
        inventory: state.inventory.copyWith(r1Crumbs: 42),
      );

      expect(updated.inventory.r1Crumbs, 42);
      expect(updated.meta.installId, 'id-1');
      expect(updated.buildings.owned, isEmpty);
    });

    test('fromJson(toJson(x)) roundtrip equal', () {
      final state = GameState.initial(
        now: DateTime(2026, 4, 17),
        installId: 'rt-id',
      ).copyWith(
        inventory: const InventoryState(r1Crumbs: 12.5),
        buildings: const BuildingsState(owned: {'crumb_collector': 3}),
      );

      final json = state.toJson();
      final restored = GameState.fromJson(json);

      expect(restored, equals(state));
    });
  });
}
