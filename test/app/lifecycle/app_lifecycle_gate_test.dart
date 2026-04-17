import 'dart:io';

import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_gate_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('onPause triggers save; onResume applies delta', (tester) async {
    // Real I/O hydration (SaveRepository.load + SharedPreferences) must
    // happen in runAsync; testWidgets fake-async otherwise stalls disk
    // awaits and the notifier's 200ms tick timer leaks into pump().
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = ProviderContainer(overrides: [
        saveRepositoryProvider.overrideWithValue(
          SaveRepository(directoryProvider: () async => tempDir.path),
        ),
      ]);
      await container.read(gameStateNotifierProvider.future);
      final notifier = container.read(gameStateNotifierProvider.notifier);
      for (var i = 0; i < 15; i++) {
        notifier.tapCrumb();
      }
      await notifier.buyBuilding('crumb_collector');
    });
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: AppLifecycleGate(child: SizedBox.shrink()),
      ),
    ));

    // Paused → save. persistNow issues real File I/O, so drain it via
    // runAsync before asserting file existence. AppLifecycleListener
    // requires the canonical transition inactive → hidden → paused.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(() async {
      // Yield so AppLifecycleListener's onPause microtask + persist I/O flush.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    final saveFile = File('${tempDir.path}/crumbs_save.json');
    expect(saveFile.existsSync(), isTrue);

    // Resume → applyResumeDelta (sync) + resetTickClock (sync). Canonical
    // wake path is paused → hidden → inactive → resumed.
    final beforeResume =
        container.read(gameStateNotifierProvider).value!.inventory.r1Crumbs;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    final afterResume =
        container.read(gameStateNotifierProvider).value!.inventory.r1Crumbs;
    expect(afterResume, greaterThanOrEqualTo(beforeResume));
  });
}
