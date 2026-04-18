import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetryEvent — AppInstall', () {
    test('eventName is app_install', () {
      const e = AppInstall(installId: 'abc-123', platform: 'ios');
      expect(e.eventName, 'app_install');
    });

    test('payload has install_id and platform', () {
      const e = AppInstall(installId: 'abc-123', platform: 'ios');
      expect(e.payload, {'install_id': 'abc-123', 'platform': 'ios'});
    });
  });

  group('TelemetryEvent — SessionStart', () {
    test('eventName is session_start', () {
      const e = SessionStart(
        installId: 'abc',
        sessionId: 'sess-1',
        installIdAgeMs: 0,
      );
      expect(e.eventName, 'session_start');
    });

    test('payload has install_id, session_id, install_id_age_ms', () {
      const e = SessionStart(
        installId: 'abc',
        sessionId: 'sess-1',
        installIdAgeMs: 12345,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
        'install_id_age_ms': 12345,
      });
    });
  });

  group('TelemetryEvent — SessionEnd', () {
    test('eventName is session_end', () {
      const e = SessionEnd(installId: 'abc', sessionId: 's1', durationMs: 1200);
      expect(e.eventName, 'session_end');
    });

    test('payload has install_id, session_id, duration_ms', () {
      const e = SessionEnd(installId: 'abc', sessionId: 's1', durationMs: 1200);
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 's1',
        'duration_ms': 1200,
      });
    });
  });

  group('TelemetryEvent — TutorialStarted', () {
    test('eventName is tutorial_started', () {
      const e = TutorialStarted(installId: 'abc', isReplay: false);
      expect(e.eventName, 'tutorial_started');
    });

    test('payload has install_id + is_replay', () {
      const e = TutorialStarted(installId: 'abc', isReplay: false);
      expect(e.payload, {'install_id': 'abc', 'is_replay': false});
    });

    test('isReplay=true propagates in payload', () {
      const e = TutorialStarted(installId: 'abc', isReplay: true);
      expect(e.payload['is_replay'], true);
    });
  });

  group('TelemetryEvent — TutorialCompleted', () {
    test('eventName is tutorial_completed', () {
      const e = TutorialCompleted(
        installId: 'abc',
        skipped: false,
        durationMs: 45000,
      );
      expect(e.eventName, 'tutorial_completed');
    });

    test('payload has install_id, skipped, duration_ms', () {
      const e = TutorialCompleted(
        installId: 'abc',
        skipped: true,
        durationMs: 3000,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'skipped': true,
        'duration_ms': 3000,
      });
    });
  });

  group('TelemetryEvent — PurchaseMade (B4)', () {
    test('eventName is purchase_made', () {
      const e = PurchaseMade(
        installId: 'abc',
        buildingId: 'crumb_collector',
        cost: 15,
        ownedAfter: 1,
      );
      expect(e.eventName, 'purchase_made');
    });

    test('payload has install_id, building_id, cost, owned_after', () {
      const e = PurchaseMade(
        installId: 'abc',
        buildingId: 'oven',
        cost: 120,
        ownedAfter: 3,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'building_id': 'oven',
        'cost': 120,
        'owned_after': 3,
      });
    });
  });

  group('TelemetryEvent — UpgradePurchased (B4)', () {
    test('eventName is upgrade_purchased', () {
      const e = UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      );
      expect(e.eventName, 'upgrade_purchased');
    });

    test('payload has install_id, upgrade_id, cost', () {
      const e = UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'upgrade_id': 'golden_recipe_i',
        'cost': 200,
      });
    });
  });

  test('TelemetryEvent is sealed — pattern match exhaustive', () {
    const TelemetryEvent e = AppInstall(installId: 'x', platform: 'ios');
    final name = switch (e) {
      AppInstall() => 'install',
      SessionStart() => 'start',
      SessionEnd() => 'end',
      TutorialStarted() => 'tut_start',
      TutorialCompleted() => 'tut_done',
      PurchaseMade() => 'purchase',
      UpgradePurchased() => 'upgrade',
    };
    expect(name, 'install');
  });
}
