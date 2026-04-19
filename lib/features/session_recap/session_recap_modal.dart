import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session Recap Modal — offline kazanç ceremony + 2 CTA.
/// Spec: docs/superpowers/specs/2026-04-19-sprint-b6-session-recap-design.md §2
/// UX: docs/ux-flows.md §6
class SessionRecapModal extends ConsumerWidget {
  const SessionRecapModal({required this.report, super.key});

  final OfflineReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final multiplier = ref.watch(multiplierChainTotalProvider);

    return Dialog(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.sessionRecapTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _onDismiss(context, ref),
                      tooltip: s.sessionRecapDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: report.earned),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1500),
                  builder: (_, value, _) => Text(
                    s.sessionRecapEarned(fmt(value)),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(s.sessionRecapElapsed(_fmtDuration(report.elapsed))),
                if (report.capped) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.sessionRecapCapped(8),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  s.sessionRecapMultiplier(multiplier.toStringAsFixed(2)),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => _onCollect(context, ref),
                    child: Text(s.sessionRecapCollect),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onCollect(BuildContext context, WidgetRef ref) async {
    // Ceremony intentionally NOT forced — pop immediate. Earned Crumbs
    // already in ledger [I25]; animation is opsiyonel presentation.
    _emitActionTaken(ref, kActionCollect);
    ref.read(offlineReportProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onDismiss(BuildContext context, WidgetRef ref) async {
    // Idempotency guard — host post-return path'inden çağrılmışsa skip [I26].
    if (ref.read(offlineReportProvider) == null) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    _emitDismissed(ref);
    ref.read(offlineReportProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
  }

  void _emitActionTaken(WidgetRef ref, String actionType) {
    final sessionId =
        ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapActionTaken(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
          actionType: actionType,
        ));
  }

  void _emitDismissed(WidgetRef ref) {
    final sessionId =
        ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapDismissed(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
        ));
  }
}

String _fmtDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} saat ${d.inMinutes % 60} dakika';
  return '${d.inMinutes} dakika';
}
