import 'dart:io';

import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget-level test for invariant `[I23]` onPause/onResume ordering.
///
/// Asserts strict triple-order by logging all three sites into a shared
/// list: `audio.pauseLoop`, `persist.save`, `session.onPause` (onPause);
/// `session.onResume`, `audio.resumeLoop` (onResume).
///
/// Runs via `flutter test` (no simulator needed) — binding lifecycle
/// events are simulated via `tester.binding.handleAppLifecycleStateChanged`.
class _LoggingAudioEngine extends FakeAudioEngine {
  _LoggingAudioEngine(this.log);
  final List<String> log;

  @override
  Future<void> pauseLoop() async {
    log.add('audio.pauseLoop');
    await super.pauseLoop();
  }

  @override
  Future<void> resumeLoop() async {
    log.add('audio.resumeLoop');
    await super.resumeLoop();
  }
}

class _LoggingSaveRepository extends SaveRepository {
  _LoggingSaveRepository(this.log, String dirPath)
      : super(directoryProvider: () async => dirPath);
  final List<String> log;

  @override
  Future<void> save(SaveEnvelope envelope) async {
    log.add('persist.save');
    await super.save(envelope);
  }
}

class _LoggingSessionController extends SessionController {
  // Parent's param is private `_ref`; test-local public `ref` forwards.
  // ignore: matching_super_parameters
  _LoggingSessionController(super.ref, this.log);
  final List<String> log;

  @override
  void onPause() {
    log.add('session.onPause');
    super.onPause();
  }

  @override
  void onResume() {
    log.add('session.onResume');
    super.onResume();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'crumbs.audio_music_enabled': true,
    });
    tempDir = await Directory.systemTemp.createTemp('crumbs_i23_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
      '[I23] onPause strict order: audio → persist → session',
      (tester) async {
    final log = <String>[];
    final fake = _LoggingAudioEngine(log);
    await fake.init();

    // Pre-boot container with real hydrate — otherwise gameStateNotifier
    // stays AsyncLoading and persistNow() state==null early-returns (skips
    // SaveRepository.save entirely).
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = ProviderContainer(overrides: [
        audioEngineProvider.overrideWithValue(fake),
        saveRepositoryProvider.overrideWithValue(
          _LoggingSaveRepository(log, tempDir.path),
        ),
        sessionControllerProvider.overrideWith(
          (ref) => _LoggingSessionController(ref, log),
        ),
      ]);
      await container.read(gameStateNotifierProvider.future);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppLifecycleGate(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    log.clear(); // Discard any build-time side effects.

    // Canonical pause transition (CLAUDE.md §12 AppLifecycleListener pattern).
    await tester.runAsync(() async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // Real-async wait so path_provider I/O + persist completes.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    final audioIdx = log.indexOf('audio.pauseLoop');
    final persistIdx = log.indexOf('persist.save');
    final sessionIdx = log.indexOf('session.onPause');

    expect(audioIdx, greaterThanOrEqualTo(0),
        reason: 'pauseLoop must fire on pause');
    expect(persistIdx, greaterThan(audioIdx),
        reason: 'persist.save must come AFTER audio.pauseLoop');
    expect(sessionIdx, greaterThan(persistIdx),
        reason: 'session.onPause must come AFTER persist.save');

    // Drain pending GameStateNotifier 200ms tick + unmount before end.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets(
      '[I23] onResume order: session → audio (audio last)',
      (tester) async {
    final log = <String>[];
    final fake = _LoggingAudioEngine(log);
    await fake.init();

    late ProviderContainer container;
    await tester.runAsync(() async {
      container = ProviderContainer(overrides: [
        audioEngineProvider.overrideWithValue(fake),
        saveRepositoryProvider.overrideWithValue(
          _LoggingSaveRepository(log, tempDir.path),
        ),
        sessionControllerProvider.overrideWith(
          (ref) => _LoggingSessionController(ref, log),
        ),
      ]);
      await container.read(gameStateNotifierProvider.future);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AppLifecycleGate(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    // Pause first to build up the resume path.
    await tester.runAsync(() async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    log.clear();

    await tester.runAsync(() async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    final sessionIdx = log.indexOf('session.onResume');
    final audioIdx = log.indexOf('audio.resumeLoop');

    expect(sessionIdx, greaterThanOrEqualTo(0),
        reason: 'session.onResume must fire');
    expect(audioIdx, greaterThanOrEqualTo(0),
        reason: 'resumeLoop must fire (music was enabled)');
    expect(audioIdx, greaterThan(sessionIdx),
        reason: 'audio.resumeLoop must come AFTER session.onResume '
            '(audio is last in resume chain)');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}
