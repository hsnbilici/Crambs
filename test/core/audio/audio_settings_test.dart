import 'package:crumbs/core/audio/audio_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioSettings.defaults()', () {
    test('musicEnabled=false, sfxEnabled=true, masterVolume=0.7', () {
      const s = AudioSettings.defaults();
      expect(s.musicEnabled, false);
      expect(s.sfxEnabled, true);
      expect(s.masterVolume, 0.7);
    });
  });

  group('AudioSettings.copyWith', () {
    test('single-field update preserves others', () {
      const a = AudioSettings.defaults();
      final b = a.copyWith(musicEnabled: true);
      expect(b.musicEnabled, true);
      expect(b.sfxEnabled, a.sfxEnabled);
      expect(b.masterVolume, a.masterVolume);
    });

    test('all-field update', () {
      const a = AudioSettings.defaults();
      final b = a.copyWith(
        musicEnabled: true,
        sfxEnabled: false,
        masterVolume: 0.3,
      );
      expect(b.musicEnabled, true);
      expect(b.sfxEnabled, false);
      expect(b.masterVolume, 0.3);
    });
  });

  group('AudioSettings equality', () {
    test('same values → equal + same hashCode', () {
      const a = AudioSettings(
        musicEnabled: true,
        sfxEnabled: false,
        masterVolume: 0.5,
      );
      const b = AudioSettings(
        musicEnabled: true,
        sfxEnabled: false,
        masterVolume: 0.5,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different values → not equal', () {
      const a = AudioSettings.defaults();
      final b = a.copyWith(musicEnabled: true);
      expect(a, isNot(b));
    });
  });
}
