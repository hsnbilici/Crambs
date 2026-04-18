import 'dart:io';

import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('crumbs_gs_telemetry_');
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-install-id',
    });
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer(_CaptureLogger logger) {
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(
          directoryProvider: () async => tempDir.path,
        ),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('GameStateNotifier telemetry — PurchaseMade (B4 [I19])', () {
    test('successful buyBuilding → PurchaseMade event emit', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      // 100 tap → 100 Crumbs; crumb_collector cost 15 satın alınabilir
      for (var i = 0; i < 100; i++) {
        notifier.tapCrumb();
      }

      logger.events.clear();
      final ok = await notifier.buyBuilding('crumb_collector');
      expect(ok, true);

      final purchases = logger.events.whereType<PurchaseMade>();
      expect(purchases, hasLength(1));
      final event = purchases.single;
      expect(event.installId, 'test-install-id');
      expect(event.buildingId, 'crumb_collector');
      expect(event.cost, 15);
      expect(event.ownedAfter, 1);
    });

    test('insufficient crumbs buyBuilding → NO emission [I19]', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      final ok = await notifier.buyBuilding('crumb_collector');
      expect(ok, false);

      expect(logger.events.whereType<PurchaseMade>(), isEmpty,
          reason: 'Failed purchase → no emission [I19]');
    });

    test('unknown building id buyBuilding → NO emission', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      final ok = await notifier.buyBuilding('unknown_building');
      expect(ok, false);

      expect(logger.events.whereType<PurchaseMade>(), isEmpty);
    });
  });

  group('GameStateNotifier telemetry — UpgradePurchased (B4 [I19])', () {
    test('successful buyUpgrade → UpgradePurchased event emit', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      for (var i = 0; i < 200; i++) {
        notifier.tapCrumb();
      }

      logger.events.clear();
      final ok = await notifier.buyUpgrade('golden_recipe_i');
      expect(ok, true);

      final purchases = logger.events.whereType<UpgradePurchased>();
      expect(purchases, hasLength(1));
      final event = purchases.single;
      expect(event.installId, 'test-install-id');
      expect(event.upgradeId, 'golden_recipe_i');
      expect(event.cost, 200);
    });

    test('already owned buyUpgrade → NO emission [I19]', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      for (var i = 0; i < 400; i++) {
        notifier.tapCrumb();
      }
      await notifier.buyUpgrade('golden_recipe_i'); // first buy

      logger.events.clear();
      final ok = await notifier.buyUpgrade('golden_recipe_i'); // second
      expect(ok, false);

      expect(logger.events.whereType<UpgradePurchased>(), isEmpty,
          reason: 'Already owned → no re-emission [I19]');
    });
  });
}
