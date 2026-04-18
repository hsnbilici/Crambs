import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutorial_state.freezed.dart';

/// Tutorial state — SharedPreferences'tan hydrate edilir.
/// currentStep disk'e YAZILMAZ (session-only, invariant I2).
@freezed
abstract class TutorialState with _$TutorialState {
  const factory TutorialState({
    required bool firstLaunchMarked,
    required bool tutorialCompleted,
    required TutorialStep? currentStep,
  }) = _TutorialState;
}
