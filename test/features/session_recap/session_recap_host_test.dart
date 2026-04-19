import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/session_recap/session_recap_host.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  testWidgets('show() emits SessionRecapShown at open', (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);
    container.read(offlineReportProvider.notifier).state = const OfflineReport(
      earned: 200,
      elapsed: Duration(minutes: 30),
      capped: false,
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SessionRecapHost.show(
                ctx,
                ref,
                const OfflineReport(
                  earned: 200,
                  elapsed: Duration(minutes: 30),
                  capped: false,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapShown>());
    final shown = logger.events.first as SessionRecapShown;
    expect(shown.offlineDurationMs, const Duration(minutes: 30).inMilliseconds);
    expect(shown.resourceEarnedOffline, 200);
  });

  testWidgets('show() returns early when offlineReportProvider null',
      (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SessionRecapHost.show(
                ctx,
                ref,
                const OfflineReport(
                  earned: 0,
                  elapsed: Duration.zero,
                  capped: false,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(logger.events, isEmpty);
  });
}
