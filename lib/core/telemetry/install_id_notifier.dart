import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Install ID'nin tek kaynağı (SharedPreferences).
/// Boot: ensureLoaded() → adoptFromGameState(gs.meta.installId) (disk wins).
/// Telemetry payload için:
///   `resolveInstallIdForTelemetry(ref.read(installIdProvider))`
/// şeklinde çağır — null ise `<not-loaded>` sentinel döner (invariant I1).
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
/// Maps a raw install_id value (from `Ref.read(installIdProvider)`,
/// `WidgetRef.read(installIdProvider)`, or
/// `ProviderContainer.read(installIdProvider)`)
/// to either the loaded String or the `<not-loaded>` sentinel.
///
/// Caller is responsible for the `.read()` — this keeps the helper
/// compatible with all three Riverpod 3.1 read contexts.
///
/// Integration test: if this sentinel appears in production emission,
/// test fails (invariant I1).
String resolveInstallIdForTelemetry(String? rawValue) {
  return rawValue ?? InstallIdNotifier.kNotLoadedSentinel;
}
