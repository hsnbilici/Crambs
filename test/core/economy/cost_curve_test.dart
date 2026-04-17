import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CostCurve.costFor', () {
    // economy.md §5: cost(n) = floor(baseCost × growthRate^owned)
    // Crumb Collector: base=10, growth=1.15
    test('owned=0 → base cost', () {
      expect(CostCurve.costFor(10, 1.15, 0), 10);
    });

    test('owned=1 → 10 × 1.15 = 11.5 → floor 11', () {
      expect(CostCurve.costFor(10, 1.15, 1), 11);
    });

    test('owned=5 → 10 × 1.15^5 ≈ 20.11 → 20', () {
      expect(CostCurve.costFor(10, 1.15, 5), 20);
    });

    test('owned=25 → 10 × 1.15^25 ≈ 329.19 → 329', () {
      expect(CostCurve.costFor(10, 1.15, 25), 329);
    });

    test('edge: owned=0 base=0 → 0', () {
      expect(CostCurve.costFor(0, 1.15, 0), 0);
    });

    test('edge: growth=1.0 flat → always base', () {
      expect(CostCurve.costFor(100, 1, 10), 100);
    });
  });
}
