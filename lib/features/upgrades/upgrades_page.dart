import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class UpgradesPage extends StatelessWidget {
  const UpgradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navUpgrades)),
      body: ListView(
        children: [
          UpgradeRow(
            id: 'golden_recipe_i',
            displayName: s.goldenRecipeIName,
          ),
        ],
      ),
    );
  }
}
