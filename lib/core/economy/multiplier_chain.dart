import 'package:crumbs/core/economy/effect.dart';
import 'package:crumbs/core/economy/upgrade_defs.dart';

/// Tüm çarpan kaynakları tek noktada toplanır (CLAUDE.md §6/6, economy.md §6).
///
/// B1'de yalnız `globalMultiplier` katmanı implemented; diğerleri
/// (buildingSpecific, event, research, prestige) YAGNI — gerektiğinde
/// method eklenir, Production imzası kırılmaz (named param pattern).
class MultiplierChain {
  const MultiplierChain._();

  /// Global upgrade multiplier — satın alınmış upgrade'lerin
  /// `EffectType.globalMultiplier` tipindeki etkilerini multiplicative çarpar.
  ///
  /// **Convention (B1 invariant):** `owned` map YALNIZCA true entry'leri tutar
  /// (buyUpgrade `id: true` yazar). `false` veya `unset` semantik olarak denk —
  /// "satın alınmamış" anlamına gelir. Defensive branch'ler (isOwned=false,
  /// unknown id) malformed save data veya gelecek migration hatalarına karşı
  /// savunmadır; production path'te tetiklenmez.
  static double globalMultiplier(Map<String, bool> owned) {
    var multiplier = 1.0;
    owned.forEach((id, isOwned) {
      if (!isOwned) return;
      if (!UpgradeDefs.exists(id)) return;
      final effect = UpgradeDefs.effectFor(id);
      if (effect.type == EffectType.globalMultiplier) {
        multiplier *= effect.value;
      }
    });
    return multiplier;
  }
}
