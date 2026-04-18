import 'package:crumbs/core/telemetry/telemetry_event.dart';

/// Abstract telemetry sink. B2'de DebugLogger impl edilir; B3'te Firebase
/// Analytics provider bu interface'i override'lar. Session hook'ları Firebase
/// lifecycle entegrasyonu için placeholder — DebugLogger'da marker print.
abstract class TelemetryLogger {
  void log(TelemetryEvent event);
  void beginSession();
  void endSession();
}
