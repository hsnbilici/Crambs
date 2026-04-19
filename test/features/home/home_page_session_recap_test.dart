import 'dart:io';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/home/home_page.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  Directory tempDir,
  TelemetryLogger logger,
  OfflineReport? report,
) async {
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(overrides: [
      audioEngineProvider.overrideWithValue(FakeAudioEngine()),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    await container.read(gameStateNotifierProvider.future);
    if (report != null) {
      container.read(offlineReportProvider.notifier).state = report;
    }
  });
  return container;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_b6_home_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('cold-start with offlineReport → modal shown, emitted',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 150,
      elapsed: Duration(minutes: 20),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(SessionRecapModal), findsOneWidget);
    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapShown>());

    // Teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('no offlineReport → no modal', (tester) async {
    final logger = _RecordingLogger();
    final container = await _boot(tester, tempDir, logger, null);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(logger.events, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('earned.toInt() == 0 → no modal', (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 0.3, // int floor = 0
      elapsed: Duration(minutes: 1),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(logger.events, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('Collect CTA → clear + next mount no re-show [I26]',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 80,
      elapsed: Duration(minutes: 15),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.tap(find.text('Topla'));
    // Pop + reverse transition (~200ms). Two pumps ensure route removal
    // settles in fake-async before assertion.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(container.read(offlineReportProvider), isNull);

    // Simulate re-mount (navigation away + back). Provider null → no modal.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    // shown + action_taken from first mount only; no new events on re-mount.
    expect(logger.events.length, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}
