import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_prefs.freezed.dart';

@freezed
abstract class OnboardingPrefs with _$OnboardingPrefs {
  const factory OnboardingPrefs({
    required bool hintDismissed,
  }) = _OnboardingPrefs;

  factory OnboardingPrefs.initial() =>
      const OnboardingPrefs(hintDismissed: false);
}

/// Onboarding tercihleri — SharedPreferences backed.
/// GameState (save envelope) DIŞINDA. Checksum/migration etkilenmez.
///
/// Cold start: AppBootstrap.initialize() sonrası (Task 12) container.read(
/// onboardingPrefsProvider.notifier).ensureLoaded() çağrılır — UI rebuild
/// etmeden önce.
final onboardingPrefsProvider =
    NotifierProvider<OnboardingPrefsNotifier, OnboardingPrefs>(
  OnboardingPrefsNotifier.new,
);

class OnboardingPrefsNotifier extends Notifier<OnboardingPrefs> {
  static const _keyHintDismissed = 'onboarding.hint_dismissed';

  @override
  OnboardingPrefs build() => OnboardingPrefs.initial();

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = OnboardingPrefs(
      hintDismissed: prefs.getBool(_keyHintDismissed) ?? false,
    );
  }

  Future<void> dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHintDismissed, true);
    state = state.copyWith(hintDismissed: true);
  }
}
