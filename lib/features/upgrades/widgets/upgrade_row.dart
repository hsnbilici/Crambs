import 'package:crumbs/core/economy/upgrade_defs.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Upgrade satın alma satırı — BuildingRow pattern'inin upgrade versiyonu.
///
/// `owned == true` durumunda button render edilmez; "Sahip ✓" Chip görünür.
/// Bu, GameStateNotifier.buyUpgrade'daki already-owned defensive branch'ını
/// prodüksiyon flow'undan dışlar (bkz spec §2.4 invariant #11).
class UpgradeRow extends ConsumerStatefulWidget {
  const UpgradeRow({
    required this.id,
    required this.displayName,
    super.key,
  });

  final String id;
  final String displayName;

  @override
  ConsumerState<UpgradeRow> createState() => _UpgradeRowState();
}

class _UpgradeRowState extends ConsumerState<UpgradeRow> {
  int _shakeSeq = 0;

  Future<void> _onBuy() async {
    final success = await ref
        .read(gameStateNotifierProvider.notifier)
        .buyUpgrade(widget.id);
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
    final owned = gs?.upgrades.owned[widget.id] ?? false;
    final cost = UpgradeDefs.baseCostFor(widget.id);
    final crumbs = ref.watch(currentCrumbsProvider);
    final canAfford = crumbs >= cost;
    final theme = Theme.of(context);
    final s = AppStrings.of(context)!;

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
                  Text(
                    s.goldenRecipeIDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (owned)
              Chip(
                label: Text(s.upgradeOwnedBadge),
                backgroundColor: theme.colorScheme.secondaryContainer,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt(cost.toDouble()),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: canAfford ? 1.0 : 0.5,
                    child: FilledButton(
                      onPressed: _onBuy,
                      child: Text(s.buyButton),
                    )
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
