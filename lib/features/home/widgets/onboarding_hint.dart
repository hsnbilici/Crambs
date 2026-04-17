import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// IgnorePointer — tap event'i altındaki TapArea'ya pass-through.
/// Dismiss logic GameStateNotifier.tapCrumb içinde.
class OnboardingHint extends ConsumerWidget {
  const OnboardingHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed =
        ref.watch(onboardingPrefsProvider.select((p) => p.hintDismissed));
    if (dismissed) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 420),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            AppStrings.of(context)!.tapHint,
            style: Theme.of(context).textTheme.bodyLarge,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 400.ms)
              .then(delay: 600.ms)
              .fadeOut(duration: 400.ms),
        ),
      ),
    );
  }
}
