import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('InstallIdNotifier', () {
    test('ensureLoaded with empty disk → state is null', () async {
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(c.read(installIdProvider), isNull);
    });

    test('ensureLoaded with existing key → state is that value', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'existing-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(c.read(installIdProvider), 'existing-id');
    });

    test('adoptFromGameState with empty disk → writes GameState id',
        () async {
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState('gs-install-id');
      expect(c.read(installIdProvider), 'gs-install-id');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crumbs.install_id'), 'gs-install-id');
    });

    test('adoptFromGameState when disk differs → disk overwritten (disk wins)',
        () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'stale-disk-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState('gs-authoritative-id');
      expect(c.read(installIdProvider), 'gs-authoritative-id');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crumbs.install_id'), 'gs-authoritative-id');
    });

    test('adoptFromGameState when disk matches → no-op write', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'same-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(installIdProvider.notifier).adoptFromGameState('same-id');
      expect(c.read(installIdProvider), 'same-id');
    });

    test('resolveInstallIdForTelemetry returns value when loaded', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'loaded-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(
        resolveInstallIdForTelemetry(c.read(installIdProvider)),
        'loaded-id',
      );
    });

    test('resolveInstallIdForTelemetry returns sentinel when null', () {
      final c = buildContainer();
      expect(resolveInstallIdForTelemetry(c.read(installIdProvider)),
          InstallIdNotifier.kNotLoadedSentinel);
      expect(InstallIdNotifier.kNotLoadedSentinel, '<not-loaded>');
    });
  });

  group('InstallIdNotifier — installIdAgeMs (B3)', () {
    test('pre-ensureLoaded → kAgeNotLoaded (-1)', () {
      final c = buildContainer();
      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, InstallIdNotifier.kAgeNotLoaded);
      expect(InstallIdNotifier.kAgeNotLoaded, -1);
    });

    test('fresh disk → _createdAt=now + pref yazıldı + age in [0, 5s]',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final notifier = c.read(installIdProvider.notifier);
      final age = notifier.installIdAgeMs;
      expect(age, greaterThanOrEqualTo(0));
      expect(age, lessThan(5000),
          reason: 'fresh _createdAt just wrote; age well under 5s');

      final prefs = await SharedPreferences.getInstance();
      final createdAtStr = prefs.getString('crumbs.install_created_at');
      expect(createdAtStr, isNotNull);
      expect(DateTime.tryParse(createdAtStr!), isNotNull);
    });

    test('existing valid pref → _createdAt parse → age > 0', () async {
      final oneMinuteAgo =
          DateTime.now().subtract(const Duration(minutes: 1));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': oneMinuteAgo.toIso8601String(),
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, greaterThanOrEqualTo(60000));
      expect(age, lessThan(120000));
    });

    test('corrupted pref → debugPrint + reset to now', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': 'not-a-valid-iso-8601',
      });

      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (msg, {wrapWidth}) {
        if (msg != null) logs.add(msg);
      };

      try {
        final c = buildContainer();
        await c.read(installIdProvider.notifier).ensureLoaded();

        expect(
          logs.any((l) =>
              l.contains('install_created_at parse failed') &&
              l.contains('not-a-valid-iso-8601')),
          isTrue,
          reason: 'corruption debugPrint forensic log bekleniyor',
        );

        final prefs = await SharedPreferences.getInstance();
        final reset = prefs.getString('crumbs.install_created_at');
        expect(reset, isNotNull);
        expect(DateTime.tryParse(reset!), isNotNull);

        final age = c.read(installIdProvider.notifier).installIdAgeMs;
        expect(age, greaterThanOrEqualTo(0));
        expect(age, lessThan(5000));
      } finally {
        debugPrint = originalDebugPrint;
      }
    });

    test('clock-backward (_createdAt in future) → 0 clamp', () async {
      final oneHourFuture =
          DateTime.now().add(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': oneHourFuture.toIso8601String(),
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, 0,
          reason:
              'negative diff (user clock moved backward) → clamp to 0');
    });
  });
}
