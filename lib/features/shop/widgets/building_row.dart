import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BuildingRow extends ConsumerStatefulWidget {
  const BuildingRow({
    required this.id,
    required this.displayName,
    super.key,
  });

  final String id;
  final String displayName;

  @override
  ConsumerState<BuildingRow> createState() => _BuildingRowState();
}

class _BuildingRowState extends ConsumerState<BuildingRow> {
  int _shakeSeq = 0;

  Future<void> _onBuy() async {
    final success = await ref
        .read(gameStateNotifierProvider.notifier)
        .buyBuilding(widget.id);
    if (!success && mounted) {
      setState(() => _shakeSeq++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context)!.insufficientCrumbs),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateNotifierProvider).value;
    final owned = gs?.buildings.owned[widget.id] ?? 0;
    final cost = ref.watch(costCurveProvider((widget.id, owned)));
    final crumbs = ref.watch(currentCrumbsProvider);
    final canAfford = crumbs >= cost;
    final theme = Theme.of(context);

    final button = FilledButton(
      onPressed: _onBuy,
      child: Text(AppStrings.of(context)!.buyButton),
    );

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(AppStrings.of(context)!.ownedLabel(owned)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt(cost.toDouble()), style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Opacity(
                  opacity: canAfford ? 1.0 : 0.5,
                  child: button
                      .animate(
                        key: ValueKey(_shakeSeq),
                        target: _shakeSeq > 0 ? 1 : 0,
                      )
                      .shake(duration: 300.ms, hz: 6, rotation: 0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
