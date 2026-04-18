import 'package:flutter/material.dart';

/// BottomNav üzerinde konumlandırılan callout. Modal barrier YOK — kullanıcı
/// gerçekten "Dükkân" item'ına tap edebilmeli (Step 2 advance trigger'ı
/// route değişimi değil, ilk building purchase. Ama kullanıcı Dükkân'a gitmeyi
/// öğrenmeli, bu yüzden navigasyon açık kalır).
class BottomNavCallout extends StatefulWidget {
  const BottomNavCallout({
    required this.targetKey,
    required this.message,
    super.key,
  });

  final GlobalKey targetKey;
  final String message;

  @override
  State<BottomNavCallout> createState() => _BottomNavCalloutState();
}

class _BottomNavCalloutState extends State<BottomNavCallout> {
  Offset? _topLeft;
  Size? _size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.targetKey.currentContext;
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

    final theme = Theme.of(context);
    final centerX = topLeft.dx + size.width / 2;
    const calloutWidth = 200.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxLeft = screenWidth - 16 - calloutWidth;
    final leftClamped =
        (centerX - calloutWidth / 2).clamp(16.0, maxLeft);

    return Positioned(
      left: leftClamped,
      top: topLeft.dy - 72,
      width: calloutWidth,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_downward,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
