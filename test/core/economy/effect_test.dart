import 'package:crumbs/core/economy/effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Effect', () {
    test('equality by type + value', () {
      const a = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const b = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const c = Effect(type: EffectType.globalMultiplier, value: 2);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashCode matches equality', () {
      const a = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const b = Effect(type: EffectType.globalMultiplier, value: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('EffectType enum has globalMultiplier', () {
      expect(EffectType.values, contains(EffectType.globalMultiplier));
    });
  });
}
