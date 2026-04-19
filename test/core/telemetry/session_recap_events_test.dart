import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRecapShown', () {
    test('eventName + payload shape', () {
      const e = SessionRecapShown(
        installId: 'abc',
        sessionId: 'sess-1',
        offlineDurationMs: 180000,
        resourceEarnedOffline: 142,
      );
      expect(e.eventName, 'session_recap_shown');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
        'offline_duration_ms': 180000,
        'resource_earned_offline': 142,
      });
    });
  });

  group('SessionRecapActionTaken', () {
    test('eventName + payload with action_type', () {
      const e = SessionRecapActionTaken(
        installId: 'abc',
        sessionId: 'sess-1',
        actionType: 'collect',
      );
      expect(e.eventName, 'session_recap_action_taken');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
        'action_type': 'collect',
      });
    });
  });

  group('SessionRecapDismissed', () {
    test('eventName + payload', () {
      const e = SessionRecapDismissed(
        installId: 'abc',
        sessionId: 'sess-1',
      );
      expect(e.eventName, 'session_recap_dismissed');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
      });
    });
  });

  group('Firebase compliance', () {
    final events = <TelemetryEvent>[
      const SessionRecapShown(
        installId: 'x',
        sessionId: 'y',
        offlineDurationMs: 0,
        resourceEarnedOffline: 0,
      ),
      const SessionRecapActionTaken(
        installId: 'x',
        sessionId: 'y',
        actionType: 'collect',
      ),
      const SessionRecapDismissed(installId: 'x', sessionId: 'y'),
    ];
    final nameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
    const reservedPrefixes = ['firebase_', 'google_', 'ga_'];

    for (final e in events) {
      test('${e.eventName} matches Firebase regex', () {
        expect(nameRegex.hasMatch(e.eventName), isTrue);
      });
      test('${e.eventName} has no reserved prefix', () {
        for (final p in reservedPrefixes) {
          expect(e.eventName.startsWith(p), isFalse);
        }
      });
    }
  });
}
