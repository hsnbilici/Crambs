import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/home/widgets/floating_number_overlay.dart';
import 'package:crumbs/features/home/widgets/onboarding_hint.dart';
import 'package:crumbs/features/home/widgets/tap_area.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..listen(offlineReportProvider, (_, next) {
        if (next == null) return;
        final s = AppStrings.of(context)!;
        final mins = next.elapsed.inMinutes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.welcomeBack(fmt(next.earned), '$mins dk')),
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(offlineReportProvider.notifier).clear();
      })
      ..listen(saveRecoveryProvider, (_, next) {
        if (next == null) return;
        final s = AppStrings.of(context)!;
        final msg = switch (next) {
          SaveRecoveryReason.checksumFailedUsedBackup => s.saveRecoveryBackup,
          SaveRecoveryReason.bothCorruptedStartedFresh => s.saveRecoveryFresh,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        ref.read(saveRecoveryProvider.notifier).clear();
      });

    return const Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              CrumbCounterHeader(),
              Expanded(child: TapArea()),
              SizedBox(height: 8),
            ],
          ),
          FloatingNumberOverlay(),
          OnboardingHint(),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: 0),
    );
  }
}
