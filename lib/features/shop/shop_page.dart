import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/features/shop/widgets/building_row.dart';
import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navShop)),
      body: ListView(
        children: [
          BuildingRow(
            key: kTutorialShopFirstRowKey,
            id: 'crumb_collector',
            displayName: s.crumbCollectorName,
          ),
          BuildingRow(id: 'oven', displayName: s.ovenName),
          BuildingRow(id: 'bakery_line', displayName: s.bakeryLineName),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
    );
  }
}
