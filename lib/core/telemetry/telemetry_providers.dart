import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:crumbs/core/telemetry/install_id_notifier.dart'
    show InstallIdNotifier, installIdProvider, resolveInstallIdForTelemetry;
export 'package:crumbs/core/telemetry/session_controller.dart'
    show SessionController, sessionControllerProvider;
export 'package:crumbs/core/telemetry/telemetry_event.dart';
export 'package:crumbs/core/telemetry/telemetry_logger.dart'
    show TelemetryLogger;

/// Default TelemetryLogger — DebugLogger (debugPrint stub).
/// B3'te FirebaseAnalyticsLogger ile override edilir (tek nokta swap).
final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());
