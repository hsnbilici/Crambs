import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:crumbs/features/tutorial/tutorial_scaffold.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _appUnderTest(ProviderContainer container) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: Text('home')),
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const Scaffold(body: Text('shop')),
    ),
  ]);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      locale: const Locale('tr'),
      builder: (ctx, child) => TutorialScaffold(
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('TutorialScaffold — loading guard [I11]', () {
    testWidgets('does not render overlay while AsyncNotifier loading',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      // First frame: AsyncNotifier.build() henüz resolve olmadı
      // Note: MaterialApp Navigator baseline is 1 ModalBarrier.
      // TutorialScaffold must NOT add its own overlay here.
      final baselineBarriers = find.byType(ModalBarrier).evaluate().length;
      expect(baselineBarriers, lessThanOrEqualTo(1));
    });
  });

  group('TutorialScaffold — step render', () {
    testWidgets('starts tutorial when !firstLaunchMarked', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Hydration + start() executes via postFrame in TutorialScaffold.
      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.currentStep, TutorialStep.tapHero);
      expect(state.firstLaunchMarked, true);
    });

    testWidgets('no tutorial when tutorialCompleted=true', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.currentStep, null);
    });
  });
}
