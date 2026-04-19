import 'dart:io';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/widgets/tap_area.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hydrate the notifier via real-async I/O before mounting the widget.
/// testWidgets fake-async otherwise stalls the path_provider/SaveRepository
/// awaits and the notifier's 200ms tick timer leaks into pump().
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
      home: Scaffold(body: TapArea()),
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_tap_sfx_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets(
    '[I22] rapid taps within 80ms → only 1 SFX call',
    (tester) async {
      final fake = FakeAudioEngine();
      await fake.init();
      final container = await _boot(tester, fake, tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pump();

      final tap = find.byType(TapArea);
      // 10 rapid taps with no time advance between.
      for (var i = 0; i < 10; i++) {
        await tester.tap(tap);
      }
      await tester.pump();

      final tapOneShots = fake.oneShots
          .where((e) => e.$1 == 'audio/sfx/tap.ogg')
          .toList();
      expect(
        tapOneShots.length,
        1,
        reason: 'haptic+SFX throttle — 1 fire per 80ms window',
      );
    },
  );

  testWidgets(
    '[I22] taps 100ms apart → 5 SFX calls for 5 taps',
    (tester) async {
      final fake = FakeAudioEngine();
      await fake.init();
      final container = await _boot(tester, fake, tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pump();

      final tap = find.byType(TapArea);
      // Throttle uses DateTime.now() (wall clock). Use runAsync +
      // Future.delayed to advance real time past the 80ms gate between
      // taps — tester.pump(Duration) only advances fake async.
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(tap);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pump();

      final tapOneShots = fake.oneShots
          .where((e) => e.$1 == 'audio/sfx/tap.ogg')
          .toList();
      expect(tapOneShots.length, 5);
    },
  );
}
