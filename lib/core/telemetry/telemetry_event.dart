/// Immutable telemetry event hierarchy. Her event sealed — exhaustive pattern
/// match zorunlu. payload shape Firebase provider wiring'de (B3) değişmemeli.
sealed class TelemetryEvent {
  const TelemetryEvent();

  String get eventName;
  Map<String, Object?> get payload;
}

class AppInstall extends TelemetryEvent {
  const AppInstall({required this.installId, required this.platform});

  final String installId;
  final String platform;

  @override
  String get eventName => 'app_install';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'platform': platform,
      };
}

class SessionStart extends TelemetryEvent {
  const SessionStart({
    required this.installId,
    required this.sessionId,
    required this.installIdAgeMs,
  });

  final String installId;
  final String sessionId;
  final int installIdAgeMs;

  @override
  String get eventName => 'session_start';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'install_id_age_ms': installIdAgeMs,
      };
}

class SessionEnd extends TelemetryEvent {
  const SessionEnd({
    required this.installId,
    required this.sessionId,
    required this.durationMs,
  });

  final String installId;
  final String sessionId;
  final int durationMs;

  @override
  String get eventName => 'session_end';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'duration_ms': durationMs,
      };
}

class TutorialStarted extends TelemetryEvent {
  const TutorialStarted({required this.installId});

  final String installId;

  @override
  String get eventName => 'tutorial_started';

  @override
  Map<String, Object?> get payload => {'install_id': installId};
}

class TutorialCompleted extends TelemetryEvent {
  const TutorialCompleted({
    required this.installId,
    required this.skipped,
    required this.durationMs,
  });

  final String installId;
  final bool skipped;
  final int durationMs;

  @override
  String get eventName => 'tutorial_completed';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'skipped': skipped,
        'duration_ms': durationMs,
      };
}
