import 'dart:math';

/// Bina maliyet eğrisi.
/// Spec: docs/economy.md §5 — cost(n) = floor(baseCost × growthRate^owned)
class CostCurve {
  const CostCurve._();

  /// Bina için n. birim maliyeti.
  /// owned: halihazırda sahip olunan sayı (0-index — 0 ise ilk alım).
  static num costFor(num baseCost, double growthRate, int owned) =>
      (baseCost * pow(growthRate, owned)).floor();
}
