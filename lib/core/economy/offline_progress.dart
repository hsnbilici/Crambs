import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/game_state.dart';

/// Offline progress — açılışta now − meta.lastSavedAt delta üzerinden
/// pasif kazanç. Production.tickDelta ile ortak formül.
/// Spec: docs/economy.md §3.4, design §3.7
class OfflineProgress {
  const OfflineProgress._();

  /// B1'den itibaren 12 saat cap — shock-value snackbar'ı engeller.
  /// A'da 24h idi; B1'de economy playtest kararı ile 12h'a indirildi
  /// (spec §1.1 in-scope). Public for Session Recap modal UI (B6 —
  /// UI/economy drift önlemi).
  static const Duration kOfflineCap = Duration(hours: 12);

  static OfflineReport compute(
    GameState state,
    DateTime now, {
    double globalMultiplier = 1.0,
  }) {
    final last = DateTime.parse(state.meta.lastSavedAt);
    final rawElapsed = now.difference(last);
    final capped = rawElapsed > kOfflineCap;
    final effective = capped ? kOfflineCap : rawElapsed;
    final earned = Production.tickDelta(
      state.buildings.owned,
      effective.inMicroseconds / 1e6,
      globalMultiplier: globalMultiplier,
    );
    return OfflineReport(
      earned: earned,
      elapsed: rawElapsed,
      capped: capped,
    );
  }
}
