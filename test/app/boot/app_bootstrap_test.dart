import 'dart:io';

import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/core/launch/first_boot_notifier.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_bootstrap_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('initialize returns BootstrapResult with ready ProviderContainer',
      () async {
    final boot = await AppBootstrap.initialize(
      containerFactory: () => ProviderContainer(overrides: [
        saveRepositoryProvider.overrideWithValue(
          SaveRepository(directoryProvider: () async => tempDir.path),
        ),
      ]),
    );
    expect(boot, isA<BootstrapResult>());
    expect(boot.container, isA<ProviderContainer>());
    boot.container.dispose();
  });

  group('AppBootstrap — Crashlytics user identity (B3)', () {
    test('initialize does not throw when FirebaseBootstrap not initialized',
        () async {
      // Test env: FirebaseBootstrap.initialize hiç çağrılmadı (veya phase 1
      // fail → isInitialized=false). setUserIdentifier guard skip edilir.
      SharedPreferences.setMockInitialValues({});

      await expectLater(
        () async {
          final boot = await AppBootstrap.initialize(
            containerFactory: () => ProviderContainer(overrides: [
              saveRepositoryProvider.overrideWithValue(
                SaveRepository(directoryProvider: () async => tempDir.path),
              ),
            ]),
          );
          addTearDown(boot.container.dispose);
          return boot;
        },
        returnsNormally,
      );
    });
  });

  group('AppBootstrap — B4 firstBootProvider wire', () {
    test(
        'fresh B4 install: firstBootProvider true → isFirstLaunch propagated',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final boot = await AppBootstrap.initialize(
        containerFactory: () => ProviderContainer(overrides: [
          saveRepositoryProvider.overrideWithValue(
            SaveRepository(directoryProvider: () async => tempDir.path),
          ),
        ]),
      );
      addTearDown(boot.container.dispose);

      expect(boot.container.read(firstBootProvider), true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true);
    });

    test('pre-B4 migration: install_id mevcut → firstBootProvider false',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
      });

      final boot = await AppBootstrap.initialize(
        containerFactory: () => ProviderContainer(overrides: [
          saveRepositoryProvider.overrideWithValue(
            SaveRepository(directoryProvider: () async => tempDir.path),
          ),
        ]),
      );
      addTearDown(boot.container.dispose);

      expect(boot.container.read(firstBootProvider), false,
          reason: 'pre-B4 backfill — AppInstall suppressed');
    });
  });
}
