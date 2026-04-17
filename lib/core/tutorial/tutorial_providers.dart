import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:crumbs/core/tutorial/tutorial_notifier.dart'
    show TutorialNotifier, tutorialNotifierProvider;
export 'package:crumbs/core/tutorial/tutorial_state.dart' show TutorialState;
export 'package:crumbs/core/tutorial/tutorial_step.dart';

/// UI mount sırasında AsyncNotifier build() henüz dönmediğinde false döner —
/// tutorial overlay render edilmez (invariant I11 flicker guard).
final tutorialActiveProvider = Provider<bool>((ref) {
  return ref.watch(tutorialNotifierProvider).maybeWhen(
        data: (s) => !s.tutorialCompleted,
        orElse: () => false,
      );
});
