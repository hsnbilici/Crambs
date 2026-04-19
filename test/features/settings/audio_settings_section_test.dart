import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _appUnderTest(FakeAudioEngine fake) {
  return ProviderScope(
    overrides: [audioEngineProvider.overrideWithValue(fake)],
    child: const MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(body: AudioSettingsSection()),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('loading → CircularProgressIndicator', (tester) async {
    final fake = FakeAudioEngine();
    await fake.init();
    await tester.pumpWidget(_appUnderTest(fake));
    // Don't pumpAndSettle — we want the loading frame.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('data → 2 switches + 1 slider', (tester) async {
    final fake = FakeAudioEngine();
    await fake.init();
    await tester.pumpWidget(_appUnderTest(fake));
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('music switch tap → setMusicEnabled true + ambient starts',
      (tester) async {
    final fake = FakeAudioEngine();
    await fake.init();
    await tester.pumpWidget(_appUnderTest(fake));
    await tester.pumpAndSettle();

    final musicSwitch = find.byType(SwitchListTile).first;
    await tester.tap(musicSwitch);
    await tester.pumpAndSettle();

    // Wait one microtask for listen-driven updateSettings.
    await tester.pump(Duration.zero);
    expect(fake.loopRunning, true);
  });

  testWidgets(
    'slider drag → previewVolume every frame, setMasterVolume after 100ms',
    (tester) async {
      final fake = FakeAudioEngine();
      await fake.init();
      // Enable music so previewVolume and setLoopVolume actually fire on
      // the engine (they early-return when music is off).
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.audio_music_enabled': true,
      });
      await tester.pumpWidget(_appUnderTest(fake));
      await tester.pumpAndSettle();

      final slider = find.byType(Slider);
      // Drag — Flutter test routes through Slider.onChanged.
      await tester.drag(slider, const Offset(-50, 0));
      await tester.pump();

      // Engine should have seen at least one setLoopVolume (preview) call —
      // verified by currentVolume having changed from 0.42 baseline.
      expect(fake.currentVolume, isNot(closeTo(0.42, 1e-9)));

      // Debounced setMasterVolume persists after 100ms elapse.
      await tester.pump(const Duration(milliseconds: 120));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('crumbs.audio_master_volume'), isNotNull);
    },
  );
}
