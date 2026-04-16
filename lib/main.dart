import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();
  runApp(const ProviderScope(child: CrumbsApp()));
}

class CrumbsApp extends ConsumerWidget {
  const CrumbsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Crumbs',
      routerConfig: router,
    );
  }
}
