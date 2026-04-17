import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/game_state.dart';

/// Offline progress — açılışta now − meta.lastSavedAt delta üzerinden
/// pasif kazanç. Production.tickDelta ile ortak formül.
/// Spec: docs/economy.md §3.4, design §3.7
class OfflineProgress {
  const OfflineProgress._();

  /// A: 24 saat cap — shock-value snackbar'ı engeller.
  /// B'de Duration(hours: 12). Tek satır const değişim.
  static const Duration _kOfflineCap = Duration(hours: 24);

  static OfflineReport compute(GameState state, DateTime now) {
    final last = DateTime.parse(state.meta.lastSavedAt);
    final rawElapsed = now.difference(last);
    final capped = rawElapsed > _kOfflineCap;
    final effective = capped ? _kOfflineCap : rawElapsed;
    final earned = Production.tickDelta(
      state.buildings.owned,
      effective.inMicroseconds / 1e6,
    );
    return OfflineReport(
      earned: earned,
      elapsed: rawElapsed,
      capped: capped,
    );
  }
}
