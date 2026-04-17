import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/app/routing/app_router.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
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
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Crumbs',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
    );
  }
}
