import 'dart:io' show Platform;

import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart'
    show telemetryLoggerProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Cold/warm/pause session geçişlerini yöneten controller.
/// - onLaunch(isFirstLaunch: true) → AppInstall + SessionStart
/// - onLaunch(isFirstLaunch: false) → SessionStart only
/// - onResume() → yeni SessionStart (yeni session_id)
/// - onPause() → SessionEnd (durationMs hesabıyla)
///
/// session_id = UUID v4. Her yeni session için yenilenir.
class SessionController {
  SessionController(this._ref);

  final Ref _ref;
  String? _currentSessionId;
  DateTime? _sessionStartedAt;

  /// Current active session UUID; null when no session is active (pre-launch
  /// veya post-pause). SessionRecapModal telemetry wiring için public expose.
  String? get currentSessionId => _currentSessionId;

  TelemetryLogger get _logger => _ref.read(telemetryLoggerProvider);

  /// [isFirstLaunch]: true when this is the user's first session ever
  /// (no `firstLaunchMarked` pref yet). Bootstrap computes it as
  /// `!tutorialState.firstLaunchMarked`. When true, emits AppInstall +
  /// SessionStart; otherwise emits SessionStart only.
  void onLaunch({required bool isFirstLaunch}) {
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    if (isFirstLaunch) {
      _logger.log(AppInstall(
        installId: installId,
        platform: Platform.operatingSystem,
      ));
    }
    _startNewSession(installId);
  }

  /// iOS Control Center/notification peek gibi `resumed → inactive → resumed`
  /// döngülerinde onPause hiç tetiklenmez — aktif session varsa önce kapatılır
  /// (defansif kontrat, spec §6.4 invariant 4).
  void onResume() {
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    _closeActiveSession(installId);
    _startNewSession(installId);
  }

  void onPause() {
    final installId =
        resolveInstallIdForTelemetry(_ref.read(installIdProvider));
    _closeActiveSession(installId);
  }

  void _closeActiveSession(String installId) {
    if (_currentSessionId == null) return;
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
        // AppBootstrap step b'de ensureLoaded garanti; kAgeNotLoaded (-1)
        // bypass bug sinyali — integration test [I15] bu sentinel'ı reddeder.
        installIdAgeMs: _ref.read(installIdProvider.notifier).installIdAgeMs,
      ));
  }
}

final sessionControllerProvider =
    Provider<SessionController>(SessionController.new);
