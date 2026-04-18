import 'package:crumbs/core/launch/first_boot_notifier.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tutorial + Telemetry end-to-end', () {
    testWidgets('cold start emits AppInstall + SessionStart + TutorialStarted',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot sim (mirrors AppBootstrap.initialize order)
      await c.read(installIdProvider.notifier).ensureLoaded();
      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      final tutorialState =
          await c.read(tutorialNotifierProvider.future);
      final firstLaunchBefore = !tutorialState.firstLaunchMarked;
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: firstLaunchBefore);

      // Mount sim: TutorialScaffold postFrame start()
      await c.read(tutorialNotifierProvider.notifier).start();
      if (c.read(tutorialNotifierProvider).value?.currentStep ==
          TutorialStep.tapHero) {
        final isReplay = c
            .read(tutorialNotifierProvider.notifier)
            .consumeReplayFlag();
        logger.log(TutorialStarted(
          installId: resolveInstallIdForTelemetry(
            c.read(installIdProvider),
          ),
          isReplay: isReplay,
        ));
      }

      expect(logger.events.whereType<AppInstall>(), hasLength(1));
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
      expect(logger.events.whereType<TutorialStarted>(), hasLength(1));

      // Invariant I1: install_id never <not-loaded>
      for (final e in logger.events) {
        final id = e.payload['install_id']! as String;
        expect(id, isNot(InstallIdNotifier.kNotLoadedSentinel));
      }

      // Invariant [I15]: SessionStart.installIdAgeMs >= 0
      // (kAgeNotLoaded reddedilir)
      for (final e in logger.events.whereType<SessionStart>()) {
        expect(
          e.installIdAgeMs,
          isNot(InstallIdNotifier.kAgeNotLoaded),
          reason: "-1 sentinel production emission'da görülmemeli",
        );
        expect(e.installIdAgeMs, greaterThanOrEqualTo(0));
      }

      // B4 — TutorialStarted.isReplay=false (fresh install [I20])
      final tutorialEvents = logger.events.whereType<TutorialStarted>();
      expect(tutorialEvents, hasLength(1));
      expect(tutorialEvents.single.isReplay, false,
          reason: 'fresh install — not replay');
    });

    testWidgets('second cold start → no TutorialStarted', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_marked': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      await c.read(installIdProvider.notifier).ensureLoaded();
      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      final tutorialState =
          await c.read(tutorialNotifierProvider.future);
      final firstLaunchBefore = !tutorialState.firstLaunchMarked;
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: firstLaunchBefore);

      await c.read(tutorialNotifierProvider.notifier).start();

      expect(logger.events.whereType<AppInstall>(), isEmpty);
      expect(logger.events.whereType<TutorialStarted>(), isEmpty);
      expect(logger.events.whereType<SessionStart>(), hasLength(1));

      // Invariant [I15]: installIdAgeMs >= 0 in production
      for (final e in logger.events.whereType<SessionStart>()) {
        expect(
          e.installIdAgeMs,
          isNot(InstallIdNotifier.kAgeNotLoaded),
        );
        expect(e.installIdAgeMs, greaterThanOrEqualTo(0));
      }
    });

    testWidgets('onPause emits SessionEnd with duration', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'integ-test',
        'crumbs.first_launch_marked': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(gameStateNotifierProvider.future);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.read(sessionControllerProvider).onPause();

      final end = logger.events.whereType<SessionEnd>().single;
      expect(end.durationMs, greaterThanOrEqualTo(20));
      expect(end.installId, 'integ-test');
    });

    testWidgets(
        'pre-B4 migration: install_id mevcut → no AppInstall emit [I18]',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
        'crumbs.install_created_at': DateTime.now().toIso8601String(),
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot sim — FirstBootNotifier pre-B4 user detect → observed=false
      await c.read(installIdProvider.notifier).ensureLoaded();
      final isFirstLaunch =
          await c.read(firstBootProvider.notifier).ensureObserved();
      expect(isFirstLaunch, false, reason: 'pre-B4 backfill');

      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: isFirstLaunch);

      // [I18]: AppInstall emit edilmemeli
      expect(logger.events.whereType<AppInstall>(), isEmpty,
          reason: 'pre-B4 migration — AppInstall suppressed [I18]');

      // SessionStart yine emit edilir (her launch'ta)
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
    });

    testWidgets(
        'post-reset replay: TutorialStarted isReplay=true [I18]+[I20]',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'test-id',
        'crumbs.install_created_at': DateTime.now().toIso8601String(),
        'crumbs.first_launch_observed': true,
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot sim — second launch (AppInstall edilmez, tutorial completed)
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(firstBootProvider.notifier).ensureObserved();
      await c.read(gameStateNotifierProvider.future);
      await c.read(tutorialNotifierProvider.future);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      logger.events.clear(); // pre-reset noise

      // Reset → sonraki start isReplay=true
      await c.read(tutorialNotifierProvider.notifier).reset();
      final isReplay = c
          .read(tutorialNotifierProvider.notifier)
          .consumeReplayFlag();

      // Simulate TutorialScaffold emission
      if (isReplay) {
        logger.log(TutorialStarted(
          installId: resolveInstallIdForTelemetry(
            c.read(installIdProvider),
          ),
          isReplay: true,
        ));
      }

      // [I18]: reset AppInstall re-emit ETMEZ
      expect(logger.events.whereType<AppInstall>(), isEmpty,
          reason: 'tutorial reset — no AppInstall [I18]');

      // [I20]: TutorialStarted isReplay=true
      final tutorialEvents = logger.events.whereType<TutorialStarted>();
      expect(tutorialEvents, hasLength(1));
      expect(tutorialEvents.single.isReplay, true,
          reason: 'reset flow — isReplay=true [I20]');
    });
  });
}
