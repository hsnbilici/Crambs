import 'package:crumbs/core/economy/offline_progress.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineProgress.compute', () {
    GameState stateWith({
      required DateTime lastSavedAt,
      Map<String, int> buildings = const {'crumb_collector': 1},
    }) =>
        GameState(
          meta: MetaState(
            lastSavedAt: lastSavedAt.toIso8601String(),
            schemaVersion: 1,
            installId: 'test',
          ),
          inventory: const InventoryState(r1Crumbs: 0),
          buildings: BuildingsState(owned: buildings),
        );

    test('0s elapsed → 0 earned, not capped', () {
      final now = DateTime(2026, 4, 17, 12);
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: now),
        now,
      );
      expect(report.earned, 0);
      expect(report.elapsed, Duration.zero);
      expect(report.capped, isFalse);
    });

    test('60s elapsed × 1 collector = 6 Crumbs', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(seconds: 60));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      expect(report.earned, closeTo(6, 1e-9));
      expect(report.elapsed, const Duration(seconds: 60));
      expect(report.capped, isFalse);
    });

    test('1h elapsed × 1 collector = 360 Crumbs', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 1));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      expect(report.earned, closeTo(360, 1e-6));
    });

    test('25h elapsed → capped at 24h', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 25));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      // 24h × 0.1 C/s × 3600 = 8640
      expect(report.earned, closeTo(8640, 1e-3));
      expect(report.elapsed, const Duration(hours: 25));
      expect(report.capped, isTrue);
    });

    test('no buildings → 0 earned', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 5));
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: last, buildings: {}),
        now,
      );
      expect(report.earned, 0);
      expect(report.elapsed, const Duration(hours: 5));
    });
  });

  group('OfflineProgress — globalMultiplier forwarding', () {
    GameState stateWith({
      required DateTime lastSavedAt,
      Map<String, int> buildings = const {'crumb_collector': 1},
    }) =>
        GameState(
          meta: MetaState(
            lastSavedAt: lastSavedAt.toIso8601String(),
            schemaVersion: 1,
            installId: 'test',
          ),
          inventory: const InventoryState(r1Crumbs: 0),
          buildings: BuildingsState(owned: buildings),
        );

    test('default multiplier = 1.0 (backward-compat)', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(seconds: 10));
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: last, buildings: {'crumb_collector': 10}),
        now,
      );
      expect(report.earned, closeTo(10.0, 1e-9));  // 10 × 0.1 × 10 = 10
    });

    test('multiplier 1.5 scales earned', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(seconds: 10));
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: last, buildings: {'crumb_collector': 10}),
        now,
        globalMultiplier: 1.5,
      );
      expect(report.earned, closeTo(15.0, 1e-9));  // 10 × 0.1 × 1.5 × 10 = 15
    });
  });
}
