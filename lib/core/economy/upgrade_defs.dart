import 'package:crumbs/core/economy/effect.dart';

/// Upgrade catalog — sabit tablo lookup'ları.
///
/// Spec: docs/upgrade-catalog.md §1 — B1'de sadece golden_recipe_i.
class UpgradeDefs {
  const UpgradeDefs._();

  /// Tablo-içi id için gerçek Effect; tanımsız id için no-op sentinel
  /// (globalMultiplier * 1).
  ///
  /// **Defensive contract:** GameStateNotifier.buyUpgrade(id) `exists(id)` ile
  /// gate eder; MultiplierChain da `exists()` kontrolü yapar. Tanımsız id
  /// Map&lt;String, bool&gt; owned'a normal yoldan giremez; bu dönüş yalnız
  /// malformed save data veya gelecek migration hatalarına karşı savunma.
  /// Yeni upgrade eklendiğinde switch'e entry eklenmesi ZORUNLU.
  static Effect effectFor(String id) => switch (id) {
        'golden_recipe_i' =>
          const Effect(type: EffectType.globalMultiplier, value: 1.5),
        _ => const Effect(type: EffectType.globalMultiplier, value: 1),
      };

  static num baseCostFor(String id) => switch (id) {
        'golden_recipe_i' => 200,
        _ => 0,
      };

  static bool exists(String id) => switch (id) {
        'golden_recipe_i' => true,
        _ => false,
      };
}
