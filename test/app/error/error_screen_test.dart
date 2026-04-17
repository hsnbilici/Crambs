import 'package:crumbs/app/error/error_screen.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorScreen', () {
    testWidgets('renders title + body + retry button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
            home: ErrorScreen(error: 'test error'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beklenmedik bir hata'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_dissatisfied), findsOneWidget);
    });

    testWidgets('retry tap does not throw', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
            home: ErrorScreen(error: 'test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      // No crash — invalidate succeeds even without pre-initialized provider.
    });
  });
}
