import 'dart:async';

import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/core/launch/first_boot_notifier.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cold boot sequence (spec §6.1):
///   a. ensureInitialized + SharedPreferences warm
///   b. installIdProvider.ensureLoaded()
///   c. gameStateNotifierProvider.future (hydrate + migration)
///   d. installIdProvider.adoptFromGameState(gs.meta.installId)
///      (GameState-wins: save dosyası authoritative, disk overwrite)
///   e. tutorialNotifierProvider.future (hydrate; flicker guard \[I11\])
///   f. sessionController.onLaunch(isFirstLaunch)
class AppBootstrap {
  const AppBootstrap._();

  /// [containerFactory] — test hook; production callers omit it.
  /// Allows tests to inject a pre-configured ProviderContainer with
  /// overrides (e.g. a temp-dir SaveRepository) without requiring
  /// Override to be part of the public API surface.
  static Future<BootstrapResult> initialize({
    ProviderContainer Function()? containerFactory,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await SharedPreferences.getInstance();
    final container = containerFactory != null
        ? containerFactory()
        : ProviderContainer();

    await container.read(installIdProvider.notifier).ensureLoaded();

    // B4 YENİ — step b': FirstBootNotifier observe (AppInstall trigger
    // source — tutorial state'inden disjoint, invariant I18)
    final isFirstLaunch =
        await container.read(firstBootProvider.notifier).ensureObserved();

    final gs = await container.read(gameStateNotifierProvider.future);
    await container
        .read(installIdProvider.notifier)
        .adoptFromGameState(gs.meta.installId);

    // B3 YENİ — step d' Crashlytics user identity
    // fire-and-forget: platform channel roundtrip ~50-200ms boot'u bloklamaz.
    // isInitialized guard: Firebase init fail'de silent skip.
    if (FirebaseBootstrap.isInitialized) {
      unawaited(
        FirebaseCrashlytics.instance.setUserIdentifier(gs.meta.installId),
      );
    }

    await container.read(tutorialNotifierProvider.future);

    // B4 DEĞİŞTİ — isFirstLaunch firstBootProvider'dan okunur (step b'),
    // tutorialState.firstLaunchMarked usage kaldırıldı
    container
        .read(sessionControllerProvider)
        .onLaunch(isFirstLaunch: isFirstLaunch);

    return BootstrapResult(container: container);
  }
}

class BootstrapResult {
  const BootstrapResult({required this.container});
  final ProviderContainer container;
}
