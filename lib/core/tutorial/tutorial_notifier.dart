import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AsyncNotifier pattern — build() async hydrate, flicker race engellenir.
/// tutorialActiveProvider (T8) loading state'te false döner.
class TutorialNotifier extends AsyncNotifier<TutorialState> {
  static const _prefKeyFirstLaunch = 'crumbs.first_launch_marked';
  static const _prefKeyCompleted = 'crumbs.tutorial_completed';

  @override
  Future<TutorialState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return TutorialState(
      firstLaunchMarked: prefs.getBool(_prefKeyFirstLaunch) ?? false,
      tutorialCompleted: prefs.getBool(_prefKeyCompleted) ?? false,
      currentStep: null,
    );
  }

  TutorialState get _state => state.requireValue;

  /// Idempotent. No-op if tutorialCompleted or firstLaunchMarked already true,
  /// or if currentStep already set.
  Future<void> start() async {
    final current = _state;
    if (current.tutorialCompleted || current.currentStep != null) return;
    if (current.firstLaunchMarked) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyFirstLaunch, true);
    state = AsyncData(current.copyWith(
      firstLaunchMarked: true,
      currentStep: TutorialStep.tapCupcake,
    ));
  }

  /// Re-entry guard: only advances if currentStep == expected.
  void advance({required TutorialStep from}) {
    final current = _state;
    if (current.currentStep != from) return;
    state = AsyncData(current.copyWith(currentStep: _nextStep(from)));
  }

  Future<void> skip() async {
    await _markCompleted();
  }

  Future<void> complete() async {
    await _markCompleted();
  }

  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyCompleted, true);
    state = AsyncData(_state.copyWith(
      tutorialCompleted: true,
      currentStep: null,
    ));
  }

  TutorialStep? _nextStep(TutorialStep current) {
    return switch (current) {
      TutorialStep.tapCupcake => TutorialStep.openShop,
      TutorialStep.openShop => TutorialStep.explainCrumbs,
      TutorialStep.explainCrumbs => null,
    };
  }
}

final tutorialNotifierProvider =
    AsyncNotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
