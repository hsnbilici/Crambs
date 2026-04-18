import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (msg, {wrapWidth}) {
      if (msg != null) logs.add(msg);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  group('DebugLogger', () {
    test('log() writes [TELEMETRY] {eventName} {payload}', () {
      DebugLogger()
          .log(const AppInstall(installId: 'abc', platform: 'ios'));
      expect(logs, hasLength(1));
      expect(logs.single, startsWith('[TELEMETRY] app_install'));
      expect(logs.single, contains('install_id'));
      expect(logs.single, contains('abc'));
    });

    test('beginSession() writes marker', () {
      DebugLogger().beginSession();
      expect(logs.single, '[TELEMETRY] beginSession');
    });

    test('endSession() writes marker', () {
      DebugLogger().endSession();
      expect(logs.single, '[TELEMETRY] endSession');
    });

    test('log() preserves event order across calls', () {
      DebugLogger()
        ..log(const SessionStart(installId: 'a', sessionId: 's1'))
        ..log(const TutorialStarted(installId: 'a'))
        ..log(
          const SessionEnd(
            installId: 'a',
            sessionId: 's1',
            durationMs: 10,
          ),
        );
      expect(logs, hasLength(3));
      expect(logs[0], contains('session_start'));
      expect(logs[1], contains('tutorial_started'));
      expect(logs[2], contains('session_end'));
    });
  });
}
