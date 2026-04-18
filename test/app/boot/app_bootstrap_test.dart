import 'dart:io';

import 'package:crumbs/app/boot/app_bootstrap.dart';
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
}
