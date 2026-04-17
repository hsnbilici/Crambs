import 'package:crumbs/core/economy/effect.dart';
import 'package:crumbs/core/economy/upgrade_defs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpgradeDefs', () {
    test('effectFor(golden_recipe_i) → globalMultiplier ×1.5', () {
      expect(
        UpgradeDefs.effectFor('golden_recipe_i'),
        const Effect(type: EffectType.globalMultiplier, value: 1.5),
      );
    });

    test('effectFor(unknown) → no-op sentinel (globalMultiplier ×1.0)', () {
      expect(
        UpgradeDefs.effectFor('unknown'),
        const Effect(type: EffectType.globalMultiplier, value: 1),
      );
    });

    test('baseCostFor(golden_recipe_i) → 200', () {
      expect(UpgradeDefs.baseCostFor('golden_recipe_i'), 200);
    });

    test('baseCostFor(unknown) → 0', () {
      expect(UpgradeDefs.baseCostFor('unknown'), 0);
    });

    test('exists(golden_recipe_i) → true', () {
      expect(UpgradeDefs.exists('golden_recipe_i'), isTrue);
    });

    test('exists(unknown) → false', () {
      expect(UpgradeDefs.exists('random_id'), isFalse);
    });
  });
}
