# Sprint B1 — Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sprint A'nın vertical slice'ını genişlet — 3 bina (crumb_collector düzeltilmiş + oven + bakery_line), ilk upgrade sistemi (Golden Recipe I), typed SaveEnvelope + v1→v2 migration, 12h offline cap, Upgrades nav slotu aktif, AsyncError friendly screen.

**Architecture:** Effect-typed upgrade system + pure MultiplierChain function (Map<String, bool> owned → double) — upgrade ID'lerine Production katmanı dokunmaz, sadece `globalMultiplier` named param alır. Typed SaveEnvelope raw-first migration (v1 Map → putIfAbsent('upgrades') → GameState.fromJson → v2 typed envelope); checksum migration sonrası yeniden hesaplanır. Sprint A'nın 5 kritik invariant'ı korunur + 6 yeni invariant (chain enjeksiyonu 3 site, upgrade preserve across resume, migration idempotency, vb).

**Tech Stack:** Flutter 3.41.5, Dart 3.11, Riverpod 3.1, freezed 3.0 + json_serializable, crypto 3.0 (SHA-256), meta (@visibleForTesting), go_router 17.2, flutter_animate 4.5 (Sprint A'dan miras).

**Referans:** `docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md` (tasarım kararları + 5 review findings applied).

---

## Önkoşullar (plan öncesi)

- **Sprint A bitti:** PR #2 (`sprint/a-vertical-slice`) merge edilmiş OLMALI. Merge edilmeden önce plan başlatılırsa bu plan `main` yerine `sprint/a-vertical-slice` tip'inden branch alır.
- Flutter 3.41.5 FVM ile: `flutter --version` ile teyit et (pinli değerin dışındaysa `fvm use 3.41.5`).
- `flutter analyze` temiz, `flutter test` tümü yeşil (Sprint A sonrası 84 test geçmeli).
- Yeni branch: `sprint/b1-expansion`.

```bash
git checkout main
git pull origin main
git checkout -b sprint/b1-expansion
flutter pub get
flutter test  # 84 pass baseline
flutter analyze  # 0 issue baseline
```

---

## Dependency Chain

```
#1,#2 ─► #3 ─► #4 ─► #5 ─► #6 ─► #11 ─► {#12, #18} paralel
                                  ▲
                   #7 ─► #8 ─► #9 ─► #10 ─────┘
UI layer (paralel, #11 sonrası):  #14 → #15 → #16 → #17 → #19
Non-blocking:                      #13 (herhangi bir noktada)
```

**Sırayla execute:** S-strict task'lar (#1, #3, #4, #5, #8, #9, #10, #11, #18) TDD disiplini ile subagent-driven. Controller-direct task'lar (#12-17, #19) kontrolcü tarafından uygulanır; review hafif.

---

## Task 1: Economy.md senkronizasyonu (Production data + buildings)

**Amaç:** `Production.baseCostFor`/`growthFor`/`baseProductionFor` switch'lerini `docs/economy.md §4` tablosuyla hizala — crumb_collector 15/1.12'ye düzeltilir, oven + bakery_line eklenir.

**Files:**
- Modify: `lib/core/economy/production.dart`
- Modify: `test/core/economy/production_test.dart`

- [ ] **Step 1: Test — economy §4 tablosu assertion**

Mevcut `test/core/economy/production_test.dart` dosyasını aç, `group('BuildingDefs lookups', ...)` veya benzeri bölümüne şu test'leri ekle (üç bina × üç metrik + unknown fallback = 10 assert):

```dart
group('Production — economy.md §4 table values', () {
  test('crumb_collector matches economy §4', () {
    expect(Production.baseProductionFor('crumb_collector'), 0.1);
    expect(Production.baseCostFor('crumb_collector'), 15);
    expect(Production.growthFor('crumb_collector'), 1.12);
  });

  test('oven matches economy §4', () {
    expect(Production.baseProductionFor('oven'), 1.0);
    expect(Production.baseCostFor('oven'), 120);
    expect(Production.growthFor('oven'), 1.12);
  });

  test('bakery_line matches economy §4', () {
    expect(Production.baseProductionFor('bakery_line'), 8.0);
    expect(Production.baseCostFor('bakery_line'), 1200);
    expect(Production.growthFor('bakery_line'), 1.13);
  });

  test('unknown building defensive fallback', () {
    expect(Production.baseProductionFor('unknown'), 0);
    expect(Production.baseCostFor('unknown'), 0);
    expect(Production.growthFor('unknown'), 1);
  });
});
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/production_test.dart`
Expected: FAIL — oven + bakery_line switch entries yok, crumb_collector değerleri eski (10/1.15).

- [ ] **Step 3: Implementation — Production switch tabloları**

`lib/core/economy/production.dart` içinde:

```dart
static double baseProductionFor(String buildingId) => switch (buildingId) {
      'crumb_collector' => 0.1,
      'oven' => 1.0,
      'bakery_line' => 8.0,
      _ => 0,
    };

static num baseCostFor(String buildingId) => switch (buildingId) {
      'crumb_collector' => 15,
      'oven' => 120,
      'bakery_line' => 1200,
      _ => 0,
    };

static double growthFor(String buildingId) => switch (buildingId) {
      'crumb_collector' => 1.12,
      'oven' => 1.12,
      'bakery_line' => 1.13,
      _ => 1,
    };
```

- [ ] **Step 4: Verify Sprint A cost_curve test'lerini kır/düzelt**

Run: `flutter test test/core/economy/`
Expected: Muhtemelen `test/core/economy/cost_curve_test.dart` veya existing production test'te `costFor(10, 1.15, 1) == 11` gibi assertion'lar kırılır (eski değerler). Bu test'leri **yeni değerlere göre güncelle**:
- `CostCurve.costFor(15, 1.12, 0) == 15`
- `CostCurve.costFor(15, 1.12, 1) == 16` (15×1.12 = 16.8 → floor 16)
- `CostCurve.costFor(15, 1.12, 2) == 18` (15×1.12² ≈ 18.816 → floor 18)

Ayrıca `test/core/state/providers_test.dart`'ta `costCurveProvider(('crumb_collector', 0)) == 10` gibi assertion varsa 15'e güncelle.

Hızlıca ara: `grep -rn "1\.15\b\|, 10)\|'crumb_collector'" test/` ile olası call-site'ları tara.

- [ ] **Step 5: Run — pass**

Run: `flutter test test/core/economy/ test/core/state/`
Expected: Tüm testler geçer.

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/economy/production.dart test/core/economy/ test/core/state/
git commit -m "sprint-b1(T1): sync Production data with economy.md §4 — oven + bakery_line + collector 15/1.12"
```

---

## Task 2: Effect class + EffectType enum

**Amaç:** Upgrade effect modelini kur — tek tip (`globalMultiplier`), gelecek tip'ler için extensible enum.

**Files:**
- Create: `lib/core/economy/effect.dart`
- Create: `test/core/economy/effect_test.dart`

- [ ] **Step 1: Test**

Write `test/core/economy/effect_test.dart`:

```dart
import 'package:crumbs/core/economy/effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Effect', () {
    test('equality by type + value', () {
      const a = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const b = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const c = Effect(type: EffectType.globalMultiplier, value: 2.0);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashCode matches equality', () {
      const a = Effect(type: EffectType.globalMultiplier, value: 1.5);
      const b = Effect(type: EffectType.globalMultiplier, value: 1.5);
      expect(a.hashCode, b.hashCode);
    });

    test('EffectType enum has globalMultiplier', () {
      expect(EffectType.values, contains(EffectType.globalMultiplier));
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/effect_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation**

Write `lib/core/economy/effect.dart`:

```dart
/// Upgrade etki tipleri (economy.md §6 çarpan katmanları).
/// B1'de sadece globalMultiplier implemented; B2/C'de
/// buildingSpecific, event, research, prestige, costReduction eklenir.
enum EffectType { globalMultiplier }

/// Upgrade etkisi — tip + değer.
///
/// Düz const class; freezed değil — fromJson gerekmez (catalog sabit).
class Effect {
  const Effect({required this.type, required this.value});

  final EffectType type;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is Effect && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/effect_test.dart`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/effect.dart test/core/economy/effect_test.dart
git commit -m "sprint-b1(T2): Effect + EffectType — upgrade effect model (globalMultiplier only)"
```

---

## Task 3: UpgradeDefs catalog

**Amaç:** Upgrade tablo lookup'ları — `effectFor`, `baseCostFor`, `exists`. B1'de sadece `golden_recipe_i` (×1.5 global, 200 C).

**Files:**
- Create: `lib/core/economy/upgrade_defs.dart`
- Create: `test/core/economy/upgrade_defs_test.dart`

- [ ] **Step 1: Test**

Write `test/core/economy/upgrade_defs_test.dart`:

```dart
import 'package:crumbs/core/economy/effect.dart';
import 'package:crumbs/core/economy/upgrade_defs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpgradeDefs', () {
    test('effectFor(golden_recipe_i) → globalMultiplier ×1.5', () {
      expect(
        UpgradeDefs.effectFor('golden_recipe_i'),
        const Effect(type: EffectType.globalMultiplier, value: 1.5),
      );
    });

    test('effectFor(unknown) → no-op sentinel (globalMultiplier ×1.0)', () {
      expect(
        UpgradeDefs.effectFor('unknown'),
        const Effect(type: EffectType.globalMultiplier, value: 1.0),
      );
    });

    test('baseCostFor(golden_recipe_i) → 200', () {
      expect(UpgradeDefs.baseCostFor('golden_recipe_i'), 200);
    });

    test('baseCostFor(unknown) → 0', () {
      expect(UpgradeDefs.baseCostFor('unknown'), 0);
    });

    test('exists(golden_recipe_i) → true', () {
      expect(UpgradeDefs.exists('golden_recipe_i'), isTrue);
    });

    test('exists(unknown) → false', () {
      expect(UpgradeDefs.exists('random_id'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/upgrade_defs_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation**

Write `lib/core/economy/upgrade_defs.dart`:

```dart
import 'package:crumbs/core/economy/effect.dart';

/// Upgrade catalog — sabit tablo lookup'ları.
///
/// Spec: docs/upgrade-catalog.md §1 — B1'de sadece golden_recipe_i.
class UpgradeDefs {
  const UpgradeDefs._();

  /// Tablo-içi id için gerçek Effect; tanımsız id için no-op sentinel
  /// (globalMultiplier × 1.0).
  ///
  /// **Defensive contract:** GameStateNotifier.buyUpgrade(id) `exists(id)` ile
  /// gate eder; MultiplierChain da `exists()` kontrolü yapar. Tanımsız id
  /// Map<String, bool> owned'a normal yoldan giremez; bu dönüş yalnız
  /// malformed save data veya gelecek migration hatalarına karşı savunma.
  /// Yeni upgrade eklendiğinde switch'e entry eklenmesi ZORUNLU.
  static Effect effectFor(String id) => switch (id) {
        'golden_recipe_i' =>
          const Effect(type: EffectType.globalMultiplier, value: 1.5),
        _ => const Effect(type: EffectType.globalMultiplier, value: 1.0),
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
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/upgrade_defs_test.dart`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/upgrade_defs.dart test/core/economy/upgrade_defs_test.dart
git commit -m "sprint-b1(T3): UpgradeDefs catalog — golden_recipe_i + no-op fallback"
```

---

## Task 4: MultiplierChain.globalMultiplier

**Amaç:** Pure function, satın alınmış upgrade'leri gezerek `globalMultiplier` type'ındaki effect value'larını multiplicative çarp.

**Files:**
- Modify: `lib/core/economy/multiplier_chain.dart`
- Create: `test/core/economy/multiplier_chain_test.dart`

- [ ] **Step 1: Test**

Write `test/core/economy/multiplier_chain_test.dart`:

```dart
import 'package:crumbs/core/economy/multiplier_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiplierChain.globalMultiplier', () {
    test('empty owned map → 1.0', () {
      expect(MultiplierChain.globalMultiplier({}), 1.0);
    });

    test('single owned golden_recipe_i → 1.5', () {
      expect(
        MultiplierChain.globalMultiplier({'golden_recipe_i': true}),
        closeTo(1.5, 1e-12),
      );
    });

    test('owned=false entry → ignored (defensive)', () {
      expect(
        MultiplierChain.globalMultiplier({'golden_recipe_i': false}),
        1.0,
      );
    });

    test('unknown id → defensive skip, 1.0', () {
      expect(
        MultiplierChain.globalMultiplier({'ghost_upgrade': true}),
        1.0,
      );
    });

    test('mixed known + unknown + false → only valid true multiplied', () {
      expect(
        MultiplierChain.globalMultiplier({
          'golden_recipe_i': true,
          'ghost': true,
          'falsey': false,
        }),
        closeTo(1.5, 1e-12),
      );
    });

    test('hypothetical multi-upgrade multiplicative (B2+ forward-compat)', () {
      // B1'de tek upgrade var; bu test gelecek ×1.5 × ×2.0 = ×3.0 davranışı
      // golden_recipe_i'yi iki kez farklı id ile simüle edemez ama
      // golden_recipe_i × 1.0-fallback → hâlâ 1.5 kalmalı.
      expect(
        MultiplierChain.globalMultiplier({
          'golden_recipe_i': true,
          'not_yet_defined_but_future': true,
        }),
        closeTo(1.5, 1e-12),
      );
    });

    test('determinism — same input same output', () {
      final input = {'golden_recipe_i': true};
      final a = MultiplierChain.globalMultiplier(input);
      final b = MultiplierChain.globalMultiplier(input);
      expect(a, b);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/multiplier_chain_test.dart`
Expected: FAIL — MultiplierChain.globalMultiplier method yok (stub class boş).

- [ ] **Step 3: Implementation**

Replace `lib/core/economy/multiplier_chain.dart`:

```dart
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
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/multiplier_chain_test.dart`
Expected: 7/7 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/multiplier_chain.dart test/core/economy/multiplier_chain_test.dart
git commit -m "sprint-b1(T4): MultiplierChain.globalMultiplier — pure fn over Map<String, bool> owned"
```

---

## Task 5: Production refactor — globalMultiplier param enjeksiyonu

**Amaç:** `Production.totalPerSecond` ve `Production.tickDelta` named param `globalMultiplier` (default 1.0) alır. Hardcoded upgrade referansı YOK; chain dışarıdan enjekte edilir.

**Files:**
- Modify: `lib/core/economy/production.dart`
- Modify: `test/core/economy/production_test.dart`

- [ ] **Step 1: Test — globalMultiplier scaling**

`test/core/economy/production_test.dart` içinde yeni group ekle:

```dart
group('Production — globalMultiplier injection', () {
  test('totalPerSecond default multiplier = 1.0 (backward-compat)', () {
    expect(Production.totalPerSecond({'crumb_collector': 1}), 0.1);
  });

  test('totalPerSecond with globalMultiplier: 1.5 → scaled', () {
    expect(
      Production.totalPerSecond(
        {'crumb_collector': 1},
        globalMultiplier: 1.5,
      ),
      closeTo(0.15, 1e-12),
    );
  });

  test('tickDelta with globalMultiplier → delta scales', () {
    expect(
      Production.tickDelta(
        {'oven': 2}, 10.0,
        globalMultiplier: 1.5,
      ),
      closeTo(30.0, 1e-9),  // 2 × 1.0 × 1.5 × 10 = 30
    );
  });

  test('tickDelta zero buildings → 0 regardless of multiplier', () {
    expect(
      Production.tickDelta({}, 10.0, globalMultiplier: 2.0),
      0.0,
    );
  });
});
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/production_test.dart`
Expected: FAIL — `globalMultiplier` parametresi bilinmiyor (no named param).

- [ ] **Step 3: Implementation — named param**

`lib/core/economy/production.dart` içinde `totalPerSecond` + `tickDelta`:

```dart
/// Toplam üretim hızı (C/s). Multipliers chain dışarıdan enjekte edilir —
/// Production upgrade ID'lerine erişmez (CLAUDE.md §6/6).
static double totalPerSecond(
  Map<String, int> buildings, {
  double globalMultiplier = 1.0,
}) {
  var total = 0.0;
  buildings.forEach((id, owned) {
    total += owned * baseProductionFor(id);
  });
  return total * globalMultiplier;
}

/// Tick veya offline delta. seconds = wall-clock elapsed.
/// Tek code path — online tick + cold hydrate + hot resume ortak formül.
static double tickDelta(
  Map<String, int> buildings,
  double seconds, {
  double globalMultiplier = 1.0,
}) =>
    totalPerSecond(buildings, globalMultiplier: globalMultiplier) * seconds;
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/production_test.dart`
Expected: Tüm yeni test'ler + mevcut test'ler geçer (default 1.0 backward-compat).

- [ ] **Step 5: Full suite**

Run: `flutter test`
Expected: All tests pass — Sprint A'nın call-site'ları (game_state_notifier, offline_progress) hâlâ imzanın default'unu kullanıyor, kırılmaz.

- [ ] **Step 6: Commit**

```bash
git add lib/core/economy/production.dart test/core/economy/production_test.dart
git commit -m "sprint-b1(T5): Production.totalPerSecond + tickDelta — globalMultiplier named param"
```

---

## Task 6: OfflineProgress refactor — globalMultiplier param

**Amaç:** `OfflineProgress.compute` da `globalMultiplier` named param alır, internal'de `Production.tickDelta`'ya geçirir.

**Files:**
- Modify: `lib/core/economy/offline_progress.dart`
- Modify: `test/core/economy/offline_progress_test.dart`

- [ ] **Step 1: Test — globalMultiplier forwarding**

`test/core/economy/offline_progress_test.dart` içinde yeni test'ler ekle:

```dart
group('OfflineProgress — globalMultiplier forwarding', () {
  test('default multiplier = 1.0 (backward-compat)', () {
    final report = OfflineProgress.compute(
      buildings: {'crumb_collector': 10},
      elapsed: const Duration(seconds: 10),
    );
    expect(report.earned, closeTo(10.0, 1e-9));  // 10 × 0.1 × 10 = 10
  });

  test('multiplier 1.5 scales earned', () {
    final report = OfflineProgress.compute(
      buildings: {'crumb_collector': 10},
      elapsed: const Duration(seconds: 10),
      globalMultiplier: 1.5,
    );
    expect(report.earned, closeTo(15.0, 1e-9));  // 10 × 0.1 × 1.5 × 10 = 15
  });

  test('12h cap honored (§8 B1 cap change)', () {
    // Task #13'te cap 12h'a değişir; bu test şimdilik mevcut cap ile çalışır.
    // Task #13 tamamlandıktan sonra 12h olacak.
    final report = OfflineProgress.compute(
      buildings: {'crumb_collector': 1},
      elapsed: const Duration(hours: 24),  // > cap
    );
    // Cap'in altında kalsın; exact değer Task #13 sonrası 12h = 43200s olacak.
    expect(report.rawElapsed.inHours, 24);
    expect(report.cappedElapsed.inHours, lessThanOrEqualTo(24));
  });
});
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/offline_progress_test.dart`
Expected: FAIL — `globalMultiplier` named param bilinmiyor.

- [ ] **Step 3: Implementation**

`lib/core/economy/offline_progress.dart`'ta `compute` metoduna named param ekle. Mevcut imza:

```dart
static OfflineReport compute({
  required Map<String, int> buildings,
  required Duration elapsed,
});
```

→

```dart
static OfflineReport compute({
  required Map<String, int> buildings,
  required Duration elapsed,
  double globalMultiplier = 1.0,
}) {
  final cappedElapsed = elapsed > _kOfflineCap ? _kOfflineCap : elapsed;
  final seconds = cappedElapsed.inMilliseconds / 1000.0;
  final earned = Production.tickDelta(
    buildings,
    seconds,
    globalMultiplier: globalMultiplier,
  );
  return OfflineReport(
    earned: earned,
    rawElapsed: elapsed,
    cappedElapsed: cappedElapsed,
  );
}
```

(Mevcut `earned` hesaplama muhtemelen `Production.tickDelta(buildings, seconds)` kullanıyor; imzaya `globalMultiplier:` ekle.)

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/offline_progress_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/offline_progress.dart test/core/economy/offline_progress_test.dart
git commit -m "sprint-b1(T6): OfflineProgress.compute — globalMultiplier forwarding"
```

---

## Task 7: UpgradeState freezed class

**Amaç:** `UpgradeState` — `Map<String, bool> owned` tutan freezed 3 immutable state.

**Files:**
- Create: `lib/core/save/upgrade_state.dart`
- Create: `test/core/save/upgrade_state_test.dart`

- [ ] **Step 1: Test**

Write `test/core/save/upgrade_state_test.dart`:

```dart
import 'package:crumbs/core/save/upgrade_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpgradeState', () {
    test('default construct — empty owned map', () {
      const state = UpgradeState();
      expect(state.owned, <String, bool>{});
    });

    test('copyWith preserves + updates', () {
      const a = UpgradeState(owned: {'a': true});
      final b = a.copyWith(owned: {'a': true, 'b': true});
      expect(b.owned, {'a': true, 'b': true});
      expect(a.owned, {'a': true});  // original immutable
    });

    test('fromJson(toJson(x)) roundtrip', () {
      const original = UpgradeState(owned: {'golden_recipe_i': true});
      final json = original.toJson();
      final restored = UpgradeState.fromJson(json);
      expect(restored, original);
    });

    test('fromJson with missing owned → default empty', () {
      // freezed @Default davranışı: fromJson({}) → default değer
      final restored = UpgradeState.fromJson(const <String, dynamic>{});
      expect(restored.owned, <String, bool>{});
    });

    test('fromJson tolerates owned=false entries (defensive)', () {
      final restored = UpgradeState.fromJson(const {
        'owned': {'a': true, 'b': false},
      });
      expect(restored.owned, {'a': true, 'b': false});
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/save/upgrade_state_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation**

Write `lib/core/save/upgrade_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'upgrade_state.freezed.dart';
part 'upgrade_state.g.dart';

/// Satın alınmış upgrade'ler.
///
/// **Convention (B1):** `owned` YALNIZCA true entry'leri tutar. buyUpgrade
/// `id: true` yazar; false durumu production flow'unda oluşmaz. fromJson
/// tarihî/malformed veri için tolere eder.
///
/// Spec: docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.1
@freezed
abstract class UpgradeState with _$UpgradeState {
  const factory UpgradeState({
    @Default(<String, bool>{}) Map<String, bool> owned,
  }) = _UpgradeState;

  factory UpgradeState.fromJson(Map<String, dynamic> json) =>
      _$UpgradeStateFromJson(json);
}
```

- [ ] **Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `upgrade_state.freezed.dart` + `upgrade_state.g.dart` üretilir.

- [ ] **Step 5: Run — pass**

Run: `flutter test test/core/save/upgrade_state_test.dart`
Expected: 5/5 pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/save/upgrade_state.dart lib/core/save/upgrade_state.freezed.dart lib/core/save/upgrade_state.g.dart test/core/save/upgrade_state_test.dart
git commit -m "sprint-b1(T7): UpgradeState freezed — owned: Map<String, bool>"
```

---

## Task 8: GameState.upgrades field (critical)

**Amaç:** GameState'e `upgrades: UpgradeState` field eklenir; freezed regen; copyWith + roundtrip test'leri genişletilir.

**Files:**
- Modify: `lib/core/save/game_state.dart`
- Modify: `test/core/save/game_state_test.dart`

- [ ] **Step 1: Test — GameState.upgrades default + preserve**

`test/core/save/game_state_test.dart` içine ekle:

```dart
group('GameState — upgrades field', () {
  test('initial() has empty UpgradeState', () {
    final gs = GameState.initial();
    expect(gs.upgrades, const UpgradeState());
    expect(gs.upgrades.owned, isEmpty);
  });

  test('copyWith preserves upgrades when other field changes', () {
    final gs = GameState.initial().copyWith(
      upgrades: const UpgradeState(owned: {'golden_recipe_i': true}),
    );
    final updated = gs.copyWith(
      inventory: gs.inventory.copyWith(r1Crumbs: 100),
    );
    expect(updated.upgrades.owned, {'golden_recipe_i': true});
  });

  test('fromJson(toJson(x)) roundtrip with upgrades', () {
    final original = GameState.initial().copyWith(
      upgrades: const UpgradeState(owned: {'golden_recipe_i': true}),
    );
    final json = original.toJson();
    final restored = GameState.fromJson(json);
    expect(restored.upgrades.owned, {'golden_recipe_i': true});
    expect(restored, original);
  });
});
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/save/game_state_test.dart`
Expected: FAIL — GameState'te upgrades field yok.

- [ ] **Step 3: Implementation — GameState'e field ekle**

`lib/core/save/game_state.dart` dosyasını aç. Mevcut `@freezed abstract class GameState` constructor'ına `upgrades` alanı ekle:

```dart
import 'package:crumbs/core/save/upgrade_state.dart';
// ... existing imports

@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    required MetaState meta,
    required RunState run,
    required InventoryState inventory,
    required BuildingState buildings,
    @Default(UpgradeState()) UpgradeState upgrades,   // ← YENİ
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);

  // ... existing factory initial() vs
}
```

`initial()` factory'sinde explicit `upgrades: UpgradeState()` eklemeye gerek yok — `@Default(UpgradeState())` devreye girer. Ama açıkça yazmak gelişime uygun:

```dart
factory GameState.initial({required String installId}) => GameState(
      meta: MetaState(installId: installId),
      run: const RunState(),
      inventory: const InventoryState(),
      buildings: const BuildingState(),
      upgrades: const UpgradeState(),    // ← explicit for clarity
    );
```

- [ ] **Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `game_state.freezed.dart` + `.g.dart` regen; UpgradeState import'u resolve olur.

- [ ] **Step 5: Run — pass**

Run: `flutter test test/core/save/game_state_test.dart`
Expected: Tüm testler (yeni + mevcut roundtrip) pass.

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: 0 issue. (Eğer UpgradeState explicit yazdıysan ve redundant_argument_values fire ederse, @Default'a güven ve explicit'i kaldır.)

- [ ] **Step 7: Commit**

```bash
git add lib/core/save/game_state.dart lib/core/save/game_state.freezed.dart lib/core/save/game_state.g.dart test/core/save/game_state_test.dart
git commit -m "sprint-b1(T8): GameState.upgrades field — UpgradeState default empty"
```

---

## Task 9: SaveEnvelope typed + Checksum rewrite (critical)

**Amaç:** `SaveEnvelope.gameState: Map<String, dynamic>` → `gameState: GameState` typed field migration. `SaveRepository` içindeki 2 `Checksum.of(env.gameState)` call'u `Checksum.of(env.gameState.toJson())` olur.

**Files:**
- Modify: `lib/core/save/save_envelope.dart`
- Modify: `lib/core/save/save_repository.dart`
- Modify: `test/core/save/save_envelope_test.dart`
- Modify: `test/core/save/save_repository_test.dart`

- [ ] **Step 1: Test — typed envelope roundtrip**

`test/core/save/save_envelope_test.dart` dosyasını güncelle. Mevcut test'lerde `gameState: {'x': 1}` gibi map literal'lar varsa hepsi typed GameState'e geçer:

```dart
test('SaveEnvelope typed GameState roundtrip', () {
  final gs = GameState.initial(installId: 'test-id').copyWith(
    upgrades: const UpgradeState(owned: {'golden_recipe_i': true}),
  );
  final envelope = SaveEnvelope(
    version: 2,
    lastSavedAt: '2026-04-17T12:00:00.000',
    gameState: gs,
    checksum: 'dummy',
  );
  final json = envelope.toJson();
  final restored = SaveEnvelope.fromJson(json);
  expect(restored.gameState.upgrades.owned, {'golden_recipe_i': true});
  expect(restored.version, 2);
});
```

Mevcut test'ler (`sampleEnvelope({tag})` helper'ı kullanan) de GameState'e geçer; helper güncellenecek.

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/save/save_envelope_test.dart`
Expected: FAIL — `gameState: Map<String, dynamic>` kabul eden mevcut SaveEnvelope typed kabul etmiyor.

- [ ] **Step 3: Implementation — SaveEnvelope typed**

`lib/core/save/save_envelope.dart`:

```dart
import 'package:crumbs/core/save/game_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// Disk persistence şeması.
/// Spec: docs/save-format.md §1, docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.3
///
/// B1'den itibaren typed GameState. v1 disk formatı (Map<String, dynamic>)
/// SaveMigrator üzerinden raw parse edilir — bkz lib/core/save/migrations/v1_to_v2.dart.
@freezed
abstract class SaveEnvelope with _$SaveEnvelope {
  const factory SaveEnvelope({
    required int version,
    required String lastSavedAt,
    required GameState gameState,
    required String checksum,
  }) = _SaveEnvelope;

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) =>
      _$SaveEnvelopeFromJson(json);
}
```

- [ ] **Step 4: Run build_runner**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 5: SaveRepository Checksum call-site update**

`lib/core/save/save_repository.dart` içindeki iki `Checksum.of(env.gameState)` → `Checksum.of(env.gameState.toJson())`:

```dart
// save() metodunda — data jsonEncode için env.toJson() zaten üretiliyor.
// Çek: eğer `jsonEncode(envelope.toJson())` kullanılıyorsa, Checksum call-site nerede?
// Sprint A post-review commit'inde _tryRead'e çekişum verify eklenmişti:

// _tryRead içinde:
if (Checksum.of(envelope.gameState.toJson()) != envelope.checksum) {
  return const _ReadResult(existed: true);
}

// save() içinde envelope yazılmadan önce checksum zaten compute ediliyor;
// envelope parametre olarak geliyor ve caller doğru checksum'u setliyor.
// Burada bir değişim gerekmeyebilir — sadece _tryRead güncellenir.
```

Ayrıca `lib/core/state/game_state_notifier.dart` içinde `_persist(gs)` veya benzeri metot envelope oluşturup checksum hesaplarken `Checksum.of(env.gameState)` kullanıyor olabilir:

```dart
// game_state_notifier.dart _persist içinde muhtemelen:
final envelope = SaveEnvelope(
  version: _kCurrentSchemaVersion,
  lastSavedAt: DateTime.now().toIso8601String(),
  gameState: gs,                              // ← artık typed, toJson gerekmez
  checksum: Checksum.of(gs.toJson()),         // ← burada typed gs.toJson()
);
```

Tüm call-site'ları `grep -rn "Checksum.of" lib/` ile tara, her birini `gs.toJson()` veya `env.gameState.toJson()` yap.

- [ ] **Step 6: save_repository_test.dart — sampleEnvelope helper güncelle**

`test/core/save/save_repository_test.dart` içindeki helper:

```dart
SaveEnvelope sampleEnvelope({String tag = 'v'}) {
  final gs = GameState.initial(installId: 'test').copyWith(
    meta: GameState.initial(installId: 'test').meta
        .copyWith(installId: 'test-$tag'),  // tag'i identifiable yap
  );
  return SaveEnvelope(
    version: 2,
    lastSavedAt: '2026-04-17T12:00:00.000',
    gameState: gs,
    checksum: Checksum.of(gs.toJson()),
  );
}
```

Mevcut test'lerde `gameState['tag']` gibi map-indexing'ler vardı — artık `gameState.meta.installId` okurlar.

Byte-flip test'i (Sprint A post-review'dan miras) yine çalışır; yalnız tampered envelope construct ederken `{'tampered': true}` gibi raw map yerine geçici GameState + farklı checksum kullanılır:

```dart
test('checksum mismatch (valid JSON, wrong hash) → uses .bak', () async {
  await repo.save(sampleEnvelope(tag: 'bak'));
  await repo.save(sampleEnvelope(tag: 'main-orig'));
  final mainPath = '${tempDir.path}/crumbs_save.json';
  // Main dosyasına valid typed envelope ama yanlış checksum yaz
  final tamperedGs = GameState.initial(installId: 'tampered');
  File(mainPath).writeAsStringSync(
    jsonEncode({
      'version': 2,
      'lastSavedAt': '2026-04-17T12:00:00.000',
      'gameState': tamperedGs.toJson(),
      'checksum': 'deadbeef' * 8,  // 64 hex, not the real hash
    }),
  );
  final result = await repo.load();
  expect(result.envelope, isNotNull);
  expect(result.recovery, SaveRecoveryReason.checksumFailedUsedBackup);
  expect(result.envelope!.gameState.meta.installId, startsWith('test-bak'));
});
```

- [ ] **Step 7: Run — pass**

Run: `flutter test test/core/save/`
Expected: Tüm save test'ler pass (envelope, repository, checksum).

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: 0 issue. Muhtemelen `unused_import` uyarıları kalabilir; silinir.

- [ ] **Step 9: Commit**

```bash
git add lib/core/save/save_envelope.dart lib/core/save/save_envelope.freezed.dart lib/core/save/save_envelope.g.dart lib/core/save/save_repository.dart lib/core/state/game_state_notifier.dart test/core/save/
git commit -m "sprint-b1(T9): SaveEnvelope typed GameState + Checksum.of(env.gameState.toJson())"
```

---

## Task 10: SaveMigrator v1→v2 (critical)

**Amaç:** Raw-first migration. v1 disk Map (upgrades YOK) → raw `migrateV1ToV2GameState(raw)` (putIfAbsent) → v2 typed envelope. Idempotent. Disk'ten load edildikten sonra yeni v2 formatında re-save.

**Files:**
- Create: `lib/core/save/migrations/v1_to_v2.dart`
- Modify: `lib/core/save/save_migrator.dart`
- Modify: `lib/core/save/save_repository.dart` (raw-first load path)
- Create: `test/core/save/migrations/v1_to_v2_test.dart`
- Modify: `test/core/save/save_migrator_test.dart`
- Modify: `test/core/save/save_repository_test.dart`

- [ ] **Step 1: Test — v1_to_v2 raw map transformation**

Write `test/core/save/migrations/v1_to_v2_test.dart`:

```dart
import 'package:crumbs/core/save/migrations/v1_to_v2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migrateV1ToV2GameState', () {
    test('adds empty upgrades when missing', () {
      final v1 = {
        'meta': {'installId': 'abc'},
        'run': {},
        'inventory': {'r1Crumbs': 100},
        'buildings': {'owned': {}},
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['upgrades'], {'owned': <String, bool>{}});
      // Original untouched (immutability convention)
      expect(v1.containsKey('upgrades'), isFalse);
    });

    test('idempotent — existing upgrades preserved', () {
      final v1 = {
        'meta': {'installId': 'abc'},
        'upgrades': {
          'owned': {'golden_recipe_i': true},
        },
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['upgrades'], {
        'owned': {'golden_recipe_i': true},
      });
    });

    test('preserves other fields', () {
      final v1 = {
        'meta': {'installId': 'xyz'},
        'buildings': {'owned': {'crumb_collector': 5}},
      };
      final v2 = migrateV1ToV2GameState(v1);
      expect(v2['meta'], {'installId': 'xyz'});
      expect(v2['buildings'], {'owned': {'crumb_collector': 5}});
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/save/migrations/v1_to_v2_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation — v1_to_v2 raw migration**

Write `lib/core/save/migrations/v1_to_v2.dart`:

```dart
/// v1 → v2 GameState migration. Raw Map üzerinde çalışır, typed cast YOK.
///
/// **Kural (Spec §3.4):** Migration HER ZAMAN raw map üzerinde koşar,
/// `GameState.fromJson` migration SONRASI çağrılır. `@Default(UpgradeState())`
/// fallback davranışına güvenilmez — explicit putIfAbsent.
///
/// Idempotent: `upgrades` zaten varsa dokunulmaz.
Map<String, dynamic> migrateV1ToV2GameState(
  Map<String, dynamic> rawGameState,
) {
  final copy = Map<String, dynamic>.from(rawGameState);
  copy.putIfAbsent('upgrades', () => {'owned': <String, bool>{}});
  return copy;
}
```

- [ ] **Step 4: Run migration unit tests — pass**

Run: `flutter test test/core/save/migrations/v1_to_v2_test.dart`
Expected: 3/3 pass.

- [ ] **Step 5: Test — SaveMigrator wrapper integration**

`test/core/save/save_migrator_test.dart`:

```dart
test('migrate v1 rawEnvelope → v2 typed SaveEnvelope', () {
  final v1Raw = <String, dynamic>{
    'version': 1,
    'lastSavedAt': '2026-04-17T10:00:00.000',
    'gameState': {
      'meta': {'installId': 'legacy-user'},
      'run': {},
      'inventory': {'r1Crumbs': 500.0},
      'buildings': {'owned': {'crumb_collector': 3}},
    },
    'checksum': 'legacy-checksum',  // v1 checksum geçerli değil B1'de
  };
  final migrated = SaveMigrator.migrate(v1Raw, 2);
  expect(migrated.version, 2);
  expect(migrated.gameState.upgrades.owned, isEmpty);
  expect(migrated.gameState.meta.installId, 'legacy-user');
  expect(migrated.gameState.buildings.owned['crumb_collector'], 3);
});

test('migrate idempotent — v2 rawEnvelope returns same state', () {
  final v2Raw = <String, dynamic>{
    'version': 2,
    'lastSavedAt': '2026-04-17T10:00:00.000',
    'gameState': GameState.initial(installId: 'x').toJson(),
    'checksum': 'anything',
  };
  final migrated = SaveMigrator.migrate(v2Raw, 2);
  expect(migrated.version, 2);
});

test('migrate throws for unreachable version', () {
  final v99Raw = <String, dynamic>{
    'version': 99,
    'lastSavedAt': '2026-04-17T10:00:00.000',
    'gameState': {},
    'checksum': '',
  };
  expect(() => SaveMigrator.migrate(v99Raw, 2), throwsFormatException);
});
```

- [ ] **Step 6: Run — fail**

Run: `flutter test test/core/save/save_migrator_test.dart`
Expected: FAIL — SaveMigrator.migrate imzası raw Map kabul etmiyor / yeni davranış yok.

- [ ] **Step 7: Implementation — SaveMigrator refactor**

`lib/core/save/save_migrator.dart`:

```dart
import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/migrations/v1_to_v2.dart';
import 'package:crumbs/core/save/save_envelope.dart';

/// Migration orchestrator — raw Map'ten typed SaveEnvelope üretir.
///
/// Spec: docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.4
/// Spec: docs/save-format.md §5
class SaveMigrator {
  const SaveMigrator._();

  /// rawEnvelope: jsonDecode sonrası henüz typed yapılmamış Map.
  /// Returns: typed SaveEnvelope at targetVersion.
  /// Throws: [FormatException] if migration path yok.
  ///
  /// Migration sonrası checksum **yeniden hesaplanır** (v1'in checksum'ı
  /// migration sonrası payload'a geçersiz). Typed envelope yeni checksum ile.
  static SaveEnvelope migrate(
    Map<String, dynamic> rawEnvelope,
    int targetVersion,
  ) {
    var mutable = Map<String, dynamic>.from(rawEnvelope);
    var currentVersion = mutable['version'] as int;

    while (currentVersion < targetVersion) {
      if (currentVersion == 1) {
        final rawGs = mutable['gameState'] as Map<String, dynamic>;
        mutable['gameState'] = migrateV1ToV2GameState(rawGs);
        mutable['version'] = 2;
        currentVersion = 2;
      } else {
        throw FormatException(
          'No migration from v$currentVersion to v$targetVersion',
        );
      }
    }

    // Typed parse
    final parsed = SaveEnvelope.fromJson(mutable);

    // Checksum yeniden hesapla (migration sonrası payload yeni)
    return parsed.copyWith(
      checksum: Checksum.of(parsed.gameState.toJson()),
    );
  }
}
```

- [ ] **Step 8: Modify SaveRepository.load — raw-first path**

`lib/core/save/save_repository.dart` `_tryRead` ve `load` logic'ini güncelle. Mevcut akış:

```
_tryRead(file)
  → readAsString
  → jsonDecode → map
  → SaveEnvelope.fromJson(map)      ← v1 için upgrades eksik → ileride typed fromJson fail
  → Checksum verify
```

Yeni akış:
```
_tryRead(file)
  → readAsString
  → jsonDecode → raw map
  → version oku
  → if version < targetVersion:
        SaveMigrator.migrate(raw, targetVersion) → typed + new checksum
        (checksum already fresh from migrator)
        return _ReadResult(existed, envelope, migrated=true)
    else:
        SaveEnvelope.fromJson(raw) → typed
        Checksum.of(env.gameState.toJson()) != env.checksum → corrupt
        return _ReadResult(existed, envelope)
```

Implementation:

```dart
// Sprint A'dan gelen _ReadResult'a `migrated: bool` field'ı eklenir:
class _ReadResult {
  const _ReadResult({
    required this.existed,
    this.envelope,
    this.migrated = false,
  });
  final bool existed;
  final SaveEnvelope? envelope;
  final bool migrated;
}

Future<_ReadResult> _tryRead(File file) async {
  final String raw;
  try {
    raw = await file.readAsString();
  } on PathNotFoundException {
    return const _ReadResult(existed: false);
  } on FileSystemException {
    return const _ReadResult(existed: false);
  }
  try {
    final rawMap = jsonDecode(raw) as Map<String, dynamic>;
    final version = rawMap['version'] as int;

    if (version < _kTargetVersion) {
      final migrated = SaveMigrator.migrate(rawMap, _kTargetVersion);
      // Migration sonrası checksum zaten migrator içinde yeniden hesaplandı.
      return _ReadResult(existed: true, envelope: migrated, migrated: true);
    }

    final envelope = SaveEnvelope.fromJson(rawMap);
    // NFR-2 (Sprint A post-review): v2+ için çekişum verify
    if (Checksum.of(envelope.gameState.toJson()) != envelope.checksum) {
      return const _ReadResult(existed: true);
    }
    return _ReadResult(existed: true, envelope: envelope);
  } on Exception {
    return const _ReadResult(existed: true);
  }
}
```

Sınıf başında const ekle:

```dart
static const int _kTargetVersion = 2;
```

Ve `load()` metodunda migration olmuşsa yeni formatta diske yaz (silent upgrade):

```dart
Future<SaveLoadResult> load() async {
  // ... existing logic for main/bak
  final mainRead = await _tryRead(main);
  if (mainRead.envelope != null) {
    if (mainRead.migrated) {
      // Silent re-save in new v2 format
      unawaited(save(mainRead.envelope!));
    }
    return SaveLoadResult(envelope: mainRead.envelope);
  }
  // ... existing bak fallback
}
```

- [ ] **Step 9: Test — SaveRepository v1 → v2 disk round-trip**

`test/core/save/save_repository_test.dart` sonuna yeni test ekle:

```dart
test('v1 disk file → load returns v2 typed envelope', () async {
  // Manuel v1 formatında disk dosyası kur
  final mainPath = '${tempDir.path}/crumbs_save.json';
  final v1Raw = {
    'version': 1,
    'lastSavedAt': '2026-04-17T10:00:00.000',
    'gameState': {
      'meta': {'installId': 'legacy-user'},
      'run': {'startedAt': '2026-04-17T09:00:00.000'},
      'inventory': {'r1Crumbs': 250.0},
      'buildings': {'owned': {'crumb_collector': 2}},
      // upgrades key YOK — bu testin asıl amacı
    },
    'checksum': 'legacy-hash-not-verified-for-v1',
  };
  File(mainPath).writeAsStringSync(jsonEncode(v1Raw));

  final result = await repo.load();
  expect(result.envelope, isNotNull);
  expect(result.envelope!.version, 2);
  expect(result.envelope!.gameState.upgrades.owned, isEmpty);
  expect(result.envelope!.gameState.buildings.owned['crumb_collector'], 2);
  expect(result.envelope!.gameState.inventory.r1Crumbs, 250.0);
  expect(result.recovery, isNull);

  // Pump event queue — silent re-save completes
  await Future<void>.delayed(const Duration(milliseconds: 50));

  // Disk'te v2 formatı yazılmış olmalı
  final rewrittenRaw = jsonDecode(File(mainPath).readAsStringSync())
      as Map<String, dynamic>;
  expect(rewrittenRaw['version'], 2);
});
```

- [ ] **Step 10: Run — pass**

Run: `flutter test test/core/save/`
Expected: All save tests pass (migrator + repository + envelope).

- [ ] **Step 11: Commit**

```bash
git add lib/core/save/migrations/ lib/core/save/save_migrator.dart lib/core/save/save_repository.dart test/core/save/migrations/ test/core/save/save_migrator_test.dart test/core/save/save_repository_test.dart
git commit -m "sprint-b1(T10): SaveMigrator v1→v2 raw-first + disk re-save on migration"
```

---

## Task 11: GameStateNotifier — buyUpgrade + chain 3-site + debugAddCrumbs (critical)

**Amaç:**
1. `buyUpgrade(String id)` action (idempotent, persist-sync).
2. `MultiplierChain.globalMultiplier(gs.upgrades.owned)` enjeksiyonu 3 yerde: `_onTick`, `build` (cold hydrate), `applyResumeDelta` (hot resume).
3. `@visibleForTesting debugAddCrumbs(double amount)` helper — integration test için.
4. Invariant test: upgrade preserve across resume.

**Files:**
- Modify: `lib/core/state/game_state_notifier.dart`
- Modify: `test/core/state/game_state_notifier_test.dart`

- [ ] **Step 1: Test — buyUpgrade happy path**

`test/core/state/game_state_notifier_test.dart` içine ekle:

```dart
group('GameStateNotifier.buyUpgrade', () {
  test('happy — golden_recipe_i satın alınır, crumbs düşer, owned set olur',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(250);   // 200+ C gerekli
    await container.read(gameStateNotifierProvider.future);

    final success = await notifier.buyUpgrade('golden_recipe_i');
    expect(success, isTrue);

    final gs = container.read(gameStateNotifierProvider).value!;
    expect(gs.upgrades.owned['golden_recipe_i'], isTrue);
    expect(gs.inventory.r1Crumbs, closeTo(50.0, 1e-9));  // 250 - 200
  });

  test('insufficient crumbs → returns false, state unchanged', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(100);  // 200 gerekli ama 100 var

    final success = await notifier.buyUpgrade('golden_recipe_i');
    expect(success, isFalse);
    expect(
      container.read(gameStateNotifierProvider).value!.upgrades.owned,
      isEmpty,
    );
  });

  test('unknown upgrade id → returns false, state unchanged', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(10000);

    final success = await notifier.buyUpgrade('ghost_upgrade_xyz');
    expect(success, isFalse);
  });

  test('already owned → returns false, silent (no crumb re-charge)', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(500);
    await notifier.buyUpgrade('golden_recipe_i');  // first buy
    final before = container.read(gameStateNotifierProvider).value!;

    final success = await notifier.buyUpgrade('golden_recipe_i');  // second
    expect(success, isFalse);
    final after = container.read(gameStateNotifierProvider).value!;
    expect(after.inventory.r1Crumbs, before.inventory.r1Crumbs);
    expect(after.upgrades.owned, before.upgrades.owned);
  });
});
```

- [ ] **Step 2: Test — chain injection 3 site**

Aynı test dosyasında ekle:

```dart
group('GameStateNotifier — MultiplierChain injection', () {
  test('_onTick uses chain — 1 Collector + Golden Recipe → 0.15 C/s scaled',
      () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(500);
    await container.read(gameStateNotifierProvider.future);
    await notifier.buyBuilding('crumb_collector');  // 1 Collector
    await notifier.buyUpgrade('golden_recipe_i');

    final rate = container.read(productionRateProvider);
    expect(rate, closeTo(0.15, 1e-9));  // 0.1 × 1.5
  });

  test('applyResumeDelta preserves upgrades (invariant #10)', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);

    final notifier = container.read(gameStateNotifierProvider.notifier);
    notifier.debugAddCrumbs(500);
    await notifier.buyUpgrade('golden_recipe_i');
    final before = container.read(gameStateNotifierProvider).value!;

    notifier.applyResumeDelta(
      now: DateTime.now().add(const Duration(seconds: 10)),
    );
    final after = container.read(gameStateNotifierProvider).value!;

    expect(
      after.upgrades.owned,
      before.upgrades.owned,
      reason: 'resume must not mutate upgrades',
    );
  });
});
```

- [ ] **Step 3: Test — debugAddCrumbs helper**

```dart
test('debugAddCrumbs helper — adds without side-effects', () async {
  final container = makeContainer();
  addTearDown(container.dispose);
  await container.read(gameStateNotifierProvider.future);

  container
      .read(gameStateNotifierProvider.notifier)
      .debugAddCrumbs(42.0);

  expect(
    container.read(gameStateNotifierProvider).value!.inventory.r1Crumbs,
    42.0,
  );
});
```

- [ ] **Step 4: Run — fail**

Run: `flutter test test/core/state/game_state_notifier_test.dart`
Expected: FAIL — `buyUpgrade`, `debugAddCrumbs` yok; `productionRateProvider` chain'siz.

- [ ] **Step 5: Implementation — GameStateNotifier updates**

`lib/core/state/game_state_notifier.dart` top imports:

```dart
import 'package:crumbs/core/economy/multiplier_chain.dart';
import 'package:crumbs/core/economy/upgrade_defs.dart';
import 'package:flutter/foundation.dart';   // @visibleForTesting + debugPrint
```

Class içinde, `_onTick` güncelle:

```dart
void _onTick(Timer timer) {
  final gs = state.value;
  if (gs == null) return;
  final now = DateTime.now();
  final seconds = now.difference(_lastTickAt).inMilliseconds / 1000.0;
  _lastTickAt = now;
  if (seconds <= 0) return;

  final multiplier = MultiplierChain.globalMultiplier(gs.upgrades.owned);
  final delta = Production.tickDelta(
    gs.buildings.owned,
    seconds,
    globalMultiplier: multiplier,
  );
  if (delta <= 0) return;

  state = AsyncData(
    gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + delta,
      ),
    ),
  );
}
```

`build()` hydration'da (offline compute kısmı):

```dart
final multiplier = MultiplierChain.globalMultiplier(restored.upgrades.owned);
final offline = OfflineProgress.compute(
  buildings: restored.buildings.owned,
  elapsed: elapsed,
  globalMultiplier: multiplier,
);
```

`applyResumeDelta`:

```dart
void applyResumeDelta({DateTime? now}) {
  final gs = state.value;
  if (gs == null) return;
  final currentNow = now ?? DateTime.now();
  final seconds =
      currentNow.difference(_lastTickAt).inMilliseconds / 1000.0;
  if (seconds <= 0) return;

  final multiplier = MultiplierChain.globalMultiplier(gs.upgrades.owned);
  final delta = Production.tickDelta(
    gs.buildings.owned,
    seconds,
    globalMultiplier: multiplier,
  );
  _lastTickAt = currentNow;
  if (delta <= 0) return;

  state = AsyncData(
    gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + delta,
      ),
    ),
  );
}
```

**`buyUpgrade` action (yeni):**

```dart
Future<bool> buyUpgrade(String id) async {
  final gs = state.value;
  if (gs == null) return false;
  if (!UpgradeDefs.exists(id)) return false;        // defensive (test-only)
  if (gs.upgrades.owned[id] == true) return false;  // idempotent (test-only)
  final cost = UpgradeDefs.baseCostFor(id);
  if (gs.inventory.r1Crumbs < cost) return false;

  final updated = gs.copyWith(
    inventory: gs.inventory.copyWith(
      r1Crumbs: gs.inventory.r1Crumbs - cost,
    ),
    upgrades: gs.upgrades.copyWith(
      owned: {...gs.upgrades.owned, id: true},
    ),
  );
  state = AsyncData(updated);
  unawaited(
    _persist(updated).catchError((Object e, StackTrace st) {
      debugPrint('buyUpgrade persist failed: $e\n$st');
    }),
  );
  return true;
}
```

**`debugAddCrumbs` helper (yeni):**

```dart
@visibleForTesting
void debugAddCrumbs(double amount) {
  final gs = state.value;
  if (gs == null) return;
  state = AsyncData(
    gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + amount,
      ),
    ),
  );
}
```

- [ ] **Step 6: Run — pass**

Run: `flutter test test/core/state/`
Expected: Tüm yeni + mevcut test'ler pass.

- [ ] **Step 7: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: All green, 0 issue.

- [ ] **Step 8: Commit**

```bash
git add lib/core/state/game_state_notifier.dart test/core/state/game_state_notifier_test.dart
git commit -m "sprint-b1(T11): GameStateNotifier buyUpgrade + chain injection (tick/hydrate/resume) + debugAddCrumbs"
```

---

## Task 12: Persist catchError + debugPrint cleanup

**Amaç:** Sprint A'nın `unawaited(_persist(...))` pattern'ı silent failure. `tapCrumb`, `buyBuilding`, `buyUpgrade` üçünde de `.catchError((e, st) => debugPrint(...))` wrapper.

**Files:**
- Modify: `lib/core/state/game_state_notifier.dart`

- [ ] **Step 1: Audit existing persist call-sites**

Run: `grep -n "unawaited(_persist" lib/core/state/game_state_notifier.dart`
Expected: Muhtemelen `tapCrumb` + `buyBuilding` içinde 2 occurrence (buyUpgrade Task #11'de zaten catchError'lü).

- [ ] **Step 2: Helper helper — `_persistSafe`**

Yazmak yerine tek satırda tekrarlayabilirsin, ama `buyUpgrade`, `tapCrumb`, `buyBuilding` 3'ünde kopya olacaksa helper daha temiz. Helper:

```dart
void _persistSafe(GameState updated, String context) {
  unawaited(
    _persist(updated).catchError((Object e, StackTrace st) {
      debugPrint('$context persist failed: $e\n$st');
    }),
  );
}
```

Call-site'ları güncelle:

```dart
// tapCrumb
_persistSafe(updated, 'tapCrumb');

// buyBuilding
_persistSafe(updated, 'buyBuilding');

// buyUpgrade (Task #11'de zaten catchError, ama helper'la aynı pattern)
_persistSafe(updated, 'buyUpgrade');
```

- [ ] **Step 3: Run — full suite**

Run: `flutter test && flutter analyze`
Expected: All pass. Behavior change sadece error-path'te (happy path aynı).

- [ ] **Step 4: Commit**

```bash
git add lib/core/state/game_state_notifier.dart
git commit -m "sprint-b1(T12): _persistSafe helper — catchError + debugPrint for all 3 purchase sites"
```

---

## Task 13: Offline cap 24h → 12h

**Amaç:** `OfflineProgress._kOfflineCap` const'unu 24 saat'ten 12 saat'e düşür. Test'te threshold assertion güncellenir.

**Files:**
- Modify: `lib/core/economy/offline_progress.dart`
- Modify: `test/core/economy/offline_progress_test.dart`

- [ ] **Step 1: Test update**

`test/core/economy/offline_progress_test.dart` içinde cap test'i aradığın şekilde (Sprint A'da 24h'a göre yazılmış):

```dart
test('cap limits elapsed to 12 hours (B1 reduction)', () {
  final report = OfflineProgress.compute(
    buildings: {'crumb_collector': 1},
    elapsed: const Duration(hours: 13),
  );
  expect(report.rawElapsed, const Duration(hours: 13));
  expect(report.cappedElapsed, const Duration(hours: 12));
  // 1 Collector × 0.1 × 12h × 3600s = 4320 earned
  expect(report.earned, closeTo(4320.0, 1e-6));
});
```

Eğer mevcut `24h` test'i varsa sil, `12h`'ye değiştir.

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/offline_progress_test.dart`
Expected: FAIL — cap 24h dönüyor.

- [ ] **Step 3: Implementation**

`lib/core/economy/offline_progress.dart`:

```dart
static const Duration _kOfflineCap = Duration(hours: 12);   // ← 24 idi
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/offline_progress_test.dart`
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/offline_progress.dart test/core/economy/offline_progress_test.dart
git commit -m "sprint-b1(T13): offline cap 24h → 12h"
```

---

## Task 14: l10n strings — upgrade + error screen + building names

**Amaç:** `lib/l10n/tr.arb` dosyasına B1 UI string'leri ekle, gen-l10n çalıştır.

**Files:**
- Modify: `lib/l10n/tr.arb`

- [ ] **Step 1: tr.arb'a yeni string'ler ekle**

`lib/l10n/tr.arb` dosyasını aç, mevcut map'e şunları ekle (önceki entry'lerden sonra, closing `}`'dan önce — virgül dikkat):

```json
{
  ... existing ...,
  "goldenRecipeIName": "Altın Tarif I",
  "goldenRecipeIDescription": "Tüm üretim × 1.5",
  "upgradeOwnedBadge": "Sahip ✓",
  "ovenName": "Fırın",
  "bakeryLineName": "Fırıncılık Hattı",
  "errorScreenTitle": "Beklenmedik bir hata",
  "errorScreenBody": "Oyun başlatılamadı. Tekrar denemek ister misin?",
  "errorScreenRetry": "Tekrar dene"
}
```

Mevcut `crumbCollectorName` zaten var; dokunma.

- [ ] **Step 2: gen-l10n üret**

Run: `flutter gen-l10n` (veya `flutter pub get` otomatik tetikler)
Expected: `lib/l10n/app_strings.dart` + `app_strings_tr.dart` regen; yeni getter'lar mevcut (`.goldenRecipeIName` vb).

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: 0 issue.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "sprint-b1(T14): l10n — upgrade + error screen + oven/bakery_line names"
```

---

## Task 15: UpgradeRow widget

**Amaç:** BuildingRow pattern'inin upgrade versiyonu — affordability, shake-on-fail, owned badge.

**Files:**
- Create: `lib/features/upgrades/widgets/upgrade_row.dart`
- Create: `test/features/upgrades/widgets/upgrade_row_test.dart`

- [ ] **Step 1: Test — UpgradeRow render states**

Write `test/features/upgrades/widgets/upgrade_row_test.dart`:

```dart
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_ur_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Widget makeApp({required Widget child}) => ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(
            SaveRepository(directoryProvider: () async => tempDir.path),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('renders name + cost when not owned, affordable', (tester) async {
    await tester.pumpWidget(
      makeApp(
        child: const UpgradeRow(
          id: 'golden_recipe_i',
          displayName: 'Altın Tarif I',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Butona simulate 500 C ekle
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpgradeRow)),
    );
    container
        .read(gameStateNotifierProvider.notifier)
        .debugAddCrumbs(500);
    await tester.pumpAndSettle();

    expect(find.text('Altın Tarif I'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);  // fmt(200)
    expect(find.text('Satın al'), findsOneWidget);
  });

  testWidgets('owned state — "Sahip ✓" badge + no buy button', (tester) async {
    await tester.pumpWidget(
      makeApp(
        child: const UpgradeRow(
          id: 'golden_recipe_i',
          displayName: 'Altın Tarif I',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpgradeRow)),
    );
    container.read(gameStateNotifierProvider.notifier).debugAddCrumbs(500);
    await container
        .read(gameStateNotifierProvider.notifier)
        .buyUpgrade('golden_recipe_i');
    await tester.pumpAndSettle();

    expect(find.text('Sahip ✓'), findsOneWidget);
    expect(find.text('Satın al'), findsNothing);
  });

  testWidgets('insufficient funds → button half opacity', (tester) async {
    await tester.pumpWidget(
      makeApp(
        child: const UpgradeRow(
          id: 'golden_recipe_i',
          displayName: 'Altın Tarif I',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 0 crumbs (default) — affordable false
    expect(find.byType(Opacity), findsWidgets);
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 0.5);
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/features/upgrades/widgets/upgrade_row_test.dart`
Expected: FAIL — UpgradeRow yok.

- [ ] **Step 3: Implementation**

Write `lib/features/upgrades/widgets/upgrade_row.dart`:

```dart
import 'package:crumbs/core/economy/upgrade_defs.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  Text(s.goldenRecipeIDescription,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (owned)
              Chip(
                label: Text(s.upgradeOwnedBadge),
                backgroundColor: theme.colorScheme.secondaryContainer,
              )
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt(cost.toDouble()),
                      style: theme.textTheme.titleMedium),
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
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/features/upgrades/`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/upgrades/ test/features/upgrades/
git commit -m "sprint-b1(T15): UpgradeRow widget — BuildingRow pattern + owned badge"
```

---

## Task 16: UpgradesPage + `/upgrades` route + nav slot unlock

**Amaç:** Upgrades tab functional — nav bar slot snack yerine `/upgrades`'e push eder; page tek upgrade row render eder.

**Files:**
- Create: `lib/features/upgrades/upgrades_page.dart`
- Modify: `lib/app/routing/app_router.dart`
- Modify: `lib/app/nav/app_navigation_bar.dart`
- Create: `test/features/upgrades/upgrades_page_test.dart`

- [ ] **Step 1: UpgradesPage implementation**

Write `lib/features/upgrades/upgrades_page.dart`:

```dart
import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class UpgradesPage extends StatelessWidget {
  const UpgradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navUpgrades)),
      body: ListView(
        children: [
          UpgradeRow(
            id: 'golden_recipe_i',
            displayName: s.goldenRecipeIName,
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
    );
  }
}
```

- [ ] **Step 2: AppRouter — `/upgrades` route**

`lib/app/routing/app_router.dart` routes array'ine ekle:

```dart
GoRoute(
  path: Routes.upgrades,
  builder: (context, state) => const UpgradesPage(),
),
```

Import: `import 'package:crumbs/features/upgrades/upgrades_page.dart';`

- [ ] **Step 3: AppNavigationBar — Upgrades slotu aktif**

`lib/app/nav/app_navigation_bar.dart` içindeki `_handleTap` switch'inde:

```dart
case NavSection.upgrades:
  context.go('/upgrades');   // ← snack yerine
```

`destinations` array'indeki upgrades entry'sinde icon:

```dart
NavigationDestination(
  icon: const Icon(Icons.auto_awesome),   // ← lock_outline idi
  label: s.navUpgrades,
),
```

- [ ] **Step 4: UpgradesPage smoke test**

Write `test/features/upgrades/upgrades_page_test.dart`:

```dart
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/features/upgrades/upgrades_page.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_upgrades_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('UpgradesPage renders golden_recipe_i row', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(
            SaveRepository(directoryProvider: () async => tempDir.path),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: const UpgradesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UpgradeRow), findsOneWidget);
    expect(find.text('Altın Tarif I'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run — pass**

Run: `flutter test test/features/upgrades/upgrades_page_test.dart`
Expected: 1/1 pass.

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: 0 issue.

- [ ] **Step 7: Commit**

```bash
git add lib/features/upgrades/upgrades_page.dart lib/app/routing/app_router.dart lib/app/nav/app_navigation_bar.dart test/features/upgrades/upgrades_page_test.dart
git commit -m "sprint-b1(T16): UpgradesPage + /upgrades route + nav slot unlock"
```

---

## Task 17: ShopPage — 3 BuildingRow

**Amaç:** ShopPage ListView'a `oven` + `bakery_line` rows eklenir.

**Files:**
- Modify: `lib/features/shop/shop_page.dart`

- [ ] **Step 1: Implementation**

`lib/features/shop/shop_page.dart`:

```dart
body: ListView(
  children: [
    BuildingRow(id: 'crumb_collector', displayName: s.crumbCollectorName),
    BuildingRow(id: 'oven', displayName: s.ovenName),
    BuildingRow(id: 'bakery_line', displayName: s.bakeryLineName),
  ],
),
```

Gerisi aynı kalır (AppBar + bottomNavigationBar).

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: 0 issue.

- [ ] **Step 3: Commit**

```bash
git add lib/features/shop/shop_page.dart
git commit -m "sprint-b1(T17): ShopPage — 3 BuildingRow (collector + oven + bakery_line)"
```

---

## Task 18: ErrorScreen + main.dart `async.when` wiring (critical)

**Amaç:** `AsyncError` durumunda ErrorScreen render. "Tekrar dene" → `ref.invalidate(gameStateNotifierProvider)`.

**Files:**
- Create: `lib/app/error/error_screen.dart`
- Modify: `lib/main.dart`
- Create: `test/app/error/error_screen_test.dart`

- [ ] **Step 1: Test — ErrorScreen render + retry**

Write `test/app/error/error_screen_test.dart`:

```dart
import 'package:crumbs/app/error/error_screen.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorScreen', () {
    testWidgets('renders title + body + retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
            home: const ErrorScreen(error: 'test error'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beklenmedik bir hata'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_dissatisfied), findsOneWidget);
    });

    testWidgets('retry tap does not throw', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppStrings.localizationsDelegates,
            supportedLocales: AppStrings.supportedLocales,
            home: const ErrorScreen(error: 'test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      // No crash — invalidate succeeded even if provider isn't pre-initialized
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/app/error/error_screen_test.dart`
Expected: FAIL — ErrorScreen yok.

- [ ] **Step 3: Implementation**

Write `lib/app/error/error_screen.dart`:

```dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AsyncError fallback — path_provider / SharedPreferences / binding
/// init hatalarında CrumbsApp.build `.when` branch'inden render edilir.
///
/// Save corruption senaryoları SaveRepository + .bak fallback zincirinde
/// absorbe olur; bu ekran sadece non-save dış hatalar için.
class ErrorScreen extends ConsumerWidget {
  const ErrorScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sentiment_dissatisfied, size: 64),
              const SizedBox(height: 16),
              Text(
                s.errorScreenTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                s.errorScreenBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(gameStateNotifierProvider),
                child: Text(s.errorScreenRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: main.dart — async.when branch**

`lib/main.dart` CrumbsApp:

```dart
import 'package:crumbs/app/error/error_screen.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
// ... existing imports

class CrumbsApp extends ConsumerWidget {
  const CrumbsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gameStateNotifierProvider);
    final router = ref.watch(appRouterProvider);
    return async.when(
      data: (_) => MaterialApp.router(
        title: 'Crumbs',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
      ),
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: ErrorScreen(error: e),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
      ),
    );
  }
}
```

- [ ] **Step 5: Run — pass**

Run: `flutter test test/app/error/error_screen_test.dart`
Expected: 2/2 pass.

- [ ] **Step 6: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: All green, 0 issue.

- [ ] **Step 7: Commit**

```bash
git add lib/app/error/error_screen.dart lib/main.dart test/app/error/
git commit -m "sprint-b1(T18): ErrorScreen + main.dart async.when wiring"
```

---

## Task 19: Integration test — round-trip with upgrade

**Amaç:** End-to-end: cold start → tap → buy Collector → `debugAddCrumbs(200)` short-circuit → buy Golden Recipe I → productionRateProvider ×1.5 assertion.

**Files:**
- Modify: `integration_test/app_test.dart`

- [ ] **Step 1: Implementation**

`integration_test/app_test.dart`:

```dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/shop/widgets/building_row.dart';
import 'package:crumbs/features/upgrades/widgets/upgrade_row.dart';
import 'package:crumbs/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cold start → tap → buy building → buy upgrade', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CrumbCounterHeader)),
    );

    // 1 Collector için 15 C gerekir → 16 tap
    for (var i = 0; i < 16; i++) {
      await tester.tap(find.byIcon(Icons.cookie));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    // Shop → Collector satın al
    await tester.tap(find.byIcon(Icons.store));
    await tester.pumpAndSettle();
    expect(find.byType(BuildingRow), findsNWidgets(3));  // 3 bina
    // Collector satın al (ilk buildable button)
    await tester.tap(find.text('Satın al').first);
    await tester.pumpAndSettle();

    // Golden Recipe I için 200 C gerekli — tap-spam yerine helper
    container
        .read(gameStateNotifierProvider.notifier)
        .debugAddCrumbs(200);
    await tester.pumpAndSettle();

    // Upgrades tab
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();
    expect(find.byType(UpgradeRow), findsOneWidget);

    // Satın al
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // Owned badge görünür
    expect(find.text('Sahip ✓'), findsOneWidget);

    // Production rate × 1.5 doğrulaması
    expect(
      container.read(productionRateProvider),
      closeTo(0.15, 1e-9),
      reason: '1 Collector (0.1) × Golden Recipe I (1.5) = 0.15 C/s',
    );
  });
}
```

- [ ] **Step 2: Run integration test on device/simulator**

Run: `flutter test integration_test/app_test.dart`
(Requires connected device or simulator; unit-test runner yeterli değil integration_test için)
Expected: Pass, ~2-3s test süresi.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: 0 issue.

- [ ] **Step 4: Commit**

```bash
git add integration_test/app_test.dart
git commit -m "sprint-b1(T19): integration test — upgrade round-trip + productionRateProvider assertion"
```

---

## Final Verification

- [ ] **Step 1: Full test suite + coverage**

Run:
```bash
flutter test --coverage
```

Expected: All green. `coverage/lcov.info` üretilir.

- [ ] **Step 2: Coverage hedefleri**

Manuel inspect (lcov yüklü ise `lcov --summary coverage/lcov.info`):
- `lib/core/economy/` ≥ %95
- `lib/core/save/` ≥ %95
- `lib/core/state/` ≥ %85
- `lib/features/upgrades/` ≥ %70
- `lib/app/error/` ≥ %80

- [ ] **Step 3: Cross-cutting review**

Dispatch final code-reviewer subagent for the whole branch (superpowers:subagent-driven-development final step). Branch diff baseline: `main` veya `sprint/a-vertical-slice` tip'i.

- [ ] **Step 4: Push + PR**

```bash
git push -u origin sprint/b1-expansion
gh pr create --base main --head sprint/b1-expansion \
  --title "Sprint B1: 3 buildings + Golden Recipe I + v2 save migration + error screen" \
  --body "Spec: docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md

DoD:
- 3 bina Shop'ta görünür (Collector affordable, oven + bakery_line gray)
- Upgrades tab unlock + Golden Recipe I satın alınabilir (cost 200 C, ×1.5 global)
- 1 Collector + Golden Recipe I → productionRateProvider 0.15 C/s
- v1 disk format → v2 typed envelope migration + disk re-save (test pin)
- Offline cap 12h automated test
- AsyncError → ErrorScreen retry path test-verified

Coverage: economy ≥95%, save ≥95%, state ≥85%, features ≥70%, error ≥80%.

Invariants (11):
- Sprint A'nın 5'i regression-free (tick race, offline report cold-start-only,
  saveRecovery cold-start-only, canonical checksum, haptic non-blocking)
- B1 yeni 6: tek-kaynak multiplier, chain 3-site, UpgradeState pure bool map,
  migration idempotency, applyResumeDelta upgrade preserve, buyUpgrade
  already-owned test-only defensive."
```

- [ ] **Step 5: CI bekle**

CI run'u yeşil bekle (`flutter analyze`, `flutter test --coverage`, integration_test). Kırmızıysa fix; yeşilse merge adayı.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-17-sprint-b1-expansion.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Her task için fresh subagent dispatch; critical task'larda (★: #1, #3, #4, #5, #8, #9, #10, #11, #18) spec reviewer + code quality reviewer; fast iteration. C task'lar controller-direct, hafif review.

**2. Inline Execution** — `superpowers:executing-plans` ile batch execution + checkpoints.

**Which approach?**
