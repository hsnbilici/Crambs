import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class MessageCallout extends StatelessWidget {
  const MessageCallout({
    required this.rect,
    required this.message,
    this.onSkip,
    super.key,
  });

  final Rect rect;
  final String message;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final below = rect.bottom + 16 + 120 < media.size.height;
    return Positioned(
      left: 24,
      right: 24,
      top: below ? rect.bottom + 16 : null,
      bottom: below ? null : media.size.height - rect.top + 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              if (onSkip != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: Text(
                      AppStrings.of(context)?.tutorialSkipButton ?? 'Geç',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
