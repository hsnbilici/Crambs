import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart'
    show telemetryLoggerProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  int beginCount = 0;
  int endCount = 0;

  @override
  void log(TelemetryEvent event) => events.add(event);

  @override
  void beginSession() => beginCount++;

  @override
  void endSession() => endCount++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-id',
    });
  });

  ProviderContainer buildContainer(_FakeLogger logger) {
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('SessionController — onLaunch', () {
    test('firstLaunch → AppInstall + SessionStart emitted', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c.read(sessionControllerProvider).onLaunch(isFirstLaunch: true);

      expect(logger.events, hasLength(2));
      expect(logger.events[0], isA<AppInstall>());
      expect(logger.events[1], isA<SessionStart>());
      expect(logger.beginCount, 1);
    });

    test('not first launch → only SessionStart', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      expect(logger.events, hasLength(1));
      expect(logger.events.single, isA<SessionStart>());
    });

    test('SessionStart carries non-null install_id', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      final start = logger.events.single as SessionStart;
      expect(start.installId, 'test-id');
      expect(start.sessionId, isNotEmpty);
    });
  });

  group('SessionController — onPause', () {
    test('emits SessionEnd with duration', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final controller = c.read(sessionControllerProvider);
      // Cascade not possible: await separates onLaunch and onPause.
      // ignore: cascade_invocations
      controller.onLaunch(isFirstLaunch: false);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.onPause();

      expect(logger.events.last, isA<SessionEnd>());
      final end = logger.events.last as SessionEnd;
      expect(end.durationMs, greaterThanOrEqualTo(10));
      expect(logger.endCount, 1);
    });

    test('onPause without active session → no-op', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c.read(sessionControllerProvider).onPause();
      expect(logger.events, isEmpty);
    });
  });

  group('SessionController — onResume', () {
    test('emits new SessionStart with new session_id', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final controller = c.read(sessionControllerProvider);
      // Cascade not possible: firstSessionId read intervenes before onResume.
      // ignore: cascade_invocations
      controller.onLaunch(isFirstLaunch: false);
      final firstSessionId =
          (logger.events.single as SessionStart).sessionId;

      controller.onResume();
      final secondSessionId =
          (logger.events.last as SessionStart).sessionId;

      expect(secondSessionId, isNot(firstSessionId));
      expect(logger.beginCount, 2);
    });
  });

  group('SessionController — install_id not loaded sentinel', () {
    test('emits <not-loaded> when installIdProvider null', () {
      SharedPreferences.setMockInitialValues({}); // no install_id key
      final logger = _FakeLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      final start = logger.events.single as SessionStart;
      expect(start.installId, '<not-loaded>');
    });
  });
}
