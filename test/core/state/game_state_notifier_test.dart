import 'dart:io';

import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_notifier_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
    ]);
  }

  test('cold start — no save → initial state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = await container.read(gameStateNotifierProvider.future);
    expect(state.inventory.r1Crumbs, 0);
    expect(state.buildings.owned, isEmpty);
  });

  test('tapCrumb increments r1Crumbs by 1', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    container.read(gameStateNotifierProvider.notifier).tapCrumb();
    final gs = container.read(gameStateNotifierProvider).value!;
    expect(gs.inventory.r1Crumbs, 1);
  });

  test('buyBuilding — insufficient → false, state unchanged', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    final result = await notifier.buyBuilding('crumb_collector');
    expect(result, isFalse);
    final gs = container.read(gameStateNotifierProvider).value!;
    expect(gs.inventory.r1Crumbs, 0);
    expect(gs.buildings.owned, isEmpty);
  });

  test('buyBuilding — sufficient → true, cost deducted, owned++', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) {
      notifier.tapCrumb();
    }
    final result = await notifier.buyBuilding('crumb_collector');
    expect(result, isTrue);
    final gs = container.read(gameStateNotifierProvider).value!;
    expect(gs.inventory.r1Crumbs, 0);
    expect(gs.buildings.owned['crumb_collector'], 1);
  });

  test('applyProductionDelta adds fractional crumbs', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) {
      notifier.tapCrumb();
    }
    await notifier.buyBuilding('crumb_collector');
    notifier.applyProductionDelta(10);
    final gs = container.read(gameStateNotifierProvider).value!;
    expect(gs.inventory.r1Crumbs, closeTo(1, 1e-9));
  });

  test('applyResumeDelta — hot resume offline progress, no OfflineReport push',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) {
      notifier.tapCrumb();
    }
    await notifier.buyBuilding('crumb_collector');
    final before = container.read(gameStateNotifierProvider).value!;
    final pauseTime = DateTime.parse(before.meta.lastSavedAt);
    final resumeTime = pauseTime.add(const Duration(seconds: 30));
    notifier.applyResumeDelta(now: resumeTime);
    final after = container.read(gameStateNotifierProvider).value!;
    expect(
      after.inventory.r1Crumbs - before.inventory.r1Crumbs,
      closeTo(3, 1e-9),
    ); // 1 collector × 0.1 C/s × 30s = 3
    // INVARIANT: OfflineReport NOT pushed on hot resume
    expect(container.read(offlineReportProvider), isNull);
    // INVARIANT: SaveRecovery NOT pushed on hot resume
    expect(container.read(saveRecoveryProvider), isNull);
  });

  test('resetTickClock — warmup first tick after reset', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    // resetTickClock should not throw, should not change state
    final before = container.read(gameStateNotifierProvider).value!;
    notifier.resetTickClock();
    final after = container.read(gameStateNotifierProvider).value!;
    expect(after, equals(before));
  });

  group('GameStateNotifier.buyUpgrade', () {
    test('happy — golden_recipe_i alınır, crumbs düşer, owned set olur',
        () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(250);

      final success = await notifier.buyUpgrade('golden_recipe_i');
      expect(success, isTrue);

      final gs = container.read(gameStateNotifierProvider).value!;
      expect(gs.upgrades.owned['golden_recipe_i'], isTrue);
      expect(gs.inventory.r1Crumbs, closeTo(50, 1e-9));
    });

    test('insufficient crumbs → returns false, state unchanged', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(100);

      final success = await notifier.buyUpgrade('golden_recipe_i');
      expect(success, isFalse);
      expect(
        container.read(gameStateNotifierProvider).value!.upgrades.owned,
        isEmpty,
      );
    });

    test('unknown upgrade id → returns false, state unchanged', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(10000);

      final success = await notifier.buyUpgrade('ghost_upgrade_xyz');
      expect(success, isFalse);
    });

    test('already owned → returns false, silent (no crumb re-charge)',
        () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(500);
      await notifier.buyUpgrade('golden_recipe_i');
      final before = container.read(gameStateNotifierProvider).value!;

      final success = await notifier.buyUpgrade('golden_recipe_i');
      expect(success, isFalse);
      final after = container.read(gameStateNotifierProvider).value!;
      expect(after.inventory.r1Crumbs, before.inventory.r1Crumbs);
      expect(after.upgrades.owned, before.upgrades.owned);
    });
  });

  group('GameStateNotifier — MultiplierChain injection', () {
    test(
        'productionRateProvider reflects chain — '
        '1 Collector + Golden Recipe = 0.15', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(500);
      await notifier.buyBuilding('crumb_collector');
      await notifier.buyUpgrade('golden_recipe_i');

      final rate = container.read(productionRateProvider);
      expect(rate, closeTo(0.15, 1e-9)); // 0.1 × 1.5
    });

    test('applyResumeDelta preserves upgrades (invariant #10)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      final notifier = container.read(gameStateNotifierProvider.notifier)
        ..debugAddCrumbs(500);
      await notifier.buyUpgrade('golden_recipe_i');
      final before = container.read(gameStateNotifierProvider).value!;

      notifier.applyResumeDelta(
        now: DateTime.now().add(const Duration(seconds: 10)),
      );
      final after = container.read(gameStateNotifierProvider).value!;

      expect(
        after.upgrades.owned,
        before.upgrades.owned,
        reason: 'resume must not mutate upgrades',
      );
    });
  });

  group('GameStateNotifier — debugAddCrumbs helper', () {
    test('debugAddCrumbs adds without side-effects', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(gameStateNotifierProvider.future);

      container
          .read(gameStateNotifierProvider.notifier)
          .debugAddCrumbs(42);

      expect(
        container.read(gameStateNotifierProvider).value!.inventory.r1Crumbs,
        42,
      );
    });
  });
}
