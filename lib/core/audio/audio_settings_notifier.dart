import 'package:crumbs/core/audio/audio_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSettingsNotifier extends AsyncNotifier<AudioSettings> {
  static const _prefMusic = 'crumbs.audio_music_enabled';
  static const _prefSfx = 'crumbs.audio_sfx_enabled';
  static const _prefVolume = 'crumbs.audio_master_volume';

  @override
  Future<AudioSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioSettings(
      musicEnabled: prefs.getBool(_prefMusic) ?? false,
      sfxEnabled: prefs.getBool(_prefSfx) ?? true,
      masterVolume: prefs.getDouble(_prefVolume) ?? 0.7,
    );
  }

  Future<void> setMusicEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefMusic, enabled);
    state = AsyncData(state.requireValue.copyWith(musicEnabled: enabled));
  }

  Future<void> setSfxEnabled({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSfx, enabled);
    state = AsyncData(state.requireValue.copyWith(sfxEnabled: enabled));
  }

  Future<void> setMasterVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefVolume, clamped);
    state = AsyncData(state.requireValue.copyWith(masterVolume: clamped));
  }
}

final audioSettingsProvider =
    AsyncNotifierProvider<AudioSettingsNotifier, AudioSettings>(
  AudioSettingsNotifier.new,
);
