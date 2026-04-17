import 'dart:io';

import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  int endSessionCalls = 0;
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() => endSessionCalls++;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-id',
    });
    tempDir = await Directory.systemTemp.createTemp('crumbs_session_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('SessionController onPause emits SessionEnd with positive durationMs',
      () async {
    final logger = _RecordingLogger();
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
    ]);
    addTearDown(c.dispose);

    await c.read(installIdProvider.notifier).ensureLoaded();
    await c.read(gameStateNotifierProvider.future);
    c
        .read(sessionControllerProvider)
        .onLaunch(isFirstLaunch: false);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    c.read(sessionControllerProvider).onPause();

    final endEvent = logger.events.whereType<SessionEnd>().single;
    expect(endEvent.sessionId, isNotEmpty);
    expect(endEvent.durationMs, greaterThanOrEqualTo(15));
    expect(logger.endSessionCalls, 1);
  });
}
