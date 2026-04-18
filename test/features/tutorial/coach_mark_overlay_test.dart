import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachMarkOverlay', () {
    testWidgets('renders SizedBox.shrink before postFrame resolves',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                child: SizedBox(key: key, width: 100, height: 100),
              ),
              CoachMarkOverlay(targetKey: key, message: 'test'),
            ],
          ),
        ),
      ));
      // Before postFrame fires, CoachMarkOverlay renders SizedBox.shrink.
      // MaterialApp navigator always contributes a baseline ModalBarrier;
      // CoachMarkOverlay must not have added its own yet.
      final baselineCount =
          find.byType(ModalBarrier).evaluate().length;
      expect(find.byType(SizedBox), findsWidgets);

      await tester.pump();
      // After postFrame resolves, CoachMarkOverlay adds one ModalBarrier.
      expect(
        find.byType(ModalBarrier),
        findsNWidgets(baselineCount + 1),
      );
    });

    testWidgets('shows message callout after geometry resolve',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 50,
                top: 50,
                child: SizedBox(key: key, width: 80, height: 80),
              ),
              CoachMarkOverlay(targetKey: key, message: 'Test message'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('calls onSkip when skip button tapped', (tester) async {
      final key = GlobalKey();
      var skipped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                child: SizedBox(key: key, width: 50, height: 50),
              ),
              CoachMarkOverlay(
                targetKey: key,
                message: 'msg',
                onSkip: () => skipped = true,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Geç'));
      expect(skipped, true);
    });

    testWidgets('no skip button when onSkip is null', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                child: SizedBox(key: key, width: 50, height: 50),
              ),
              CoachMarkOverlay(targetKey: key, message: 'msg'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Geç'), findsNothing);
    });

    testWidgets('HaloShape.circle renders without throwing', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                child: SizedBox(key: key, width: 50, height: 50),
              ),
              CoachMarkOverlay(
                targetKey: key,
                message: 'msg',
                shape: HaloShape.circle,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(CoachMarkOverlay), findsOneWidget);
    });

    testWidgets('does not crash when target wider than safe area (bug_002)',
        (tester) async {
      final key = GlobalKey();
      // Simulate notched landscape: non-zero horizontal padding +
      // target wider than safe area width.
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.symmetric(horizontal: 44),
            size: Size(400, 200),
          ),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 50,
                  child: SizedBox(key: key, width: 400, height: 80),
                ),
                CoachMarkOverlay(targetKey: key, message: 'oversized target'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'clamp precondition violation should not crash');
      expect(find.byType(CoachMarkOverlay), findsOneWidget);
    });
  });
}
