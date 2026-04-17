import 'package:crumbs/core/save/upgrade_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpgradeState', () {
    test('default construct — empty owned map', () {
      const state = UpgradeState();
      expect(state.owned, <String, bool>{});
    });

    test('copyWith preserves + updates', () {
      const a = UpgradeState(owned: {'a': true});
      final b = a.copyWith(owned: {'a': true, 'b': true});
      expect(b.owned, {'a': true, 'b': true});
      expect(a.owned, {'a': true});  // original immutable
    });

    test('fromJson(toJson(x)) roundtrip', () {
      const original = UpgradeState(owned: {'golden_recipe_i': true});
      final json = original.toJson();
      final restored = UpgradeState.fromJson(json);
      expect(restored, original);
    });

    test('fromJson with missing owned → default empty', () {
      final restored = UpgradeState.fromJson(const <String, dynamic>{});
      expect(restored.owned, <String, bool>{});
    });

    test('fromJson tolerates owned=false entries (defensive)', () {
      final restored = UpgradeState.fromJson(const {
        'owned': {'a': true, 'b': false},
      });
      expect(restored.owned, {'a': true, 'b': false});
    });
  });
}
