import 'dart:async';

import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum NavSection { home, shop, upgrades, research, more }

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({required this.currentIndex, super.key});

  final int currentIndex;

  void _handleTap(BuildContext context, int index) {
    final section = NavSection.values[index];
    switch (section) {
      case NavSection.home:
        context.go('/');
      case NavSection.shop:
        context.go('/shop');
      case NavSection.upgrades:
        _snack(context, AppStrings.of(context)!.navLockUpgradesA);
      case NavSection.research:
        _snack(context, AppStrings.of(context)!.navLockResearch);
      case NavSection.more:
        _showMoreSheet(context);
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final s = AppStrings.of(context)!;
    unawaited(showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(s.navEvents),
              subtitle: Text(s.navLockEvents),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: Text(s.navPrestige),
              subtitle: Text(s.navLockPrestige),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.collections),
              title: Text(s.navCollection),
              subtitle: Text(s.navLockCollection),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(s.navSettings),
              onTap: () {
                Navigator.of(c).pop();
                context.go('/settings');
              },
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _handleTap(context, i),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home), label: s.navHome),
        NavigationDestination(
          icon: const Icon(Icons.store),
          label: s.navShop,
        ),
        NavigationDestination(
          icon: const Icon(Icons.lock_outline),
          label: s.navUpgrades,
        ),
        NavigationDestination(
          icon: const Icon(Icons.lock_outline),
          label: s.navResearch,
        ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          label: s.navMore,
        ),
      ],
    );
  }
}
