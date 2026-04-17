import 'package:crumbs/features/tutorial/widgets/info_card_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfoCardOverlay', () {
    testWidgets('renders title, body, cta and calls onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              InfoCardOverlay(
                title: 'Neden Crumb?',
                body: 'Binalar C/s üretir.',
                ctaLabel: 'Anladım',
                onClose: () => closed = true,
              ),
            ],
          ),
        ),
      ));
      expect(find.text('Neden Crumb?'), findsOneWidget);
      expect(find.text('Binalar C/s üretir.'), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      expect(closed, true);
    });

    testWidgets('renders its own ModalBarrier (blocks background taps)',
        (tester) async {
      // Baseline: no MaterialApp Navigator → baseline 0 ModalBarrier;
      // with MaterialApp, baseline is 1. InfoCardOverlay adds 1 more.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              InfoCardOverlay(
                title: 't',
                body: 'b',
                ctaLabel: 'ok',
                onClose: () {},
              ),
            ],
          ),
        ),
      ));
      // MaterialApp Navigator baseline (1) + InfoCardOverlay (1) = 2.
      final barriers = find.byType(ModalBarrier).evaluate();
      expect(barriers.length, greaterThanOrEqualTo(2),
          reason: 'InfoCardOverlay must add its own ModalBarrier on top of '
              'MaterialApp Navigator baseline');
    });
  });
}
