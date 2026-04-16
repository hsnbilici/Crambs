import 'package:crumbs/app/routing/routes.dart';
import 'package:crumbs/features/home/home_page.dart';
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
      // TODO: diğer rotalar eklendikçe buraya eklenir
    ],
  );
});
