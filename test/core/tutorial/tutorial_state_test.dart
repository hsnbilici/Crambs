import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialState', () {
    test('equality — same fields', () {
      const a = TutorialState(
        firstLaunchMarked: false,
        tutorialCompleted: false,
        currentStep: null,
      );
      const b = TutorialState(
        firstLaunchMarked: false,
        tutorialCompleted: false,
        currentStep: null,
      );
      expect(a, b);
    });

    test('copyWith updates currentStep only', () {
      const a = TutorialState(
        firstLaunchMarked: true,
        tutorialCompleted: false,
        currentStep: null,
      );
      final b = a.copyWith(currentStep: TutorialStep.tapHero);
      expect(b.firstLaunchMarked, true);
      expect(b.tutorialCompleted, false);
      expect(b.currentStep, TutorialStep.tapHero);
    });
  });

  group('TutorialStep enum', () {
    test('has 3 values', () {
      expect(TutorialStep.values, hasLength(3));
      expect(
        TutorialStep.values,
        containsAll([
          TutorialStep.tapHero,
          TutorialStep.openShop,
          TutorialStep.explainCrumbs,
        ]),
      );
    });
  });
}
