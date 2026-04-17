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
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.shop,
        builder: (context, state) => const ShopPage(),
      ),
      GoRoute(
        path: Routes.upgrades,
        builder: (context, state) => const UpgradesPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
