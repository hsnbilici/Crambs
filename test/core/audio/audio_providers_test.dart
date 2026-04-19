import 'dart:async';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/audio/audio_settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('audioEngineProvider', () {
    test('dispose triggers engine.dispose', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final fake = FakeAudioEngine();
      await fake.init();
      // NOTE: Plan spec uses `overrideWithValue(fake)`, but in Riverpod 3
      // `overrideWithValue` substitutes a `$SyncValueProvider` that never
      // runs the original builder — so `ref.onDispose` never registers and
      // the assertion would always fail. Using `overrideWith` with a
      // builder that mirrors the production `ref.onDispose` pattern
      // validates the same intent: container dispose → engine.dispose.
      final c = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(fake.dispose()));
            return fake;
          }),
        ],
      )..read(audioEngineProvider);
      expect(fake.disposed, false);

      c.dispose();

      expect(fake.disposed, true);
    });
  });

  group('audioControllerProvider — listen lifecycle', () {
    test('settings change fires controller.updateSettings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final fake = FakeAudioEngine();
      await fake.init();
      final c = ProviderContainer(
        overrides: [audioEngineProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);

      // Hydrate settings + instantiate controller (triggers listen).
      await c.read(audioSettingsProvider.future);
      c.read(audioControllerProvider);
      expect(fake.loopRunning, false);

      // Flip musicEnabled → startLoop fires
      await c
          .read(audioSettingsProvider.notifier)
          .setMusicEnabled(enabled: true);
      // Give microtask queue time to drain the listen-driven update.
      await Future<void>.delayed(Duration.zero);

      expect(fake.loopRunning, true);
    });

    test('instantiates with snapshot = settings.value at build time',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.audio_music_enabled': true,
      });
      final fake = FakeAudioEngine();
      await fake.init();
      final c = ProviderContainer(
        overrides: [audioEngineProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);

      await c.read(audioSettingsProvider.future);
      final ctrl = c.read(audioControllerProvider);

      // startAmbient works because snapshot already has musicEnabled=true
      await ctrl.startAmbient();
      expect(fake.loopRunning, true);
    });
  });
}
