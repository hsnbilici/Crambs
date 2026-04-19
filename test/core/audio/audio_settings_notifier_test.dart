import 'package:crumbs/core/audio/audio_settings.dart';
import 'package:crumbs/core/audio/audio_settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('AudioSettingsNotifier — build() hydration', () {
    test('fresh install → defaults (false/true/0.7)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      final s = await c.read(audioSettingsProvider.future);
      expect(s, const AudioSettings.defaults());
    });

    test('persisted values reflected', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.audio_music_enabled': true,
        'crumbs.audio_sfx_enabled': false,
        'crumbs.audio_master_volume': 0.3,
      });
      final c = buildContainer();
      final s = await c.read(audioSettingsProvider.future);
      expect(s.musicEnabled, true);
      expect(s.sfxEnabled, false);
      expect(s.masterVolume, 0.3);
    });
  });

  group('AudioSettingsNotifier — setters', () {
    test('setMusicEnabled writes prefs + updates state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(audioSettingsProvider.future);
      await c
          .read(audioSettingsProvider.notifier)
          .setMusicEnabled(enabled: true);

      final state = c.read(audioSettingsProvider).requireValue;
      expect(state.musicEnabled, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.audio_music_enabled'), true);
    });

    test('setSfxEnabled writes prefs + updates state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(audioSettingsProvider.future);
      await c
          .read(audioSettingsProvider.notifier)
          .setSfxEnabled(enabled: false);

      final state = c.read(audioSettingsProvider).requireValue;
      expect(state.sfxEnabled, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.audio_sfx_enabled'), false);
    });

    test('setMasterVolume writes prefs + updates state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(audioSettingsProvider.future);
      await c.read(audioSettingsProvider.notifier).setMasterVolume(0.4);

      final state = c.read(audioSettingsProvider).requireValue;
      expect(state.masterVolume, 0.4);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('crumbs.audio_master_volume'), 0.4);
    });

    test('setMasterVolume clamps out-of-range', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(audioSettingsProvider.future);
      final n = c.read(audioSettingsProvider.notifier);
      await n.setMasterVolume(1.5);
      expect(c.read(audioSettingsProvider).requireValue.masterVolume, 1.0);
      await n.setMasterVolume(-0.2);
      expect(c.read(audioSettingsProvider).requireValue.masterVolume, 0.0);
    });
  });
}
