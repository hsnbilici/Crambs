import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAudioEngine — call recording', () {
    test('playOneShot records asset path + volume', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      await fake.playOneShot('audio/sfx/tap.ogg', volume: 0.7);
      await fake.playOneShot('audio/sfx/purchase.ogg', volume: 1);
      expect(fake.oneShots, [
        ('audio/sfx/tap.ogg', 0.7),
        ('audio/sfx/purchase.ogg', 1.0),
      ]);
    });

    test('startLoop / pauseLoop / resumeLoop / stopLoop state machine',
        () async {
      final fake = FakeAudioEngine();
      await fake.init();
      expect(fake.loopRunning, false);

      await fake.startLoop('audio/music/artisan_ambient.ogg', volume: 0.42);
      expect(fake.loopRunning, true);
      expect(fake.loopPaused, false);
      expect(fake.currentLoopPath, 'audio/music/artisan_ambient.ogg');
      expect(fake.currentVolume, 0.42);

      await fake.pauseLoop();
      expect(fake.loopRunning, true);
      expect(fake.loopPaused, true);

      await fake.resumeLoop();
      expect(fake.loopPaused, false);

      await fake.stopLoop();
      expect(fake.loopRunning, false);
    });

    test('setLoopVolume updates currentVolume', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      await fake.startLoop('audio/music/artisan_ambient.ogg', volume: 0.5);
      await fake.setLoopVolume(0.2);
      expect(fake.currentVolume, 0.2);
    });

    test('dispose flips disposed flag', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      await fake.dispose();
      expect(fake.disposed, true);
    });
  });

  group('FakeAudioEngine — failure simulation', () {
    test('simulateInitFailure → failed=true, all plays no-op', () async {
      final fake = FakeAudioEngine(simulateInitFailure: true);
      await fake.init();
      expect(fake.failed, true);

      await fake.playOneShot('audio/sfx/tap.ogg', volume: 1);
      await fake.startLoop('audio/music/artisan_ambient.ogg', volume: 1);
      expect(fake.oneShots, isEmpty);
      expect(fake.loopRunning, false);
    });

    test('disposed engine plays no-op', () async {
      final fake = FakeAudioEngine();
      await fake.init();
      await fake.dispose();
      await fake.playOneShot('audio/sfx/tap.ogg', volume: 1);
      expect(fake.oneShots, isEmpty);
    });
  });
}
