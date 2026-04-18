import 'package:crumbs/features/settings/providers.dart';
import 'package:crumbs/features/settings/settings_page.dart';
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
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

  Widget appUnderTest({required bool showDev}) {
    return ProviderScope(
      overrides: [developerVisibilityProvider.overrideWithValue(showDev)],
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: SettingsPage(),
      ),
    );
  }

  testWidgets('default dev flag true → 2 section render', (tester) async {
    await tester.pumpWidget(appUnderTest(showDev: true));
    await tester.pumpAndSettle();

    expect(find.byType(AudioSettingsSection), findsOneWidget);
    expect(find.byType(DeveloperSettingsSection), findsOneWidget);
  });

  testWidgets('dev flag false → only Audio section (Developer hidden)',
      (tester) async {
    await tester.pumpWidget(appUnderTest(showDev: false));
    await tester.pumpAndSettle();

    expect(find.byType(AudioSettingsSection), findsOneWidget);
    expect(find.byType(DeveloperSettingsSection), findsNothing);
  });
}
