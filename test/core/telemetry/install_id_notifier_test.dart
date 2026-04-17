import 'package:crumbs/core/telemetry/install_id_notifier.dart';
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
}
