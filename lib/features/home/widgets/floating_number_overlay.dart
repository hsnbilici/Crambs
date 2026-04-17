import 'package:crumbs/features/home/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingNumberOverlay extends ConsumerWidget {
  const FloatingNumberOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(floatingNumbersProvider);
    final primary = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Stack(
        children: [
          for (final n in numbers)
            Center(
              key: ValueKey(n.id),
              child: Transform.translate(
                offset: Offset(n.dx, 0),
                child: Text(
                  '+${n.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                )
                    .animate(
                      onComplete: (_) => ref
                          .read(floatingNumbersProvider.notifier)
                          .remove(n.id),
                    )
                    .fadeOut(duration: 800.ms, curve: Curves.easeOut)
                    .moveY(begin: 0, end: -80, duration: 800.ms),
              ),
            ),
        ],
      ),
    );
  }
}
