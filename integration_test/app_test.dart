import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/shop/widgets/building_row.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cold start → tap → buy building → buy upgrade', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CrumbCounterHeader)),
    );

    // 1 Collector için 15 C gerekir → 16 tap (buffer için)
    for (var i = 0; i < 16; i++) {
      await tester.tap(find.byIcon(Icons.cookie));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Shop → 3 BuildingRow görünür
    await tester.tap(find.byIcon(Icons.store));
    await tester.pumpAndSettle();
    expect(find.byType(BuildingRow), findsNWidgets(3));

    // Collector satın al (ilk buildable button)
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // Golden Recipe I için 200 C — tap-spam yerine @visibleForTesting helper
    container.read(gameStateNotifierProvider.notifier).debugAddCrumbs(200);
    await tester.pumpAndSettle();

    // Upgrades tab (auto_awesome icon)
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();
    expect(find.byType(UpgradeRow), findsOneWidget);

    // Satın al
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // Owned badge
    expect(find.text('Sahip ✓'), findsOneWidget);

    // Production rate × 1.5 assertion
    expect(
      container.read(productionRateProvider),
      closeTo(0.15, 1e-9),
      reason: '1 Collector (0.1) × Golden Recipe I (1.5) = 0.15 C/s',
    );
  });
}
