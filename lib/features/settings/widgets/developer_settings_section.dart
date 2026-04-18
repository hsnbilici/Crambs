import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/features/settings/widgets/tutorial_replay_dialog.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperSettingsSection extends ConsumerWidget {
  const DeveloperSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.settingsDevSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: Text(s.settingsDevTestCrash),
          subtitle: Text(s.settingsDevTestCrashHint),
          onTap: () => _onTestCrashTap(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.replay),
          title: Text(s.settingsDevTutorialReplay),
          subtitle: Text(s.settingsDevTutorialReplayHint),
          onTap: () => _onTutorialReplayTap(context, ref),
        ),
      ],
    );
  }

  void _onTestCrashTap(BuildContext context, AppStrings s) {
    if (!FirebaseBootstrap.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsDevTestCrashNotInit)),
      );
      return;
    }
    FirebaseCrashlytics.instance.crash();
  }

  Future<void> _onTutorialReplayTap(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const TutorialReplayDialog(),
    );
    if (confirmed ?? false) {
      await ref.read(tutorialNotifierProvider.notifier).reset();
    }
  }
}
