import 'dart:io';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget test — UpgradeRow.onBuy success/fail paths emit correct SFX cues.
///
/// Mirrors building_row_sfx_test pattern. Upgrade `golden_recipe_i` base
/// cost 200 → 205 crumb_collector-free taps grant headroom.
Future<ProviderContainer> _boot(
  WidgetTester tester,
  FakeAudioEngine fake,
  Directory tempDir,
) async {
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(overrides: [
      audioEngineProvider.overrideWithValue(fake),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
    ]);
    await container.read(gameStateNotifierProvider.future);
  });
  return container;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: UpgradeRow(
          id: 'golden_recipe_i',
          displayName: 'Altın Tarif I',
        ),
      ),
    ),
  );
}

Future<void> _teardown(WidgetTester tester, ProviderContainer c) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  c.dispose();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_upg_sfx_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('tap buy with sufficient crumbs → upgradeBuy cue',
      (tester) async {
    final fake = FakeAudioEngine();
    await fake.init();
    final container = await _boot(tester, fake, tempDir);

    // Grant enough crumbs (golden_recipe_i cost 200 → 205 taps).
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 205; i++) {
      notifier.tapCrumb();
    }

    await tester.pumpWidget(_app(container));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 1));

    final upgradeCues = fake.oneShots
        .where((e) => e.$1 == 'audio/sfx/upgrade.ogg')
        .toList();
    expect(
      upgradeCues.length,
      1,
      reason: 'Successful upgrade must emit exactly one upgradeBuy cue',
    );

    await _teardown(tester, container);
  });

  testWidgets('tap buy with insufficient crumbs → NO cue',
      (tester) async {
    final fake = FakeAudioEngine();
    await fake.init();
    final container = await _boot(tester, fake, tempDir);

    await tester.pumpWidget(_app(container));
    await tester.pump(const Duration(milliseconds: 1));

    // Fresh install — zero crumbs, can't afford 200-cost upgrade.
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 1));

    final upgradeCues = fake.oneShots
        .where((e) => e.$1 == 'audio/sfx/upgrade.ogg')
        .toList();
    expect(
      upgradeCues,
      isEmpty,
      reason:
          'Failed upgrade must not emit cue (audio feedback for success only)',
    );

    await _teardown(tester, container);
  });
}
