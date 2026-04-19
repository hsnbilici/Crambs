import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:crumbs/core/audio/sfx_catalog.dart';
import 'package:flutter/foundation.dart';

/// Audio primitive layer — wraps `audioplayers` (concrete impl added in
/// AudioplayersEngine). Tests use FakeAudioEngine.
///
/// Invariant I21 — fail-silent: after init failure (`_failed=true`) or
/// dispose (`_disposed=true`), all play methods become no-ops.
/// Gameplay path preserved (B3 FirebaseBootstrap.isInitialized parallel).
abstract interface class AudioEngine {
  /// Platform config + AudioPool warm-up (parallel).
  /// Idempotent — completes immediately if already initialized.
  /// Completes normally even on internal failure; sets `_failed=true` so
  /// awaiters proceed to silent no-ops.
  Future<void> init();

  /// Plays a one-shot SFX asset at [volume] (0.0–1.0). No-op after dispose
  /// or init failure.
  Future<void> playOneShot(String assetPath, {required double volume});

  /// Starts looping music from [assetPath] at [volume]. Replaces any
  /// currently-playing loop. No-op after dispose or init failure.
  Future<void> startLoop(String assetPath, {required double volume});

  /// Stops the currently-playing loop (if any). Always safe to call.
  Future<void> stopLoop();

  /// Pauses the currently-playing loop (keeps position). No-op if no loop
  /// is running.
  Future<void> pauseLoop();

  /// Resumes a paused loop. No-op after dispose or init failure.
  Future<void> resumeLoop();

  /// Updates the running loop's volume to [v] (0.0–1.0). No-op after
  /// dispose or init failure.
  Future<void> setLoopVolume(double v);

  /// Releases all player instances. Idempotent. Post-dispose plays no-op.
  Future<void> dispose();
}

/// Test helper — records calls, supports failure simulation.
///
/// Not constructed from production code. Used in unit/widget/integration
/// tests via `audioEngineProvider.overrideWithValue(FakeAudioEngine())`.
class FakeAudioEngine implements AudioEngine {
  FakeAudioEngine({this.simulateInitFailure = false});

  final bool simulateInitFailure;

  final List<(String, double)> oneShots = [];
  final List<(String, double)> loopsStarted = [];
  bool loopRunning = false;
  bool loopPaused = false;
  String? currentLoopPath;
  double currentVolume = 0;
  bool disposed = false;
  bool failed = false;

  bool get _blocked => failed || disposed;

  @override
  Future<void> init() async {
    if (simulateInitFailure) {
      failed = true;
    }
  }

  @override
  Future<void> playOneShot(String assetPath, {required double volume}) async {
    if (_blocked) return;
    oneShots.add((assetPath, volume));
  }

  @override
  Future<void> startLoop(String assetPath, {required double volume}) async {
    if (_blocked) return;
    loopsStarted.add((assetPath, volume));
    loopRunning = true;
    loopPaused = false;
    currentLoopPath = assetPath;
    currentVolume = volume;
  }

  @override
  Future<void> stopLoop() async {
    loopRunning = false;
    loopPaused = false;
    currentLoopPath = null;
  }

  @override
  Future<void> pauseLoop() async {
    if (loopRunning) loopPaused = true;
  }

  @override
  Future<void> resumeLoop() async {
    if (_blocked) return;
    if (loopRunning) loopPaused = false;
  }

  @override
  Future<void> setLoopVolume(double v) async {
    if (_blocked) return;
    currentVolume = v;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    loopRunning = false;
  }
}

/// Concrete platform-bound engine — coverage excluded per spec §4.4.
///
/// Wraps `audioplayers`:
/// - per-cue [AudioPool] (4 players max) for rapid overlap SFX
/// - single ambient [AudioPlayer] loop
/// - iOS Ambient category (silenced by Ring/Silent switch, mix with others)
/// - Android media/music content type (respects silent mode per platform)
///
/// Race-guard contract:
/// - [init] is idempotent; repeated calls reuse the same [_initCompleter].
/// - On bootstrap failure, completer still completes (NOT completeError) so
///   awaiters unblock and proceed to silent no-ops via [_failed].
/// - Every public method (except [dispose]) awaits [_initCompleter] before
///   touching platform state — pre-init plays queue safely.
class AudioplayersEngine implements AudioEngine {
  Completer<void>? _initCompleter;
  bool _failed = false;
  bool _disposed = false;

  final Map<SfxCue, AudioPool> _pools = {};
  final AudioPlayer _ambient = AudioPlayer();

  bool get _blocked => _failed || _disposed;

  @override
  Future<void> init() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    unawaited(
      _bootstrap().then(
        (_) {
          completer.complete();
        },
        onError: (Object e, StackTrace st) {
          _failed = true;
          debugPrint('AudioplayersEngine init failed: $e\n$st');
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> _bootstrap() async {
    // iOS Ambient — silenced by Ring/Silent switch + mix with other audio.
    // Android default: media content + music usage (platform convention;
    // silent mode behaviour handled by OS).
    // NOTE: `AudioContext`/`AudioContextIOS` constructors are non-const
    // (AudioContextIOS has runtime asserts), so we cannot use `const` here.
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
        android: const AudioContextAndroid(
          // contentType/usageType defaults match (music/media).
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    // Parallel AudioPool warm — one per cue.
    await Future.wait([
      for (final cue in SfxCue.values)
        AudioPool.create(
          source: AssetSource(SfxCatalog.assetPath(cue)),
          maxPlayers: 4,
        ).then((pool) => _pools[cue] = pool),
    ]);
    await _ambient.setReleaseMode(ReleaseMode.loop);
  }

  SfxCue? _cueForPath(String assetPath) {
    for (final cue in SfxCue.values) {
      if (SfxCatalog.assetPath(cue) == assetPath) return cue;
    }
    return null;
  }

  @override
  Future<void> playOneShot(String assetPath, {required double volume}) async {
    await _initCompleter?.future;
    if (_blocked) return;
    final cue = _cueForPath(assetPath);
    final pool = cue != null ? _pools[cue] : null;
    if (pool == null) return;
    try {
      await pool.start(volume: volume);
    } on Object catch (e, st) {
      debugPrint('playOneShot failed ($assetPath): $e\n$st');
    }
  }

  @override
  Future<void> startLoop(String assetPath, {required double volume}) async {
    await _initCompleter?.future;
    if (_blocked) return;
    try {
      await _ambient.stop();
      await _ambient.setVolume(volume);
      await _ambient.play(AssetSource(assetPath));
    } on Object catch (e, st) {
      debugPrint('startLoop failed ($assetPath): $e\n$st');
    }
  }

  @override
  Future<void> stopLoop() async {
    await _initCompleter?.future;
    if (_blocked) return;
    try {
      await _ambient.stop();
    } on Object catch (e, st) {
      debugPrint('stopLoop failed: $e\n$st');
    }
  }

  @override
  Future<void> pauseLoop() async {
    await _initCompleter?.future;
    if (_blocked) return;
    try {
      await _ambient.pause();
    } on Object catch (e, st) {
      debugPrint('pauseLoop failed: $e\n$st');
    }
  }

  @override
  Future<void> resumeLoop() async {
    await _initCompleter?.future;
    if (_blocked) return;
    try {
      await _ambient.resume();
    } on Object catch (e, st) {
      debugPrint('resumeLoop failed: $e\n$st');
    }
  }

  @override
  Future<void> setLoopVolume(double v) async {
    await _initCompleter?.future;
    if (_blocked) return;
    try {
      await _ambient.setVolume(v);
    } on Object catch (e, st) {
      debugPrint('setLoopVolume failed: $e\n$st');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _ambient.dispose();
      for (final pool in _pools.values) {
        await pool.dispose();
      }
      _pools.clear();
    } on Object catch (e, st) {
      debugPrint('AudioplayersEngine dispose failed: $e\n$st');
    }
  }
}
