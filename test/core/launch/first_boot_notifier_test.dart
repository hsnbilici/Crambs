import 'package:crumbs/core/launch/first_boot_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('FirstBootNotifier', () {
    test('fresh B4 install (no prefs) → ensureObserved true + pref write',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, true, reason: 'fresh install → AppInstall should emit');
      expect(c.read(firstBootProvider), true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true);
    });

    test(
        'pre-B4 migration (install_id mevcut, observed yok) → '
        'state=false + backfill', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
      });
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, false, reason: 'pre-B4 user — AppInstall suppressed');
      expect(c.read(firstBootProvider), false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true,
          reason: 'backfill: pref yazıldı ki ikinci boot idempotent olsun');
    });

    test('second boot (observed=true pref) → state=false idempotent',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_observed': true,
        'crumbs.install_id': 'some-id',
      });
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, false);
      expect(c.read(firstBootProvider), false);
    });

    test('B4 fresh install second boot — observed stays true', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c1 = buildContainer();
      final r1 = await c1.read(firstBootProvider.notifier).ensureObserved();
      expect(r1, true);

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final r2 = await c2.read(firstBootProvider.notifier).ensureObserved();
      expect(r2, false, reason: 'observed pref idempotent korunur');
    });
  });
}
