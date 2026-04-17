import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TapArea extends ConsumerStatefulWidget {
  const TapArea({super.key});

  @override
  ConsumerState<TapArea> createState() => _TapAreaState();
}

class _TapAreaState extends ConsumerState<TapArea> {
  double _scale = 1;

  void _onTap() {
    ref.read(gameStateNotifierProvider.notifier).tapCrumb();
    ref.read(floatingNumbersProvider.notifier).spawn(1);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: _onTap,
      child: Center(
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cookie, size: 140, color: color),
          ),
        ),
      ),
    );
  }
}
