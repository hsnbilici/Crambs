import 'package:crumbs/features/settings/providers.dart';
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/features/settings/widgets/developer_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell dışı route. `More` bottom sheet'inden `context.push('/settings')`
/// ile açılır — AppBar back button Navigator.canPop sayesinde otomatik gelir.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    final showDev = ref.watch(developerVisibilityProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        children: [
          const AudioSettingsSection(),
          if (showDev) const DeveloperSettingsSection(),
        ],
      ),
    );
  }
}
