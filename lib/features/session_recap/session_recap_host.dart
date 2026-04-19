import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session Recap modal orchestrator — emit Shown at open, handle barrier
/// dismiss defense, post-return cleanup.
///
/// Spec §2.2 / §3.1 / invariants I24, I25, I26.
abstract final class SessionRecapHost {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    OfflineReport report,
  ) async {
    // Defense: call sites should already null-check, but idempotent.
    if (ref.read(offlineReportProvider) == null) return;

    _emitShown(ref, report);

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppStrings.of(context)!.sessionRecapDismiss,
      transitionDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => SessionRecapModal(report: report),
    );

    // Barrier dismiss / back gesture: modal CTA handlers fire etmemiş olabilir.
    // Provider hâlâ non-null ise dismiss path'inden emit + clear.
    if (ref.read(offlineReportProvider) != null) {
      _emitDismissed(ref);
      ref.read(offlineReportProvider.notifier).clear();
    }
  }

  static void _emitShown(WidgetRef ref, OfflineReport report) {
    final sessionId =
        ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapShown(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
          offlineDurationMs: report.elapsed.inMilliseconds,
          resourceEarnedOffline: report.earned.toInt(),
        ));
  }

  static void _emitDismissed(WidgetRef ref) {
    final sessionId =
        ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapDismissed(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
        ));
  }
}
