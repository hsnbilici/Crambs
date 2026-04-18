import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Shell dışı route. `More` bottom sheet'inden `context.push('/settings')`
/// ile açılır — AppBar back button Navigator.canPop sayesinde otomatik gelir.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: Center(child: Text(s.settingsPlaceholder)),
    );
  }
}
