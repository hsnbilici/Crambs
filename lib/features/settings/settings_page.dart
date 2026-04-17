import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: Center(child: Text(s.settingsPlaceholder)),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 4),
    );
  }
}
