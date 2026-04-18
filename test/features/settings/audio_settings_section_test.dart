import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioSettingsSection renders 2 disabled switches',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(body: AudioSettingsSection()),
    ));
    await tester.pumpAndSettle();

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2));

    final switch1 = tester.widget<SwitchListTile>(switches.at(0));
    final switch2 = tester.widget<SwitchListTile>(switches.at(1));
    expect(switch1.onChanged, isNull);
    expect(switch2.onChanged, isNull);
  });
}
