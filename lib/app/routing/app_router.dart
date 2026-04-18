import 'package:crumbs/app/nav/main_shell.dart';
import 'package:crumbs/app/routing/routes.dart';
import 'package:crumbs/features/home/home_page.dart';
import 'package:crumbs/features/settings/settings_page.dart';
import 'package:crumbs/features/shop/shop_page.dart';
import 'package:crumbs/features/upgrades/upgrades_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      // Tab destinations: StatefulShellRoute tek `MainShell` altında —
      // `AppNavigationBar` ve `kTutorialShopNavKey` bir kez mount edilir
      // (bug_009 duplicate GlobalKey fix).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.shop,
                builder: (context, state) => const ShopPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.upgrades,
                builder: (context, state) => const UpgradesPage(),
              ),
            ],
          ),
        ],
      ),
      // Settings shell dışında — "More" sheet'inden `context.push` ile açılır,
      // AppBar back button Navigator.canPop ile otomatik gelir.
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
