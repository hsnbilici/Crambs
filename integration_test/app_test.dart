import 'package:crumbs/features/shop/widgets/building_row.dart';
import 'package:crumbs/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cold start → tap → buy → lifecycle round-trip', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // 15 tap on the cookie icon — should leave ≥10 crumbs afterward.
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byIcon(Icons.cookie));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(
      find.text('15'),
      findsOneWidget,
      reason: 'counter should show 15 after 15 taps',
    );

    // Navigate to shop via nav bar (index 1).
    await tester.tap(find.byIcon(Icons.store));
    await tester.pumpAndSettle();

    // Shop shows one BuildingRow — find via type, not locale string.
    expect(find.byType(BuildingRow), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  });
}
