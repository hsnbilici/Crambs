import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/audio/audio_settings.dart';
import 'package:crumbs/core/audio/sfx_catalog.dart';

/// Bridge between AudioEngine and AudioSettings snapshot.
///
/// Plain class (not a Notifier). Lifecycle: constructed by
/// `audioControllerProvider`, kept alive for app lifetime. Settings
/// snapshot updated via `ref.listen(audioSettingsProvider)` wired inside
/// the provider (Pattern A, spec §1).
///
/// Ambient ducked vs SFX via `_ambientDuckFactor` (0.6) applied to
/// masterVolume. Cue-level volume balancing (tap subtle / purchase
/// celebratory) deferred to post-asset mixing pass (spec §5.2).
class AudioController {
  AudioController(this._engine, AudioSettings initial)
      : _settingsSnapshot = initial;

  static const double _ambientDuckFactor = 0.6;
  static const String _ambientAssetPath = 'audio/music/artisan_ambient.ogg';

  final AudioEngine _engine;
  AudioSettings _settingsSnapshot;

  double get _ambientVolume =>
      _settingsSnapshot.masterVolume * _ambientDuckFactor;

  /// Update settings snapshot and react to diff:
  /// - masterVolume change triggers live loop re-volume when music on
  /// - music toggle on/off starts/stops ambient
  /// - sfx toggle is snapshot-checked at playCue site (no diff needed)
  Future<void> updateSettings(AudioSettings next) async {
    final prev = _settingsSnapshot;
    _settingsSnapshot = next;
    if (next.musicEnabled && !prev.musicEnabled) {
      await startAmbient();
    }
    if (!next.musicEnabled && prev.musicEnabled) {
      await stopAmbient();
    }
    if (next.masterVolume != prev.masterVolume && next.musicEnabled) {
      await _engine.setLoopVolume(_ambientVolume);
    }
  }

  Future<void> playCue(SfxCue cue) async {
    if (!_settingsSnapshot.sfxEnabled) return;
    await _engine.playOneShot(
      SfxCatalog.assetPath(cue),
      volume: _settingsSnapshot.masterVolume,
    );
  }

  Future<void> startAmbient() async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.startLoop(
      _ambientAssetPath,
      volume: _ambientVolume,
    );
  }

  Future<void> stopAmbient() => _engine.stopLoop();

  Future<void> pauseAmbient() => _engine.pauseLoop();

  Future<void> resumeAmbient() async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.resumeLoop();
  }

  /// Live engine volume update during slider drag. No prefs write.
  /// Prefs persist handled separately by AudioSettingsSection debounce +
  /// final setMasterVolume call.
  Future<void> previewVolume(double v) async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.setLoopVolume(v * _ambientDuckFactor);
  }
}
