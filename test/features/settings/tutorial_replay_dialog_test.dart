import 'package:crumbs/features/settings/widgets/tutorial_replay_dialog.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps `showDialog<bool>` in a scaffold. The dialog result is stored via
/// the [resultSink] setter after the dialog closes.
Future<void> pumpDialogHost(
  WidgetTester tester, {
  required ValueSetter<bool?> resultSink,
}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (_) => const TutorialReplayDialog(),
              );
              resultSink(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('Confirm button pops with true', (tester) async {
    bool? result;
    await pumpDialogHost(tester, resultSink: (v) => result = v);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evet, yeniden oyna'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('Cancel button pops with false', (tester) async {
    bool? result;
    await pumpDialogHost(tester, resultSink: (v) => result = v);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('Dialog body contains reassurance copy', (tester) async {
    await pumpDialogHost(tester, resultSink: (_) {});

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('kaybolmaz'), findsOneWidget);
  });
}
