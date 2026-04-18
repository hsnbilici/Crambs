import 'package:crumbs/features/settings/widgets/developer_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget appUnderTest({ProviderContainer? container}) {
    return UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(body: DeveloperSettingsSection()),
      ),
    );
  }

  testWidgets('Test Crash button isInitialized=false → snackbar shown',
      (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(appUnderTest(container: c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Crash Gönder'));
    await tester.pumpAndSettle();

    // Test env: FirebaseBootstrap.isInitialized=false (default)
    expect(find.textContaining('Firebase başlatılmadı'), findsOneWidget);
  });

  testWidgets('Tutorial Replay button opens dialog', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(appUnderTest(container: c));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Tutorial'i Tekrar Oyna"));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Tutorial yeniden oynatılsın mı?'),
      findsOneWidget,
    );
  });

  testWidgets('Widget structure smoke — 2 ListTile + Divider', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(appUnderTest(container: c));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.byType(Divider), findsOneWidget);
  });
}
