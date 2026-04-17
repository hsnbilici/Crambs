import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('TutorialNotifier — build() hydration', () {
    test('fresh install → firstLaunchMarked=false + completed=false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.firstLaunchMarked, false);
      expect(state.tutorialCompleted, false);
      expect(state.currentStep, null);
    });

    test('firstLaunchMarked persisted → reflected in state', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.firstLaunchMarked, true);
    });

    test('tutorialCompleted persisted → reflected in state', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.tutorialCompleted, true);
    });

    test('currentStep is never persisted — always null after hydrate',
        () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': false,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.currentStep, null);
    });
  });

  group('TutorialNotifier — start()', () {
    test('fresh install → currentStep=tapCupcake + firstLaunchMarked=true',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.currentStep, TutorialStep.tapCupcake);
      expect(state.firstLaunchMarked, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_marked'), true);
    });

    test('idempotent — second call no-op when currentStep already set',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      final notifier = c.read(tutorialNotifierProvider.notifier);
      await notifier.start();
      await notifier.start();
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.tapCupcake);
    });

    test('no-op if firstLaunchMarked already true', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });

    test('no-op if tutorialCompleted=true', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });
  });

  group('TutorialNotifier — advance()', () {
    Future<ProviderContainer> startedContainer() async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      return c;
    }

    test('tapCupcake → openShop', () async {
      final c = await startedContainer();
      c
          .read(tutorialNotifierProvider.notifier)
          .advance(from: TutorialStep.tapCupcake);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.openShop);
    });

    test('openShop → explainCrumbs', () async {
      final c = await startedContainer();
      c.read(tutorialNotifierProvider.notifier)
        ..advance(from: TutorialStep.tapCupcake)
        ..advance(from: TutorialStep.openShop);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.explainCrumbs);
    });

    test('re-entry guard — wrong from → no-op', () async {
      final c = await startedContainer();
      c
          .read(tutorialNotifierProvider.notifier)
          .advance(from: TutorialStep.explainCrumbs);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.tapCupcake);
    });

    test('explainCrumbs advance → currentStep becomes null', () async {
      final c = await startedContainer();
      c.read(tutorialNotifierProvider.notifier)
        ..advance(from: TutorialStep.tapCupcake)
        ..advance(from: TutorialStep.openShop)
        ..advance(from: TutorialStep.explainCrumbs);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });
  });

  group('TutorialNotifier — skip() + complete()', () {
    test('skip → completed=true + currentStep=null + disk write', () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      await c.read(tutorialNotifierProvider.notifier).skip();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.tutorialCompleted, true);
      expect(state.currentStep, null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.tutorial_completed'), true);
    });

    test('complete → completed=true + currentStep=null + disk write',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      await c.read(tutorialNotifierProvider.notifier).complete();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.tutorialCompleted, true);
      expect(state.currentStep, null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.tutorial_completed'), true);
    });
  });
}
