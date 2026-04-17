import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/features/tutorial/widgets/bottom_nav_callout.dart';
import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart';
import 'package:crumbs/features/tutorial/widgets/info_card_overlay.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tutorial overlay katmanı. MaterialApp.router(builder:) üzerinden mount —
/// invariant I12. GoRouterState.of(context) router tree context gerektirir.
class TutorialScaffold extends ConsumerStatefulWidget {
  const TutorialScaffold({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TutorialScaffold> createState() => _TutorialScaffoldState();
}

class _TutorialScaffoldState extends ConsumerState<TutorialScaffold> {
  bool _startInvoked = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _startInvoked) return;
      final loaded = await ref.read(tutorialNotifierProvider.future);
      if (!mounted) return;
      if (loaded.tutorialCompleted || loaded.firstLaunchMarked) return;
      _startInvoked = true;
      await ref.read(tutorialNotifierProvider.notifier).start();
      final postState = ref.read(tutorialNotifierProvider).value;
      if (postState?.currentStep == TutorialStep.tapCupcake) {
        _startedAt = DateTime.now();
        ref.read(telemetryLoggerProvider).log(
              TutorialStarted(
                installId: resolveInstallIdForTelemetry(
                  ref.read(installIdProvider),
                ),
              ),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(tutorialNotifierProvider);
    final step = asyncState.maybeWhen(
      data: (s) => s.currentStep,
      orElse: () => null,
    );

    ref.listen<AsyncValue<GameState>>(gameStateNotifierProvider, (prev, next) {
      if (step == null) return;
      final prevCrumbs = prev?.value?.inventory.r1Crumbs ?? 0;
      final nextCrumbs = next.value?.inventory.r1Crumbs ?? 0;
      if (step == TutorialStep.tapCupcake && nextCrumbs > prevCrumbs) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
      final prevOwned = prev?.value?.buildings.owned['crumb_collector'] ?? 0;
      final nextOwned = next.value?.buildings.owned['crumb_collector'] ?? 0;
      if (step == TutorialStep.openShop && nextOwned > prevOwned) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
    });

    return Stack(
      children: [
        widget.child,
        if (step != null) _buildOverlay(step),
      ],
    );
  }

  Widget _buildOverlay(TutorialStep step) {
    final s = AppStrings.of(context)!;
    final notifier = ref.read(tutorialNotifierProvider.notifier);

    return switch (step) {
      TutorialStep.tapCupcake => CoachMarkOverlay(
          targetKey: kTutorialCupcakeKey,
          message: s.tutorialStep1Message,
          shape: HaloShape.circle,
          onSkip: () => _onSkipPressed(notifier),
        ),
      TutorialStep.openShop => _buildStep2Overlay(s),
      TutorialStep.explainCrumbs => InfoCardOverlay(
          title: s.tutorialStep3Title,
          body: s.tutorialStep3Body,
          ctaLabel: s.tutorialCloseButton,
          onClose: () => _onCompletePressed(notifier),
        ),
    };
  }

  Widget _buildStep2Overlay(AppStrings s) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/shop') {
      return CoachMarkOverlay(
        targetKey: kTutorialShopFirstRowKey,
        message: s.tutorialStep2ShopMessage,
      );
    }
    return BottomNavCallout(
      targetKey: kTutorialShopNavKey,
      message: s.tutorialStep2NavMessage,
    );
  }

  Future<void> _onSkipPressed(TutorialNotifier notifier) async {
    await notifier.skip();
    _emitCompleted(skipped: true);
  }

  Future<void> _onCompletePressed(TutorialNotifier notifier) async {
    await notifier.complete();
    _emitCompleted(skipped: false);
  }

  void _emitCompleted({required bool skipped}) {
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    ref.read(telemetryLoggerProvider).log(
          TutorialCompleted(
            installId: resolveInstallIdForTelemetry(
              ref.read(installIdProvider),
            ),
            skipped: skipped,
            durationMs: duration.inMilliseconds,
          ),
        );
  }
}
