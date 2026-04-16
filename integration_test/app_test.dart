import 'package:crumbs/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uygulama boot olur ve Home ekranı görünür', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Crumbs — Home'), findsOneWidget);
  });
}
