import 'dart:async';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle observer + autosave + hot resume offline delta gate + telemetry
/// session hooks + audio pause/resume gate.
///
/// onPause / onDetach: pauseAmbient → persist → session (invariant `[I23]`).
/// Audio fail never blocks persist (`[I6]` korunur — try/catch swallows).
/// onResume: session.onResume → applyResumeDelta → resetTickClock →
/// resumeAmbient.
/// 30s periodic autosave — yalnız persist (telemetry tetikleme yok).
class AppLifecycleGate extends ConsumerStatefulWidget {
  const AppLifecycleGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends ConsumerState<AppLifecycleGate> {
  late final AppLifecycleListener _listener;
  late final Timer _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: _onPause,
      onDetach: _onDetach,
      onResume: _onResume,
    );
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _persistOnly(),
    );
  }

  Future<void> _persistOnly() async {
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
  }

  /// Sıra kritik (invariant `[I23]`): pauseAmbient → persist → session.
  /// Audio fail `persistNow()`'u asla bloklamaz (`[I6]` korunur).
  Future<void> _onPause() async {
    try {
      await ref.read(audioControllerProvider).pauseAmbient();
    } on Object catch (e, st) {
      debugPrint('audio pauseAmbient failed in _onPause: $e\n$st');
    }
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
    ref.read(sessionControllerProvider).onPause();
  }

  Future<void> _onDetach() async {
    try {
      await ref.read(audioControllerProvider).pauseAmbient();
    } on Object catch (e, st) {
      debugPrint('audio pauseAmbient failed in _onDetach: $e\n$st');
    }
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
    ref.read(sessionControllerProvider).onPause();
  }

  void _onResume() {
    ref.read(sessionControllerProvider).onResume();
    ref.read(gameStateNotifierProvider.notifier)
      ..applyResumeDelta()
      ..resetTickClock();
    try {
      unawaited(ref.read(audioControllerProvider).resumeAmbient());
    } on Object catch (e, st) {
      debugPrint('audio resumeAmbient failed in _onResume: $e\n$st');
    }
  }

  @override
  void dispose() {
    _autoSaveTimer.cancel();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
