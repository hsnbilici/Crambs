import 'dart:io';

import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_providers_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(
            SaveRepository(directoryProvider: () async => tempDir.path),
          ),
        ],
      );

  test('currentCrumbsProvider — reflects notifier state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    container.read(gameStateNotifierProvider.notifier).tapCrumb();
    expect(container.read(currentCrumbsProvider), 1);
  });

  test('productionRateProvider — totalPerSecond sum', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) {
      notifier.tapCrumb();
    }
    await notifier.buyBuilding('crumb_collector');
    expect(container.read(productionRateProvider), closeTo(0.1, 1e-12));
  });

  test('costCurveProvider family — memoized cost lookup', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    expect(container.read(costCurveProvider(('crumb_collector', 0))), 10);
    expect(container.read(costCurveProvider(('crumb_collector', 1))), 11);
    expect(container.read(costCurveProvider(('unknown', 0))), 0);
  });
}
