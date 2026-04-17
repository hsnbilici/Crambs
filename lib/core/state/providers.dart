import 'package:crumbs/core/economy/cost_curve.dart';
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
  return gs == null ? 0 : Production.totalPerSecond(gs.buildings.owned);
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
