/// Üretim formülleri — bina başına saniyede üretim.
/// Spec: docs/economy.md §2, §3
///
/// BuildingDefs lookup'ları burada: base production, base cost, growth.
/// A kapsamı: tek bina (crumb_collector). B+'ta genişler.
/// Unknown id defensively 0 / 1.0 döner — forward-compat.
class Production {
  const Production._();

  /// Base production (C/s). economy.md §2.
  static double baseProductionFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 0.1,
        _ => 0,
      };

  /// Base cost. economy.md §2. CostCurve.costFor bu değeri büyütür.
  static num baseCostFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 10,
        _ => 0,
      };

  /// Growth rate — cost(n) = base × growth^owned. economy.md §5.
  static double growthFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 1.15,
        _ => 1,
      };

  /// Toplam üretim hızı (C/s). UI + tick + offline tek noktadan besler.
  static double totalPerSecond(Map<String, int> buildings) {
    double total = 0;
    buildings.forEach((id, owned) {
      total += owned * baseProductionFor(id);
    });
    return total;
  }

  /// Tick veya offline delta. seconds = wall-clock elapsed.
  /// Tek kod yolu — online tick + cold start hydration + hot resume ortak
  /// formül.
  static double tickDelta(Map<String, int> buildings, double seconds) =>
      totalPerSecond(buildings) * seconds;
}
