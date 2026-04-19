import 'dart:async';

import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/home/widgets/floating_number_overlay.dart';
import 'package:crumbs/features/home/widgets/onboarding_hint.dart';
import 'package:crumbs/features/home/widgets/tap_area.dart';
import 'package:crumbs/features/session_recap/session_recap_host.dart';
import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = ref.read(offlineReportProvider);
      _maybeShowSessionRecap(report);
    });
  }

  void _maybeShowSessionRecap(OfflineReport? report) {
    if (report == null || report.earned.toInt() <= 0) return;
    if (!mounted) return;
    unawaited(SessionRecapHost.show(context, ref, report));
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<OfflineReport?>(offlineReportProvider, (_, next) {
        _maybeShowSessionRecap(next);
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

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const CrumbCounterHeader(),
              Expanded(child: TapArea(key: kTutorialHeroKey)),
              const SizedBox(height: 8),
            ],
          ),
          const FloatingNumberOverlay(),
          const OnboardingHint(),
        ],
      ),
    );
  }
}
