import 'dart:io' show Platform;

import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Telemetry logger provider — default DebugLogger.
/// B3'te FirebaseAnalyticsLogger ile override edilecek (tek satır).
/// Not: Bu provider T5'te telemetry_providers.dart barrel'a taşınacak.
final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());

/// Cold/warm/pause session geçişlerini yöneten controller.
/// - onLaunch(firstLaunchMarkedBefore: true) → AppInstall + SessionStart
/// - onLaunch(firstLaunchMarkedBefore: false) → SessionStart only
/// - onResume() → yeni SessionStart (yeni session_id)
/// - onPause() → SessionEnd (durationMs hesabıyla)
///
/// session_id = UUID v4. Her yeni session için yenilenir.
class SessionController {
  SessionController(this._ref);

  final Ref _ref;
  String? _currentSessionId;
  DateTime? _sessionStartedAt;

  TelemetryLogger get _logger => _ref.read(telemetryLoggerProvider);

  void onLaunch({required bool firstLaunchMarkedBefore}) {
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    if (firstLaunchMarkedBefore) {
      _logger.log(AppInstall(
        installId: installId,
        platform: Platform.operatingSystem,
      ));
    }
    _startNewSession(installId);
  }

  void onResume() {
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    _startNewSession(installId);
  }

  void onPause() {
    if (_currentSessionId == null) return;
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    final duration = DateTime.now().difference(_sessionStartedAt!);
    _logger
      ..log(SessionEnd(
        installId: installId,
        sessionId: _currentSessionId!,
        durationMs: duration.inMilliseconds,
      ))
      ..endSession();
    _currentSessionId = null;
    _sessionStartedAt = null;
  }

  void _startNewSession(String installId) {
    _currentSessionId = const Uuid().v4();
    _sessionStartedAt = DateTime.now();
    _logger
      ..beginSession()
      ..log(SessionStart(
        installId: installId,
        sessionId: _currentSessionId!,
      ));
  }
}

final sessionControllerProvider =
    Provider<SessionController>(SessionController.new);
