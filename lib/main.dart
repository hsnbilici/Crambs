import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/error/error_screen.dart';
import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/app/routing/app_router.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/tutorial/tutorial_scaffold.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  final container = await AppBootstrap.initialize();
  await container.read(onboardingPrefsProvider.notifier).ensureLoaded();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppLifecycleGate(child: CrumbsApp()),
    ),
  );
}

class CrumbsApp extends ConsumerWidget {
  const CrumbsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gameStateNotifierProvider);
    final router = ref.watch(appRouterProvider);
    return async.when(
      data: (_) => MaterialApp.router(
        title: 'Crumbs',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        builder: (ctx, child) => TutorialScaffold(
          child: child ?? const SizedBox.shrink(),
        ),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
      ),
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: ErrorScreen(error: e),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
      ),
    );
  }
}
