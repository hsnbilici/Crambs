import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrumbCounterHeader extends ConsumerWidget {
  const CrumbCounterHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crumbs = ref.watch(currentCrumbsProvider);
    final rate = ref.watch(productionRateProvider);
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(
          fmt(crumbs),
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 64),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.of(context)!.rateLabel(fmt(rate)),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
