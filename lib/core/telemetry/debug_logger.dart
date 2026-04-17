import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter/foundation.dart';

/// Stub TelemetryLogger — tüm event'leri debugPrint'e yazar.
/// Format: `[TELEMETRY] <eventName> <payload>`.
/// Production swap: B3'te Firebase Analytics logger bu class'ı değiştirir.
class DebugLogger implements TelemetryLogger {
  @override
  void log(TelemetryEvent event) {
    debugPrint('[TELEMETRY] ${event.eventName} ${event.payload}');
  }

  @override
  void beginSession() {
    debugPrint('[TELEMETRY] beginSession');
  }

  @override
  void endSession() {
    debugPrint('[TELEMETRY] endSession');
  }
}
