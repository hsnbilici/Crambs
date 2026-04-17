import 'package:flutter/material.dart';

/// Step 3 — modal bottom-centered info card. Modal barrier BLOCKS background
/// taps (tutorial'in sonunda CTA ile close edilir).
class InfoCardOverlay extends StatelessWidget {
  const InfoCardOverlay({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onClose,
    super.key,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Text(body, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: onClose,
                        child: Text(ctaLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
