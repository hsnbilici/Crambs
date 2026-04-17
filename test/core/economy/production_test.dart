import 'package:crumbs/core/economy/production.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production.baseProductionFor', () {
    test('crumb_collector → 0.1 C/s', () {
      expect(Production.baseProductionFor('crumb_collector'), 0.1);
    });

    test('unknown id → 0 (no exception)', () {
      expect(Production.baseProductionFor('unknown'), 0);
    });
  });

  group('Production.baseCostFor', () {
    test('crumb_collector → 15', () {
      expect(Production.baseCostFor('crumb_collector'), 15);
    });

    test('unknown id → 0', () {
      expect(Production.baseCostFor('unknown'), 0);
    });
  });

  group('Production.growthFor', () {
    test('crumb_collector → 1.12', () {
      expect(Production.growthFor('crumb_collector'), 1.12);
    });

    test('unknown id → 1.0 (flat)', () {
      expect(Production.growthFor('unknown'), 1);
    });
  });

  group('Production.totalPerSecond', () {
    test('boş map → 0', () {
      expect(Production.totalPerSecond({}), 0);
    });

    test('1 collector → 0.1', () {
      expect(Production.totalPerSecond({'crumb_collector': 1}), 0.1);
    });

    test('5 collector → 0.5', () {
      expect(
        Production.totalPerSecond({'crumb_collector': 5}),
        closeTo(0.5, 1e-12),
      );
    });

    test('unknown building katkı vermez', () {
      expect(
        Production.totalPerSecond({'crumb_collector': 3, 'unknown': 10}),
        closeTo(0.3, 1e-12),
      );
    });
  });

  group('Production.tickDelta', () {
    test('1 collector × 1.0s = 0.1', () {
      expect(
        Production.tickDelta({'crumb_collector': 1}, 1),
        closeTo(0.1, 1e-12),
      );
    });

    test('0s delta = 0', () {
      expect(Production.tickDelta({'crumb_collector': 5}, 0), 0);
    });

    test('lineer akkümülasyon: 5×(0.2s) ≈ 1×(1.0s) — relative tolerance', () {
      final b = {'crumb_collector': 100};
      final chunked = List.generate(5, (_) => Production.tickDelta(b, 0.2))
          .reduce((a, c) => a + c);
      final whole = Production.tickDelta(b, 1);
      final diff = (chunked - whole).abs();
      final maxAbs =
          chunked.abs() > whole.abs() ? chunked.abs() : whole.abs();
      final tolerance = 1e-12 * maxAbs;
      expect(
        diff,
        lessThan(tolerance.isFinite && tolerance > 0 ? tolerance : 1e-9),
      );
    });
  });

  group('Production — economy.md §4 table values', () {
    test('crumb_collector matches economy §4', () {
      expect(Production.baseProductionFor('crumb_collector'), 0.1);
      expect(Production.baseCostFor('crumb_collector'), 15);
      expect(Production.growthFor('crumb_collector'), 1.12);
    });

    test('oven matches economy §4', () {
      expect(Production.baseProductionFor('oven'), 1.0);
      expect(Production.baseCostFor('oven'), 120);
      expect(Production.growthFor('oven'), 1.12);
    });

    test('bakery_line matches economy §4', () {
      expect(Production.baseProductionFor('bakery_line'), 8.0);
      expect(Production.baseCostFor('bakery_line'), 1200);
      expect(Production.growthFor('bakery_line'), 1.13);
    });

    test('unknown building defensive fallback', () {
      expect(Production.baseProductionFor('unknown'), 0);
      expect(Production.baseCostFor('unknown'), 0);
      expect(Production.growthFor('unknown'), 1);
    });
  });

  group('Production — globalMultiplier injection', () {
    test('totalPerSecond default multiplier = 1.0 (backward-compat)', () {
      expect(Production.totalPerSecond({'crumb_collector': 1}), 0.1);
    });

    test('totalPerSecond with globalMultiplier: 1.5 → scaled', () {
      expect(
        Production.totalPerSecond(
          {'crumb_collector': 1},
          globalMultiplier: 1.5,
        ),
        closeTo(0.15, 1e-12),
      );
    });

    test('tickDelta with globalMultiplier → delta scales', () {
      expect(
        Production.tickDelta(
          {'oven': 2}, 10,
          globalMultiplier: 1.5,
        ),
        closeTo(30, 1e-9),  // 2 × 1.0 × 1.5 × 10 = 30
      );
    });

    test('tickDelta zero buildings → 0 regardless of multiplier', () {
      expect(
        Production.tickDelta({}, 10, globalMultiplier: 2),
        0,
      );
    });
  });
}
