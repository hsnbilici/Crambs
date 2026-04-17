import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/features/shop/widgets/building_row.dart';
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
          BuildingRow(id: 'crumb_collector', displayName: s.crumbCollectorName),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
    );
  }
}
