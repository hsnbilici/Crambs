import 'dart:async';

import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart'
    show HaloShape;
import 'package:flutter/material.dart';

class PulseHalo extends StatefulWidget {
  const PulseHalo({required this.shape, super.key});

  final HaloShape shape;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    unawaited(_controller.repeat(reverse: true));
    _scale = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: widget.shape == HaloShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: widget.shape == HaloShape.rectangle
              ? BorderRadius.circular(12)
              : null,
          border: Border.all(color: color, width: 3),
        ),
      ),
    );
  }
}
