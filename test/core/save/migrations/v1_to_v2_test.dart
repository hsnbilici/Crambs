import 'package:crumbs/core/save/migrations/v1_to_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateV1ToV2GameState', () {
    test('adds empty upgrades when missing', () {
      final v1 = <String, dynamic>{
        'meta': {'installId': 'abc'},
        'inventory': {'r1Crumbs': 100},
        'buildings': {'owned': <String, dynamic>{}},
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['upgrades'], {'owned': <String, bool>{}});
      expect(v1.containsKey('upgrades'), isFalse); // original untouched
    });

    test('idempotent — existing upgrades preserved', () {
      final v1 = <String, dynamic>{
        'meta': {'installId': 'abc'},
        'upgrades': {
          'owned': {'golden_recipe_i': true},
        },
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['upgrades'], {
        'owned': {'golden_recipe_i': true},
      });
    });

    test('preserves other fields', () {
      final v1 = <String, dynamic>{
        'meta': {'installId': 'xyz'},
        'buildings': {
          'owned': {'crumb_collector': 5},
        },
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['meta'], {'installId': 'xyz'});
      expect(v2['buildings'], {
        'owned': {'crumb_collector': 5},
      });
    });
  });
}
