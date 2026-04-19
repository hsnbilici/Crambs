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
  const TutorialStarted({
    required this.installId,
    required this.isReplay,
  });

  final String installId;
  final bool isReplay;

  @override
  String get eventName => 'tutorial_started';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'is_replay': isReplay,
      };
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

class PurchaseMade extends TelemetryEvent {
  const PurchaseMade({
    required this.installId,
    required this.buildingId,
    required this.cost,
    required this.ownedAfter,
  });

  final String installId;
  final String buildingId;
  final int cost;
  final int ownedAfter;

  @override
  String get eventName => 'purchase_made';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'building_id': buildingId,
        'cost': cost,
        'owned_after': ownedAfter,
      };
}

class UpgradePurchased extends TelemetryEvent {
  const UpgradePurchased({
    required this.installId,
    required this.upgradeId,
    required this.cost,
  });

  final String installId;
  final String upgradeId;
  final int cost;

  @override
  String get eventName => 'upgrade_purchased';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'upgrade_id': upgradeId,
        'cost': cost,
      };
}

class SessionRecapShown extends TelemetryEvent {
  const SessionRecapShown({
    required this.installId,
    required this.sessionId,
    required this.offlineDurationMs,
    required this.resourceEarnedOffline,
  });

  final String installId;
  final String sessionId;
  final int offlineDurationMs;
  final int resourceEarnedOffline;

  @override
  String get eventName => 'session_recap_shown';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'offline_duration_ms': offlineDurationMs,
        'resource_earned_offline': resourceEarnedOffline,
      };
}

class SessionRecapActionTaken extends TelemetryEvent {
  const SessionRecapActionTaken({
    required this.installId,
    required this.sessionId,
    required this.actionType,
  });

  final String installId;
  final String sessionId;
  final String actionType;

  @override
  String get eventName => 'session_recap_action_taken';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'action_type': actionType,
      };
}

class SessionRecapDismissed extends TelemetryEvent {
  const SessionRecapDismissed({
    required this.installId,
    required this.sessionId,
  });

  final String installId;
  final String sessionId;

  @override
  String get eventName => 'session_recap_dismissed';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
      };
}

/// Session Recap CTA action type literals. B7 enum refactor candidate —
/// spec §5.3 #12.
const String kActionCollect = 'collect';
