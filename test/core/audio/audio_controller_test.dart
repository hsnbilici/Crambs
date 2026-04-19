import 'package:crumbs/core/audio/audio_controller.dart';
import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/audio/audio_settings.dart';
import 'package:crumbs/core/audio/sfx_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioController.playCue', () {
    test('sfxEnabled=true → engine.playOneShot called with asset+volume',
        () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());

      await ctrl.playCue(SfxCue.tap);

      expect(fake.oneShots, [('audio/sfx/tap.ogg', 0.7)]);
    });

    test('sfxEnabled=false → engine NOT called', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(
        fake,
        const AudioSettings.defaults().copyWith(sfxEnabled: false),
      );

      await ctrl.playCue(SfxCue.tap);

      expect(fake.oneShots, isEmpty);
    });

    test('engine failed → playCue no-op, no throw', () async {
      final fake = FakeAudioEngine(simulateInitFailure: true);
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());

      await ctrl.playCue(SfxCue.tap); // must not throw

      expect(fake.oneShots, isEmpty);
    });
  });

  group('AudioController.updateSettings diff', () {
    test('musicOff → musicOn triggers startLoop', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());

      await ctrl.updateSettings(
        const AudioSettings.defaults().copyWith(musicEnabled: true),
      );

      expect(fake.loopRunning, true);
      expect(fake.currentLoopPath, 'audio/music/artisan_ambient.ogg');
      expect(fake.currentVolume, closeTo(0.42, 1e-9)); // 0.7 * 0.6
    });

    test('musicOn → musicOff triggers stopLoop', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(
        fake,
        const AudioSettings.defaults().copyWith(musicEnabled: true),
      );
      await ctrl.startAmbient();
      expect(fake.loopRunning, true);

      await ctrl.updateSettings(const AudioSettings.defaults());

      expect(fake.loopRunning, false);
    });

    test('masterVolume change while music on → setLoopVolume called', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final initial =
          const AudioSettings.defaults().copyWith(musicEnabled: true);
      final ctrl = AudioController(fake, initial);
      await ctrl.startAmbient();
      expect(fake.currentVolume, closeTo(0.42, 1e-9));

      await ctrl.updateSettings(initial.copyWith(masterVolume: 0.5));

      expect(fake.currentVolume, closeTo(0.3, 1e-9)); // 0.5 * 0.6
    });

    test('sfxEnabled toggle → no loop side effect', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());
      final loopsBefore = fake.loopsStarted.length;

      await ctrl.updateSettings(
        const AudioSettings.defaults().copyWith(sfxEnabled: false),
      );

      expect(fake.loopsStarted.length, loopsBefore);
      expect(fake.loopRunning, false);
    });
  });

  group('AudioController lifecycle helpers', () {
    test('pauseAmbient / resumeAmbient respect musicEnabled', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(
        fake,
        const AudioSettings.defaults().copyWith(musicEnabled: true),
      );
      await ctrl.startAmbient();

      await ctrl.pauseAmbient();
      expect(fake.loopPaused, true);

      await ctrl.resumeAmbient();
      expect(fake.loopPaused, false);
    });

    test('resumeAmbient no-op when musicEnabled=false', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());

      await ctrl.resumeAmbient();

      expect(fake.loopRunning, false);
    });

    test('previewVolume updates engine live without prefs write', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(
        fake,
        const AudioSettings.defaults().copyWith(musicEnabled: true),
      );
      await ctrl.startAmbient();

      await ctrl.previewVolume(0.2);

      expect(fake.currentVolume, closeTo(0.12, 1e-9)); // 0.2 * 0.6
    });

    test('previewVolume no-op when musicEnabled=false', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      final ctrl = AudioController(fake, const AudioSettings.defaults());
      final volBefore = fake.currentVolume;

      await ctrl.previewVolume(0.5);

      expect(fake.currentVolume, volBefore);
    });
  });
}
