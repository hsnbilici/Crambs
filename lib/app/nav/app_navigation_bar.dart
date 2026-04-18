import 'dart:async';

import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tab destination index'leri.
///
/// Home/Shop/Upgrades StatefulShellRoute branch'ları; Research lock snackbar;
/// More bottom sheet (Settings gibi off-branch route'lara giriş).
enum NavSection { home, shop, upgrades, research, more }

/// BottomNavigationBar — `MainShell` içinde tek bir instance mount edilir.
///
/// [navigationShell]: StatefulShellRoute indexedStack shell'i. `currentIndex`
/// buradan okunur; tab switch `navigationShell.goBranch(index)` ile yapılır
/// (nav state + back stack branch-başına korunur).
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _handleTap(BuildContext context, int index) {
    final section = NavSection.values[index];
    switch (section) {
      case NavSection.home:
      case NavSection.shop:
      case NavSection.upgrades:
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
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
    unawaited(
      showModalBottomSheet<void>(
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
                  // `push`: Settings shell dışı top-level route;
                  // AppBar back button Navigator.canPop ile otomatik gelir.
                  unawaited(context.push('/settings'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    // currentIndex shell branch'tan okunur; More (4) & Research (3) shell
    // dışı olduğu için currentIndex 0..2 aralığında kalır.
    final shellIndex = navigationShell.currentIndex;
    return NavigationBar(
      selectedIndex: shellIndex,
      onDestinationSelected: (i) => _handleTap(context, i),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home), label: s.navHome),
        NavigationDestination(
          icon: Icon(Icons.store, key: kTutorialShopNavKey),
          label: s.navShop,
        ),
        NavigationDestination(
          icon: const Icon(Icons.auto_awesome),
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
