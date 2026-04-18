import 'dart:async' show unawaited;

import 'package:crumbs/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase core bootstrap — main()'de AppBootstrap ÖNCESİ çağrılır.
///
/// 3-phase strateji:
/// - **Phase 1 (fatal):** Firebase.initializeApp — fail'de early return,
///   `_initialized=false`, app Firebase'siz devam eder (telemetry no-op).
/// - **Phase 2 (best-effort):** setAnalyticsCollectionEnabled +
///   setCrashlyticsCollectionEnabled — fail loglanır ama init çökertmez
///   (native Firebase.instance preserved, sonraki launch'ta duplicate app
///   hatası önlenir).
/// - **Phase 3 (sync):** FlutterError.onError + PlatformDispatcher.onError
///   register — exception atmaz.
///
/// `isInitialized` flag telemetry logger gate'i için okur (telemetry_providers
/// 3-state gate). Phase 2/3 tamamlanmadan true olmaz.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    // Phase 1 — fatal init (native Firebase app binding)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on Object catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] initializeApp failed, '
        'telemetry disabled: $e\n$st',
      );
      return; // _initialized false kalır
    }

    // Phase 2 — best-effort data transmission gate
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(!kDebugMode);
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    } on Object catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] collection flag set failed '
        '(non-fatal): $e\n$st',
      );
      // Devam — Firebase platform default'larıyla çalışır.
    }

    // Phase 3 — sync handler register (exception atmaz)
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
      return true;
    };
    _initialized = true;
  }
}
