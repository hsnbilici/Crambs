import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class TutorialReplayDialog extends StatelessWidget {
  const TutorialReplayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return AlertDialog(
      title: Text(s.settingsDevTutorialReplayDialogTitle),
      content: Text(s.settingsDevTutorialReplayDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.settingsDevTutorialReplayCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.settingsDevTutorialReplayConfirm),
        ),
      ],
    );
  }
}
