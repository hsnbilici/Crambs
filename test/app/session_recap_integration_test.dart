import 'dart:io';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
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

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_b6_e2e_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
      'E2E: cold-start offlineReport → modal → Collect → next mount clean',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 250,
      elapsed: Duration(minutes: 45),
      capped: false,
    );

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
      container.read(offlineReportProvider.notifier).state = report;
    });

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

    // Modal shown
    expect(find.byType(SessionRecapModal), findsOneWidget);
    expect(logger.events.where((e) => e is SessionRecapShown), hasLength(1));
    final shown = logger.events
        .firstWhere((e) => e is SessionRecapShown) as SessionRecapShown;
    expect(shown.resourceEarnedOffline, 250);
    expect(shown.offlineDurationMs,
        const Duration(minutes: 45).inMilliseconds);

    // Collect
    await tester.tap(find.text('Topla'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Modal gone, provider cleared
    expect(find.byType(SessionRecapModal), findsNothing);
    expect(container.read(offlineReportProvider), isNull);
    expect(logger.events.where((e) => e is SessionRecapActionTaken),
        hasLength(1));

    // Simulate next session — provider stays null, no modal
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
    expect(logger.events, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}
