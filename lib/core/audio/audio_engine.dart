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
