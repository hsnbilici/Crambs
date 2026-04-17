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
          .onLaunch(firstLaunchMarkedBefore: firstLaunchBefore);

      // Mount sim: TutorialScaffold postFrame start()
      await c.read(tutorialNotifierProvider.notifier).start();
      if (c.read(tutorialNotifierProvider).value?.currentStep ==
          TutorialStep.tapCupcake) {
        logger.log(TutorialStarted(
          installId: resolveInstallIdForTelemetry(
            c.read(installIdProvider),
          ),
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
          .onLaunch(firstLaunchMarkedBefore: firstLaunchBefore);

      await c.read(tutorialNotifierProvider.notifier).start();

      expect(logger.events.whereType<AppInstall>(), isEmpty);
      expect(logger.events.whereType<TutorialStarted>(), isEmpty);
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
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
          .onLaunch(firstLaunchMarkedBefore: false);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.read(sessionControllerProvider).onPause();

      final end = logger.events.whereType<SessionEnd>().single;
      expect(end.durationMs, greaterThanOrEqualTo(20));
      expect(end.installId, 'integ-test');
    });
  });
}
