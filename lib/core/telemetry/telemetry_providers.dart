import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/firebase_analytics_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:crumbs/core/telemetry/install_id_notifier.dart'
    show InstallIdNotifier, installIdProvider, resolveInstallIdForTelemetry;
export 'package:crumbs/core/telemetry/session_controller.dart'
    show SessionController, sessionControllerProvider;
export 'package:crumbs/core/telemetry/telemetry_event.dart';
export 'package:crumbs/core/telemetry/telemetry_logger.dart'
    show TelemetryLogger;

/// Default TelemetryLogger — 3-state gate (invariant I14):
/// - [kDebugMode] → [DebugLogger] (debugPrint flow dev'de görünür)
/// - `!FirebaseBootstrap.isInitialized` → [DebugLogger] (Firebase init fail'de
///   silent fallback, telemetry no-op yerine debugPrint devam eder)
/// - else → [FirebaseAnalyticsLogger] (release + Firebase up path)
///
/// Test override pattern B2'den korunur:
///   ProviderScope(overrides: [
///     telemetryLoggerProvider.overrideWithValue(_FakeLogger()),
///   ])
final telemetryLoggerProvider = Provider<TelemetryLogger>((ref) {
  if (kDebugMode || !FirebaseBootstrap.isInitialized) {
    return DebugLogger();
  }
  return FirebaseAnalyticsLogger(FirebaseAnalytics.instance);
});
