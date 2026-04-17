import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncError fallback — path_provider / SharedPreferences / binding
/// init hatalarında CrumbsApp.build `.when` branch'inden render edilir.
///
/// Save corruption senaryoları SaveRepository + .bak + checksum verify
/// zincirinde absorbe olur (Sprint A NFR-2); bu ekran sadece non-save
/// dış hatalar için. Retry → ref.invalidate(gameStateNotifierProvider).
class ErrorScreen extends ConsumerWidget {
  const ErrorScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_dissatisfied, size: 64),
              const SizedBox(height: 16),
              Text(
                s.errorScreenTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                s.errorScreenBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(gameStateNotifierProvider),
                child: Text(s.errorScreenRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
