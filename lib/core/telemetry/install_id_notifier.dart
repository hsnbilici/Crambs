import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Install ID'nin tek kaynağı (SharedPreferences).
/// Boot: ensureLoaded() → adoptFromGameState(gs.meta.installId)
/// (GameState-wins: GameState'teki değer authoritative, disk farklıysa
/// overwrite edilir).
/// Telemetry payload için:
///   `resolveInstallIdForTelemetry(ref.read(installIdProvider))`
/// şeklinde çağır — null ise `<not-loaded>` sentinel döner (invariant I1).
///
/// B3 genişlemesi: `_createdAt` (SharedPreferences-backed, device-local) +
/// `installIdAgeMs` getter. SessionStart payload `install_id_age_ms` için
/// kullanılır (invariant I15).
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKeyId = 'crumbs.install_id';
  static const _prefKeyCreatedAt = 'crumbs.install_created_at';
  static const kNotLoadedSentinel = '<not-loaded>';
  static const int kAgeNotLoaded = -1;

  DateTime? _createdAt;

  @override
  String? build() => null;

  /// Install creation timestamp — device-local (SharedPreferences).
  /// Cross-device save restore'da bu device'ın ilk boot'unda yazılır.
  /// [ensureLoaded] sonrası güvenilir.
  DateTime? get installCreatedAt => _createdAt;

  /// `_createdAt`'den `DateTime.now()`'a ms. Pre-ensureLoaded: [kAgeNotLoaded]
  /// (-1). Clock-backward (user cihaz saatini geri aldı) → 0 clamp (negative
  /// dashboard aggregation'ı kirletir).
  int get installIdAgeMs {
    final c = _createdAt;
    if (c == null) return kAgeNotLoaded;
    final diff = DateTime.now().difference(c).inMilliseconds;
    return diff < 0 ? 0 : diff;
  }

  /// Boot sırasında, GameState hydrate'den ÖNCE çağrılır.
  /// State SharedPreferences'taki değerle (veya null ile) doldurulur.
  /// `_createdAt` pref yüklenir; yoksa now yazılır; parse fail'de corruption
  /// debugPrint + reset to now.
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKeyId);

    final createdAtStr = prefs.getString(_prefKeyCreatedAt);
    if (createdAtStr != null) {
      _createdAt = DateTime.tryParse(createdAtStr);
      if (_createdAt == null) {
        debugPrint(
          '[InstallIdNotifier] install_created_at parse failed '
          '(value: "$createdAtStr") — resetting to now. '
          'Install appears new in telemetry.',
        );
      }
    }
    if (_createdAt == null) {
      _createdAt = DateTime.now();
      await prefs.setString(
        _prefKeyCreatedAt,
        _createdAt!.toIso8601String(),
      );
    }
  }

  /// Boot sırasında, GameState hydrate sonrası çağrılır.
  /// GameState-wins: GameState.meta.installId her zaman authoritative;
  /// disk farklıysa disk'teki değer overwrite edilir.
  Future<void> adoptFromGameState(String savedInstallId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKeyId);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKeyId, savedInstallId);
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
