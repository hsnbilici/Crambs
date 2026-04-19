import 'dart:async';

import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/app/error/error_screen.dart';
import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/app/routing/app_router.dart';
import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/audio/audio_settings_notifier.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/tutorial/tutorial_scaffold.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize(); // B3 — AppBootstrap ÖNCESİ
  final boot = await AppBootstrap.initialize();
  await boot.container
      .read(onboardingPrefsProvider.notifier)
      .ensureLoaded();

  // B5 — await audio settings hydrate BEFORE runApp. Otherwise
  // audioControllerProvider's first read falls back to AudioSettings.defaults()
  // (sfxEnabled=true) while disk may have sfxEnabled=false persisted;
  // <100ms pre-hydrate tap would play SFX the user disabled.
  // Prefs I/O cost ~10-50ms; acceptable cold-start addition.
  await boot.container.read(audioSettingsProvider.future);

  // B5 — audio engine lazy init (fire-and-forget).
  // Cold start uncoupled from platform audio config (200-500ms).
  // Pre-init plays are safely queued via _initCompleter race guard.
  unawaited(Future.microtask(
    () => boot.container.read(audioEngineProvider).init(),
  ));

  runApp(
    UncontrolledProviderScope(
      container: boot.container,
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
