import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initial state — hint not dismissed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(onboardingPrefsProvider.notifier).ensureLoaded();
    expect(container.read(onboardingPrefsProvider).hintDismissed, isFalse);
  });

  test('dismissHint flips flag and persists across containers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(onboardingPrefsProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dismissHint();

    expect(container.read(onboardingPrefsProvider).hintDismissed, isTrue);

    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    await fresh.read(onboardingPrefsProvider.notifier).ensureLoaded();
    expect(fresh.read(onboardingPrefsProvider).hintDismissed, isTrue);
  });
}
