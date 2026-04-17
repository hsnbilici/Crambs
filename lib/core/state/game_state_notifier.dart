import 'dart:async';

import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:crumbs/core/economy/offline_progress.dart';
import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const int _kCurrentSchemaVersion = 1;

/// UI sinyal kanalları.
///
/// INVARIANT: OfflineReport YALNIZCA cold start (build hydration) path'inden
/// push edilir. applyResumeDelta (hot resume) bu provider'ı DEĞIŞTIRMEZ.
/// INVARIANT: saveRecoveryProvider da aynı kural — yalnız cold start.
///
/// UI katmanı `ref.listen` ile yakalar, snackbar gösterir, null'lar.
class OfflineReportSignal extends Notifier<OfflineReport?> {
  @override
  OfflineReport? build() => null;

  void clear() => state = null;
}

class SaveRecoverySignal extends Notifier<SaveRecoveryReason?> {
  @override
  SaveRecoveryReason? build() => null;

  void clear() => state = null;
}

final offlineReportProvider =
    NotifierProvider<OfflineReportSignal, OfflineReport?>(
  OfflineReportSignal.new,
);
final saveRecoveryProvider =
    NotifierProvider<SaveRecoverySignal, SaveRecoveryReason?>(
  SaveRecoverySignal.new,
);

/// SaveRepository override edilebilir — test'lerde tempDir inject edilir.
final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => SaveRepository(),
);

class GameStateNotifier extends AsyncNotifier<GameState> {
  Timer? _tick;
  DateTime? _lastTickAt;
  DateTime? _lastHaptic;

  @override
  Future<GameState> build() async {
    ref.onDispose(() {
      _tick?.cancel();
      _tick = null;
    });

    final repo = ref.read(saveRepositoryProvider);
    final loadResult = await repo.load();

    GameState hydrated;
    OfflineReport? offlineReport;

    if (loadResult.envelope != null) {
      final migrated = SaveMigrator.migrate(
        loadResult.envelope!,
        targetVersion: _kCurrentSchemaVersion,
      );
      hydrated = migrated.gameState;
      final now = DateTime.now();
      offlineReport = OfflineProgress.compute(hydrated, now);
      hydrated = hydrated.copyWith(
        inventory: hydrated.inventory.copyWith(
          r1Crumbs: hydrated.inventory.r1Crumbs + offlineReport.earned,
        ),
        meta: hydrated.meta.copyWith(lastSavedAt: now.toIso8601String()),
      );
    } else {
      hydrated = GameState.initial(installId: const Uuid().v4());
    }

    // Cold start-only UI sinyaller
    if (loadResult.recovery != null) {
      ref.read(saveRecoveryProvider.notifier).state = loadResult.recovery;
    }
    if (offlineReport != null && offlineReport.earned > 0) {
      ref.read(offlineReportProvider.notifier).state = offlineReport;
    }

    // TICK RACE FIX: _lastTickAt önce set, sonra Timer spawn
    _lastTickAt = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 200), _onTick);

    return hydrated;
  }

  void _onTick(Timer _) {
    final now = DateTime.now();
    final seconds = _lastTickAt == null
        ? 0.0
        : now.difference(_lastTickAt!).inMicroseconds / 1e6;
    _lastTickAt = now;
    if (seconds > 0) applyProductionDelta(seconds);
  }

  void tapCrumb() {
    final gs = state.value;
    if (gs == null) return;
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs + 1),
    ));
    _triggerHaptic();
    // Onboarding hint pass-through dismiss — fire-and-forget.
    // Swallow late-dispose errors (container may dispose during the async gap
    // of SharedPreferences.getInstance in dismissHint).
    final prefs = ref.read(onboardingPrefsProvider);
    if (!prefs.hintDismissed) {
      unawaited(
        ref
            .read(onboardingPrefsProvider.notifier)
            .dismissHint()
            .catchError((Object _) {}),
      );
    }
  }

  Future<bool> buyBuilding(String id) async {
    final gs = state.value;
    if (gs == null) return false;
    final owned = gs.buildings.owned[id] ?? 0;
    final cost = CostCurve.costFor(
      Production.baseCostFor(id),
      Production.growthFor(id),
      owned,
    );
    if (gs.inventory.r1Crumbs < cost) return false;
    final updated = gs.copyWith(
      inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs - cost),
      buildings: gs.buildings.copyWith(
        owned: {...gs.buildings.owned, id: owned + 1},
      ),
    );
    state = AsyncData(updated);
    await _persist(updated);
    return true;
  }

  void applyProductionDelta(double seconds) {
    final gs = state.value;
    if (gs == null) return;
    final delta = Production.tickDelta(gs.buildings.owned, seconds);
    if (delta == 0) return;
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + delta,
      ),
    ));
  }

  /// Hot resume path — sync, sessiz.
  /// INVARIANT: NEITHER offlineReportProvider NOR saveRecoveryProvider changed.
  void applyResumeDelta({DateTime? now}) {
    final gs = state.value;
    if (gs == null) return;
    final n = now ?? DateTime.now();
    final last = DateTime.parse(gs.meta.lastSavedAt);
    final seconds = n.difference(last).inMicroseconds / 1e6;
    if (seconds <= 0) return;
    final delta = Production.tickDelta(gs.buildings.owned, seconds);
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + delta,
      ),
      meta: gs.meta.copyWith(lastSavedAt: n.toIso8601String()),
    ));
  }

  void resetTickClock() {
    _lastTickAt = null;
  }

  Future<void> _persist(GameState gs) async {
    final repo = ref.read(saveRepositoryProvider);
    final envelope = SaveEnvelope(
      version: _kCurrentSchemaVersion,
      lastSavedAt: DateTime.now().toIso8601String(),
      gameState: gs,
      checksum: Checksum.of(gs.toJson()),
    );
    await repo.save(envelope);
  }

  Future<void> persistNow() async {
    final gs = state.value;
    if (gs == null) return;
    await _persist(gs);
  }

  void _triggerHaptic() {
    final now = DateTime.now();
    if (_lastHaptic != null &&
        now.difference(_lastHaptic!).inMilliseconds < 80) {
      return;
    }
    _lastHaptic = now;
    unawaited(HapticFeedback.lightImpact());
  }
}

final gameStateNotifierProvider =
    AsyncNotifierProvider<GameStateNotifier, GameState>(
  GameStateNotifier.new,
);
