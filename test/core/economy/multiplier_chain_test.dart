import 'package:crumbs/core/economy/multiplier_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiplierChain.globalMultiplier', () {
    test('empty owned map → 1.0', () {
      expect(MultiplierChain.globalMultiplier({}), 1.0);
    });

    test('single owned golden_recipe_i → 1.5', () {
      expect(
        MultiplierChain.globalMultiplier({'golden_recipe_i': true}),
        closeTo(1.5, 1e-12),
      );
    });

    test('owned=false entry → ignored (defensive)', () {
      expect(
        MultiplierChain.globalMultiplier({'golden_recipe_i': false}),
        1.0,
      );
    });

    test('unknown id → defensive skip, 1.0', () {
      expect(
        MultiplierChain.globalMultiplier({'ghost_upgrade': true}),
        1.0,
      );
    });

    test('mixed known + unknown + false → only valid true multiplied', () {
      expect(
        MultiplierChain.globalMultiplier({
          'golden_recipe_i': true,
          'ghost': true,
          'falsey': false,
        }),
        closeTo(1.5, 1e-12),
      );
    });

    test('hypothetical multi-upgrade multiplicative (B2+ forward-compat)', () {
      expect(
        MultiplierChain.globalMultiplier({
          'golden_recipe_i': true,
          'not_yet_defined_but_future': true,
        }),
        closeTo(1.5, 1e-12),
      );
    });

    test('determinism — same input same output', () {
      final input = {'golden_recipe_i': true};
      final a = MultiplierChain.globalMultiplier(input);
      final b = MultiplierChain.globalMultiplier(input);
      expect(a, b);
    });
  });
}
