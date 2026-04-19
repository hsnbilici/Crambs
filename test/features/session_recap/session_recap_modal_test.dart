import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required Widget child,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  const report = OfflineReport(
    earned: 142.7,
    elapsed: Duration(minutes: 42),
    capped: false,
  );

  testWidgets('renders title + earned + elapsed + collect + dismiss',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('Yokken kazandın!'), findsOneWidget);
    expect(find.textContaining('Crumb'), findsOneWidget);
    expect(find.textContaining('dakika'), findsOneWidget);
    expect(find.text('Topla'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('capped=true shows capped badge', (tester) async {
    const capped = OfflineReport(
      earned: 500,
      elapsed: Duration(hours: 10),
      capped: true,
    );
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: capped),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('sınır'), findsOneWidget);
  });

  testWidgets('multiplier secondary line shows ×value', (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('Pasif çarpan: ×'), findsOneWidget);
  });

  testWidgets('disableAnimations → counter instant final value',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
      disableAnimations: true,
    ));
    // Single pump — no animation time advance needed.
    await tester.pump();

    // Counter should show final earned value (142 via fmt, not 0).
    expect(find.textContaining('142'), findsOneWidget);
  });
}
