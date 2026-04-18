import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Settings > Ses ve Müzik — B4'te stub; B5'te audio layer geldiğinde
/// `onChanged` handler'ları audioSettingsProvider üzerinden bağlanır.
class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.settingsAudioSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SwitchListTile(
          title: Text(s.settingsAudioMusicToggle),
          subtitle: Text(s.settingsAudioStubHint),
          value: false,
          onChanged: null,
        ),
        SwitchListTile(
          title: Text(s.settingsAudioSfxToggle),
          subtitle: Text(s.settingsAudioStubHint),
          value: false,
          onChanged: null,
        ),
      ],
    );
  }
}
