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

    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byIcon(Icons.cookie));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dükkân'));
    await tester.pumpAndSettle();

    expect(find.text('Satın al'), findsOneWidget);
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();
  });
}
