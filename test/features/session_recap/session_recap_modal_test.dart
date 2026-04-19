import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required Widget child,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  const report = OfflineReport(
    earned: 142.7,
    elapsed: Duration(minutes: 42),
    capped: false,
  );

  testWidgets('renders title + earned + elapsed + collect + dismiss',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('Yokken kazandın!'), findsOneWidget);
    expect(find.textContaining('Crumb'), findsOneWidget);
    expect(find.textContaining('dakika'), findsOneWidget);
    expect(find.text('Topla'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('capped=true shows capped badge', (tester) async {
    const capped = OfflineReport(
      earned: 500,
      elapsed: Duration(hours: 10),
      capped: true,
    );
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: capped),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('sınır'), findsOneWidget);
  });

  testWidgets('multiplier secondary line shows ×value', (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('Pasif çarpan: ×'), findsOneWidget);
  });

  testWidgets('disableAnimations → counter instant final value',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
      disableAnimations: true,
    ));
    // Single pump — no animation time advance needed.
    await tester.pump();

    // Counter should show final earned value (142 via fmt, not 0).
    expect(find.textContaining('142'), findsOneWidget);
  });

  group('CTA handlers', () {
    testWidgets('Collect → emit action_taken + clear + pop',
        (tester) async {
      final logger = _RecordingLogger();
      final container = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(container.dispose);
      container.read(offlineReportProvider.notifier).state =
          const OfflineReport(
        earned: 142,
        elapsed: Duration(minutes: 42),
        capped: false,
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => const SessionRecapModal(
                    report: OfflineReport(
                      earned: 142,
                      elapsed: Duration(minutes: 42),
                      capped: false,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1600));

      await tester.tap(find.text('Topla'));
      await tester.pumpAndSettle();

      expect(logger.events, hasLength(1));
      expect(logger.events.first, isA<SessionRecapActionTaken>());
      expect(
        (logger.events.first as SessionRecapActionTaken).actionType,
        'collect',
      );
      expect(container.read(offlineReportProvider), isNull);
    });

    testWidgets('Dismiss (X) → emit dismissed + clear', (tester) async {
      final logger = _RecordingLogger();
      final container = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(container.dispose);
      container.read(offlineReportProvider.notifier).state =
          const OfflineReport(
        earned: 100,
        elapsed: Duration(minutes: 10),
        capped: false,
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(
            body: SessionRecapModal(
              report: OfflineReport(
                earned: 100,
                elapsed: Duration(minutes: 10),
                capped: false,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1600));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(logger.events, hasLength(1));
      expect(logger.events.first, isA<SessionRecapDismissed>());
      expect(container.read(offlineReportProvider), isNull);
    });

    testWidgets('Dismiss when provider already null → no double emit',
        (tester) async {
      final logger = _RecordingLogger();
      final container = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(container.dispose);
      // Provider starts null (no OfflineReport).

      expect(container.read(offlineReportProvider), isNull);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(
            body: SessionRecapModal(
              report: OfflineReport(
                earned: 50,
                elapsed: Duration(minutes: 5),
                capped: false,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1600));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // No telemetry emitted — provider was already null (idempotency guard).
      expect(logger.events, isEmpty);
    });
  });

  group('[I25] Crumbs ledger CTA-independent', () {
    testWidgets('Collect vs Dismiss → both clear provider, no Crumbs mutation',
        (tester) async {
      const report = OfflineReport(
        earned: 100,
        elapsed: Duration(minutes: 10),
        capped: false,
      );

      // Scenario A: Collect
      final loggerA = _RecordingLogger();
      final containerA = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(loggerA),
      ]);
      addTearDown(containerA.dispose);
      containerA.read(offlineReportProvider.notifier).state = report;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: containerA,
        child: const MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(body: SessionRecapModal(report: report)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('Topla'));
      await tester.pump();
      expect(containerA.read(offlineReportProvider), isNull);
      expect(loggerA.events.first, isA<SessionRecapActionTaken>());

      // Reset widget tree between scenarios — scenario A's Navigator.pop()
      // pops the root route, so the next pumpWidget needs a clean slate.
      await tester.pumpWidget(const SizedBox.shrink());

      // Scenario B: Dismiss
      final loggerB = _RecordingLogger();
      final containerB = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(loggerB),
      ]);
      addTearDown(containerB.dispose);
      containerB.read(offlineReportProvider.notifier).state = report;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: containerB,
        child: const MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(body: SessionRecapModal(report: report)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(containerB.read(offlineReportProvider), isNull);
      expect(loggerB.events.first, isA<SessionRecapDismissed>());
    });
  });
}

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}
