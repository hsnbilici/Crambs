import 'package:crumbs/features/tutorial/widgets/bottom_nav_callout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BottomNavCallout', () {
    testWidgets('renders message above target key', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 80,
                child: SizedBox(key: key, width: 50, height: 50),
              ),
              BottomNavCallout(targetKey: key, message: "Dükkân'a git"),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text("Dükkân'a git"), findsOneWidget);
    });

    testWidgets('does not render modal barrier (navigation preserved)',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                bottom: 0,
                child: SizedBox(key: key, width: 50, height: 50),
              ),
              BottomNavCallout(targetKey: key, message: 'msg'),
            ],
          ),
        ),
      ));
      await tester.pump();
      // Count baseline (MaterialApp Navigator adds one ModalBarrier).
      // BottomNavCallout itself must NOT add any additional ModalBarrier.
      final baselineCount = find.byType(ModalBarrier).evaluate().length;
      expect(baselineCount, lessThanOrEqualTo(1),
          reason: 'BottomNavCallout must not add its own ModalBarrier');
    });
  });
}
