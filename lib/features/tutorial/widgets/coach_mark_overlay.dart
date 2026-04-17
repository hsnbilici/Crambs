import 'package:crumbs/features/tutorial/widgets/_message_callout.dart';
import 'package:crumbs/features/tutorial/widgets/_pulse_halo.dart';
import 'package:flutter/material.dart';

enum HaloShape { rectangle, circle }

/// Target widget'ın render box geometry'sini postFrame'de resolve eder.
/// Target tree'de değilse veya henüz layout edilmemişse SizedBox.shrink.
/// LayoutBuilder ile safe area'ya clamp edilir (edge overflow engeli).
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.targetKey,
    required this.message,
    this.shape = HaloShape.rectangle,
    this.onSkip,
    super.key,
  });

  final GlobalKey? targetKey;
  final String message;
  final HaloShape shape;
  final VoidCallback? onSkip;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  Offset? _topLeft;
  Size? _size;

  @override
  void initState() {
    super.initState();
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      _scheduleResolve();
    }
  }

  void _scheduleResolve() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.targetKey?.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      setState(() {
        _topLeft = box.localToGlobal(Offset.zero);
        _size = box.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topLeft = _topLeft;
    final size = _size;
    if (topLeft == null || size == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final safeRect = Rect.fromLTWH(
        media.padding.left,
        media.padding.top,
        constraints.maxWidth - media.padding.horizontal,
        constraints.maxHeight - media.padding.vertical,
      );
      final clampedLeft =
          topLeft.dx.clamp(safeRect.left, safeRect.right - size.width);
      final clampedTop =
          topLeft.dy.clamp(safeRect.top, safeRect.bottom - size.height);
      final clamped =
          Rect.fromLTWH(clampedLeft, clampedTop, size.width, size.height);
      final halo = clamped.inflate(12);

      return Stack(children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Positioned.fromRect(
          rect: halo,
          child: PulseHalo(shape: widget.shape),
        ),
        MessageCallout(
          rect: clamped,
          message: widget.message,
          onSkip: widget.onSkip,
        ),
      ]);
    });
  }
}
