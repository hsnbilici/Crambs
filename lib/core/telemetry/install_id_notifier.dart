import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Install ID'nin tek kaynağı (SharedPreferences).
/// Boot: ensureLoaded() → adoptFromGameState(gs.meta.installId) (disk wins).
/// Telemetry payload için `resolveInstallIdForTelemetry(ref)` kullan —
/// null ise `<not-loaded>` sentinel döner (invariant guard).
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKey = 'crumbs.install_id';
  static const kNotLoadedSentinel = '<not-loaded>';

  @override
  String? build() => null;

  /// Boot sırasında, GameState hydrate'den ÖNCE çağrılır.
  /// State SharedPreferences'taki değerle (veya null ile) doldurulur.
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey);
  }

  /// Boot sırasında, GameState hydrate sonrası çağrılır.
  /// Disk-wins: GameState.meta.installId her zaman authoritative;
  /// disk farklıysa overwrite edilir.
  Future<void> adoptFromGameState(String savedInstallId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKey);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKey, savedInstallId);
    }
    state = savedInstallId;
  }
}

final installIdProvider =
    NotifierProvider<InstallIdNotifier, String?>(InstallIdNotifier.new);

/// Telemetry invariant guard.
/// Returns install_id veya `<not-loaded>` sentinel.
/// Integration test bu sentinel'ı production emission'da görürse fail eder.
///
/// Hem [ProviderContainer] (test/boot) hem de production context'te
/// `container.read(installIdProvider)` aynı API'yı kullanır.
String resolveInstallIdForTelemetry(ProviderContainer container) {
  return container.read(installIdProvider) ??
      InstallIdNotifier.kNotLoadedSentinel;
}
