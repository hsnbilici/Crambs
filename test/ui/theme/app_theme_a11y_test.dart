import 'package:crumbs/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme — a11y 48dp minimum tap target', () {
    testWidgets('FilledButton resolves height >= 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('TextButton resolves height >= 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('dark theme also enforces 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
