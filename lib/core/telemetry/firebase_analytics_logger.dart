import 'dart:async';

import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Analytics'e TelemetryEvent adapter.
///
/// **Payload coercion:** Firebase Analytics `logEvent(parameters)` sadece
/// `String/int/double` kabul eder (bool desteklenmez). `bool → int` çevrilir
/// (true=1, false=0), null değerler drop edilir.
///
/// **Fire-and-forget:** `unawaited(logEvent)` UI latency optimize eder.
/// Hızlı ardışık event'lerde Firebase SDK emission sırası GARANTİLİ DEĞİL
/// (platform channel queueing). B3 event cadence saatlik/session seviyesinde;
/// ordering issue yok. Daha sıkı ordering gerekirse Completer chain B4'te.
///
/// **Session hooks:** Firebase Analytics otomatik session tracking yapar
/// (engagement time). Manual session API yok — beginSession/endSession no-op.
class FirebaseAnalyticsLogger implements TelemetryLogger {
  FirebaseAnalyticsLogger(this._analytics);
  final FirebaseAnalytics _analytics;

  @override
  void log(TelemetryEvent event) {
    final params = <String, Object>{};
    for (final entry in event.payload.entries) {
      final value = entry.value;
      if (value == null) continue;
      params[entry.key] = value is bool ? (value ? 1 : 0) : value;
    }
    unawaited(
      _analytics.logEvent(name: event.eventName, parameters: params),
    );
  }

  @override
  void beginSession() {}

  @override
  void endSession() {}
}
