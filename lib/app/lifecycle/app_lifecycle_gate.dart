import 'dart:async';

import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle observer + autosave + hot resume offline delta gate.
///
/// onPause / onDetach: await persistNow — state'i diske yazar.
/// onResume: applyResumeDelta sync → resetTickClock warmup.
/// 30s periodic autosave — worst-case kayıp penceresi.
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
      onPause: _saveNow,
      onDetach: _saveNow,
      onResume: _onResume,
    );
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveNow(),
    );
  }

  Future<void> _saveNow() async {
    final notifier = ref.read(gameStateNotifierProvider.notifier);
    await notifier.persistNow();
  }

  void _onResume() {
    ref.read(gameStateNotifierProvider.notifier)
      ..applyResumeDelta()
      ..resetTickClock();
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
