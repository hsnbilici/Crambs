import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `StatefulShellRoute.indexedStack` için Scaffold shell.
///
/// Tek bir `AppNavigationBar` instance'ı host'lar — bu sayede nav bar içindeki
/// `kTutorialShopNavKey` GlobalKey'i sadece bir widget'a bağlı kalır. Shell
/// öncesi pattern'de her sayfa kendi `AppNavigationBar`'ını mount ediyordu,
/// route transition'ında (outgoing + incoming Scaffold) duplicate GlobalKey
/// assertion'ı fire oluyordu (bug_009 ultrareview).
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppNavigationBar(navigationShell: navigationShell),
    );
  }
}
