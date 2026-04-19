import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:crumbs/core/economy/multiplier_chain.dart';
import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI'ın okuduğu derived state — notifier değişince rebuild.
final currentCrumbsProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).value;
  return gs?.inventory.r1Crumbs ?? 0;
});

final productionRateProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).value;
  if (gs == null) return 0;
  final multiplier = MultiplierChain.globalMultiplier(gs.upgrades.owned);
  return Production.totalPerSecond(
    gs.buildings.owned,
    globalMultiplier: multiplier,
  );
});

/// Family key: (buildingId, ownedCount). Shop BuildingRow bu provider'ı watch
/// eder; owned sayısı değiştiğinde yeniden hesaplanır.
// ignore: specify_nonobvious_property_types
final costCurveProvider = Provider.family<num, (String, int)>((ref, args) {
  final (id, owned) = args;
  return CostCurve.costFor(
    Production.baseCostFor(id),
    Production.growthFor(id),
    owned,
  );
});

/// Current global multiplier from upgrades — used by Session Recap modal
/// to display passive multiplier secondary line (spec B6 §2.1).
final multiplierChainTotalProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).value;
  if (gs == null) return 1.0;
  return MultiplierChain.globalMultiplier(gs.upgrades.owned);
});
