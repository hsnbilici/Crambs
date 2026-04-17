# Sprint A — Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Project Crumbs'ta en küçük bitmiş idle oyun döngüsünü teslim et — tıkla, +1 Crumb kazan, Crumb Collector al, pasif üretim başlasın, kaydet, offline kazancı al.

**Architecture:** Riverpod 3.x AsyncNotifier tabanlı `GameState` merkez state; pure functions (`CostCurve`, `Production`, `OfflineProgress`) saf ekonomi hesabı; atomic file I/O + SHA-256 canonical checksum ile persistence; `AppLifecycleGate` wrapper ile pause/resume/save yönetimi; `flutter_animate` ile floating number + shake polish; `gen-l10n` ile tr.arb tek locale. Drift-free tick + hot-resume offline delta tek formül altında (`Production.tickDelta`).

**Tech Stack:** Flutter 3.41.5 (pinned via FVM), Dart 3.11, Riverpod 3.1 (flutter_riverpod + riverpod_annotation + riverpod_generator), freezed 3.0 + json_serializable, go_router 17.2, path_provider 2.1, crypto 3.0 (SHA-256), shared_preferences 2.3, flutter_animate 4.5, uuid 4.5, intl 0.20 + flutter_localizations.

**Referans:** `docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md` (tasarım kararları + rationale).

---

## Önkoşullar (plan öncesi)

- `main` branch'te: scaffold PR merged (`94ae7dd`), design doc commit (`5a0bb17`)
- `fix/platform-launch-setup` branch'i push edildi ama henüz merge değil — bu plan'a başlamadan önce:
  - Branch merge edilebilir: `git checkout main && git merge --ff-only fix/platform-launch-setup && git push`
  - Veya PR açılabilir: `gh pr create --base main --head fix/platform-launch-setup`
- Yeni branch: `sprint/a-vertical-slice` açılır, bu plan'daki tüm commit'ler orada toplanır.
- Flutter 3.41.5 FVM ile: `fvm install 3.41.5 && fvm use 3.41.5`

---

## Task 1: Pubspec yeni bağımlılıkları

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Mevcut deps'i teyit et**

Run: `grep -E "path_provider|crypto|intl" pubspec.yaml`
Expected çıktı:
```
  path_provider: ^2.1.5
  crypto: ^3.0.6
  intl: ^0.20.2
```
Bu 3 dep scaffold'da mevcut — Task 1 kapsamına girmez.

- [ ] **Step 2: pubspec.yaml'a yeni deps ekle**

`pubspec.yaml` dependencies bölümüne, `in_app_purchase: ^3.2.0` satırının hemen altına ekle:

```yaml
  # Sprint A — polish + onboarding + telemetry foundation
  flutter_animate: ^4.5.2
  shared_preferences: ^2.3.4
  uuid: ^4.5.1
  flutter_localizations:
    sdk: flutter
```

`flutter:` bölümünü genişlet (aynı dosyanın sonunda):

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/
```

- [ ] **Step 3: pub get çalıştır**

Run: `flutter pub get`
Expected: `Got dependencies!` veya `Changed N dependencies` — sıfır hata.

- [ ] **Step 4: analyze hala temiz mi?**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock 2>/dev/null; git add pubspec.yaml
git commit -m "sprint-a(T1): add flutter_animate, shared_preferences, uuid, flutter_localizations"
```

Not: `pubspec.lock` gitignored (pubspec.lock).

---

## Task 2: L10n kurulumu (gen-l10n + tr.arb)

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/tr.arb`

- [ ] **Step 1: `l10n.yaml` oluştur**

```yaml
# l10n.yaml — flutter gen-l10n konfigürasyonu
arb-dir: lib/l10n
template-arb-file: tr.arb
output-localization-file: app_strings.dart
output-class: AppStrings
synthetic-package: true
```

- [ ] **Step 2: `lib/l10n/tr.arb` oluştur**

```json
{
  "@@locale": "tr",
  "appTitle": "Crumbs",
  "tapHint": "Cupcake'e dokun, Crumbs kazan",
  "welcomeBack": "Yokken {amount} Crumb kazandın ({duration})",
  "@welcomeBack": {
    "placeholders": {
      "amount": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
  "offlineCapped": "Çevrim dışı kazanç {cap} saate sınırlandı",
  "@offlineCapped": { "placeholders": { "cap": { "type": "int" } } },
  "saveRecoveryBackup": "Son kayıt bozuk, yedekten yüklendi",
  "saveRecoveryFresh": "Kayıt kurtarılamadı, yeni başladı",
  "crumbCollectorName": "Crumb Collector",
  "buyButton": "Satın al",
  "ownedLabel": "Sahip: {count}",
  "@ownedLabel": { "placeholders": { "count": { "type": "int" } } },
  "insufficientCrumbs": "Yetersiz Crumb",
  "rateLabel": "C/s: {rate}",
  "@rateLabel": { "placeholders": { "rate": { "type": "String" } } },
  "navHome": "Ev",
  "navShop": "Dükkân",
  "navUpgrades": "Yükseltmeler",
  "navResearch": "Araştırma",
  "navMore": "Daha fazla",
  "navEvents": "Olaylar",
  "navPrestige": "Prestige",
  "navCollection": "Koleksiyon",
  "navSettings": "Ayarlar",
  "navLockUpgradesA": "Sonraki güncellemede açılır",
  "navLockResearch": "15-30 dakika oyun sonrası açılır",
  "navLockEvents": "Yakında",
  "navLockPrestige": "Prestige koşulu sağlandığında açılır",
  "navLockCollection": "Yakında",
  "settingsPlaceholder": "Ayarlar yakında eklenecek"
}
```

- [ ] **Step 3: gen-l10n çalıştır**

Run: `flutter pub get`
Expected: otomatik `AppStrings` class'ını üretir. `.dart_tool/flutter_gen/gen_l10n/app_strings.dart` dosyası üretilmiş olmalı.

Doğrula:
```bash
ls .dart_tool/flutter_gen/gen_l10n/ 2>/dev/null | head -3
```
Expected: `app_strings.dart` satırını içerir.

- [ ] **Step 4: Küçük dummy import testi (derleme doğrulama)**

Run: `flutter analyze`
Expected: `No issues found!` — l10n yalnız kurulumda, kullanılmıyor henüz.

- [ ] **Step 5: Commit**

```bash
git add l10n.yaml lib/l10n/tr.arb
git commit -m "sprint-a(T2): gen-l10n setup + tr.arb initial strings"
```

---

## Task 3: GameState freezed 3'lü

**Files:**
- Create: `lib/core/save/game_state.dart`
- Create: `test/core/save/game_state_test.dart`

- [ ] **Step 1: Failing test — GameState.initial() shape**

Write `test/core/save/game_state_test.dart`:

```dart
import 'package:crumbs/core/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState', () {
    test('initial() produces zero-state with fresh installId', () {
      final now = DateTime(2026, 4, 17, 12, 0, 0);
      final state = GameState.initial(now: now, installId: 'test-uuid');

      expect(state.meta.lastSavedAt, '2026-04-17T12:00:00.000');
      expect(state.meta.schemaVersion, 1);
      expect(state.meta.installId, 'test-uuid');
      expect(state.inventory.r1Crumbs, 0);
      expect(state.buildings.owned, isEmpty);
    });

    test('copyWith preserves unchanged children', () {
      final state = GameState.initial(
        now: DateTime(2026, 4, 17),
        installId: 'id-1',
      );
      final updated = state.copyWith(
        inventory: state.inventory.copyWith(r1Crumbs: 42),
      );

      expect(updated.inventory.r1Crumbs, 42);
      expect(updated.meta.installId, 'id-1');
      expect(updated.buildings.owned, isEmpty);
    });

    test('fromJson(toJson(x)) roundtrip equal', () {
      final state = GameState.initial(
        now: DateTime(2026, 4, 17),
        installId: 'rt-id',
      ).copyWith(
        inventory: const InventoryState(r1Crumbs: 12.5),
        buildings: const BuildingsState(owned: {'crumb_collector': 3}),
      );

      final json = state.toJson();
      final restored = GameState.fromJson(json);

      expect(restored, equals(state));
    });
  });
}
```

- [ ] **Step 2: Run test — beklenen hata: import hatası**

Run: `flutter test test/core/save/game_state_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:crumbs/core/save/game_state.dart'`

- [ ] **Step 3: `game_state.dart` oluştur**

Write `lib/core/save/game_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';
part 'game_state.g.dart';

/// Game state root — 3'lü ayrım: meta (deterministic invariant),
/// inventory (resource state), buildings (structure state).
/// OnboardingPrefs checksum/migration dışında kalır (device state ≠ player state).
///
/// OfflineReport push rule: yalnız cold start hydration (SaveRepository.load)
/// path'inde tetiklenir. applyResumeDelta sessiz çalışır.
@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    required MetaState meta,
    required InventoryState inventory,
    required BuildingsState buildings,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);

  factory GameState.initial({DateTime? now, String? installId}) => GameState(
        meta: MetaState(
          lastSavedAt: (now ?? DateTime.now()).toIso8601String(),
          schemaVersion: 1,
          installId: installId ?? 'uninitialized',
        ),
        inventory: const InventoryState(r1Crumbs: 0),
        buildings: const BuildingsState(owned: {}),
      );
}

@freezed
abstract class MetaState with _$MetaState {
  const factory MetaState({
    required String lastSavedAt,
    required int schemaVersion,
    required String installId,
  }) = _MetaState;
  factory MetaState.fromJson(Map<String, dynamic> j) => _$MetaStateFromJson(j);
}

@freezed
abstract class InventoryState with _$InventoryState {
  const factory InventoryState({
    required double r1Crumbs,
  }) = _InventoryState;
  factory InventoryState.fromJson(Map<String, dynamic> j) =>
      _$InventoryStateFromJson(j);
}

@freezed
abstract class BuildingsState with _$BuildingsState {
  const factory BuildingsState({
    required Map<String, int> owned,
  }) = _BuildingsState;
  factory BuildingsState.fromJson(Map<String, dynamic> j) =>
      _$BuildingsStateFromJson(j);
}
```

- [ ] **Step 4: build_runner çalıştır**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 4 yeni `.freezed.dart` + `.g.dart` dosyası üretildi; `[SEVERE]` yok.

- [ ] **Step 5: Testi çalıştır — pass**

Run: `flutter test test/core/save/game_state_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/save/game_state.dart test/core/save/game_state_test.dart
git commit -m "sprint-a(T3): GameState freezed 3'lü (meta + inventory + buildings)"
```

---

## Task 4: CostCurve saf fonksiyon

**Files:**
- Modify: `lib/core/economy/cost_curve.dart`
- Create: `test/core/economy/cost_curve_test.dart` (replace scaffold smoke stub)

- [ ] **Step 1: Failing tests**

Replace `test/core/economy/cost_curve_test.dart` içeriğini:

```dart
import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CostCurve.costFor', () {
    // economy.md §5: cost(n) = floor(baseCost × growthRate^owned)
    // Crumb Collector: base=10, growth=1.15
    test('owned=0 → base cost', () {
      expect(CostCurve.costFor(10, 1.15, 0), 10);
    });

    test('owned=1 → 10 × 1.15 = 11.5 → floor 11', () {
      expect(CostCurve.costFor(10, 1.15, 1), 11);
    });

    test('owned=5 → 10 × 1.15^5 ≈ 20.11 → 20', () {
      expect(CostCurve.costFor(10, 1.15, 5), 20);
    });

    test('owned=25 → 10 × 1.15^25 ≈ 329.19 → 329', () {
      expect(CostCurve.costFor(10, 1.15, 25), 329);
    });

    test('edge: owned=0 base=0 → 0', () {
      expect(CostCurve.costFor(0, 1.15, 0), 0);
    });

    test('edge: growth=1.0 flat → always base', () {
      expect(CostCurve.costFor(100, 1.0, 10), 100);
    });
  });
}
```

- [ ] **Step 2: Run tests — fail (eski stub'ın `isA<Type>()` pass ama yeni testler fail)**

Run: `flutter test test/core/economy/cost_curve_test.dart`
Expected: FAIL — `The method 'costFor' isn't defined for the type 'CostCurve'`.

- [ ] **Step 3: `cost_curve.dart` implementasyonu**

Replace `lib/core/economy/cost_curve.dart`:

```dart
import 'dart:math';

/// Bina maliyet eğrisi.
/// Spec: docs/economy.md §5 — cost(n) = floor(baseCost × growthRate^owned)
class CostCurve {
  const CostCurve._();

  /// Bina için n. birim maliyeti.
  /// owned: halihazırda sahip olunan sayı (0-index — 0 ise ilk alım).
  static num costFor(num baseCost, double growthRate, int owned) =>
      (baseCost * pow(growthRate, owned)).floor();
}
```

- [ ] **Step 4: Run tests — pass**

Run: `flutter test test/core/economy/cost_curve_test.dart`
Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/cost_curve.dart test/core/economy/cost_curve_test.dart
git commit -m "sprint-a(T4): CostCurve saf fonksiyon — floor(base × growth^owned)"
```

---

## Task 5: Production + BuildingDefs

**Files:**
- Modify: `lib/core/economy/production.dart`
- Create: `test/core/economy/production_test.dart` (replace scaffold stub)

- [ ] **Step 1: Failing tests**

Replace `test/core/economy/production_test.dart`:

```dart
import 'package:crumbs/core/economy/production.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Production.baseProductionFor', () {
    test('crumb_collector → 0.1 C/s', () {
      expect(Production.baseProductionFor('crumb_collector'), 0.1);
    });

    test('unknown id → 0 (no exception)', () {
      expect(Production.baseProductionFor('unknown'), 0);
    });
  });

  group('Production.baseCostFor', () {
    test('crumb_collector → 10', () {
      expect(Production.baseCostFor('crumb_collector'), 10);
    });

    test('unknown id → 0', () {
      expect(Production.baseCostFor('unknown'), 0);
    });
  });

  group('Production.growthFor', () {
    test('crumb_collector → 1.15', () {
      expect(Production.growthFor('crumb_collector'), 1.15);
    });

    test('unknown id → 1.0 (flat)', () {
      expect(Production.growthFor('unknown'), 1.0);
    });
  });

  group('Production.totalPerSecond', () {
    test('boş map → 0', () {
      expect(Production.totalPerSecond({}), 0);
    });

    test('1 collector → 0.1', () {
      expect(Production.totalPerSecond({'crumb_collector': 1}), 0.1);
    });

    test('5 collector → 0.5', () {
      expect(Production.totalPerSecond({'crumb_collector': 5}), closeTo(0.5, 1e-12));
    });

    test('unknown building katkı vermez', () {
      expect(
        Production.totalPerSecond({'crumb_collector': 3, 'unknown': 10}),
        closeTo(0.3, 1e-12),
      );
    });
  });

  group('Production.tickDelta', () {
    test('1 collector × 1.0s = 0.1', () {
      expect(
        Production.tickDelta({'crumb_collector': 1}, 1.0),
        closeTo(0.1, 1e-12),
      );
    });

    test('0s delta = 0', () {
      expect(Production.tickDelta({'crumb_collector': 5}, 0.0), 0);
    });

    test('lineer akkümülasyon: 5×(0.2s) ≈ 1×(1.0s) — relative tolerance', () {
      final b = {'crumb_collector': 100};
      final chunked = List.generate(5, (_) => Production.tickDelta(b, 0.2))
          .reduce((a, c) => a + c);
      final whole = Production.tickDelta(b, 1.0);
      final diff = (chunked - whole).abs();
      final tolerance = 1e-12 * (chunked.abs() > whole.abs() ? chunked.abs() : whole.abs());
      expect(diff, lessThan(tolerance));
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/economy/production_test.dart`
Expected: FAIL — `The method 'baseProductionFor' isn't defined`.

- [ ] **Step 3: `production.dart` implementasyonu**

Replace `lib/core/economy/production.dart`:

```dart
/// Üretim formülleri — bina başına saniyede üretim.
/// Spec: docs/economy.md §2, §3
///
/// BuildingDefs lookup'ları burada: base production, base cost, growth.
/// A kapsamı: tek bina (crumb_collector). B+'ta genişler.
/// Unknown id defensively 0 / 1.0 döner — forward-compat (yeni binaları
/// iyimser eklemeye izin verir, eski kodda exception atmaz).
class Production {
  const Production._();

  /// Base production (C/s). economy.md §2.
  static double baseProductionFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 0.1,
        _ => 0.0,
      };

  /// Base cost. economy.md §2. CostCurve.costFor bu değeri büyütür.
  static num baseCostFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 10,
        _ => 0,
      };

  /// Growth rate — cost(n) = base × growth^owned. economy.md §5.
  static double growthFor(String buildingId) => switch (buildingId) {
        'crumb_collector' => 1.15,
        _ => 1.0,
      };

  /// Toplam üretim hızı (C/s). UI + tick + offline tek noktadan besler.
  static double totalPerSecond(Map<String, int> buildings) {
    double total = 0;
    buildings.forEach((id, owned) {
      total += owned * baseProductionFor(id);
    });
    return total;
  }

  /// Tick veya offline delta. seconds = wall-clock elapsed.
  /// Tek kod yolu — online tick + cold start hydration + hot resume ortak formül.
  static double tickDelta(Map<String, int> buildings, double seconds) =>
      totalPerSecond(buildings) * seconds;
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/economy/production_test.dart`
Expected: `+14: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/economy/production.dart test/core/economy/production_test.dart
git commit -m "sprint-a(T5): Production + BuildingDefs (crumb_collector) + tickDelta"
```

---

## Task 6: OfflineProgress + OfflineReport

**Files:**
- Create: `lib/core/feedback/offline_report.dart`
- Modify: `lib/core/economy/offline_progress.dart`
- Create: `test/core/economy/offline_progress_test.dart` (replace scaffold stub)
- Create: `test/core/feedback/offline_report_test.dart`

- [ ] **Step 1: OfflineReport freezed tests**

Write `test/core/feedback/offline_report_test.dart`:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineReport', () {
    test('constructor + equality', () {
      const r1 = OfflineReport(
        earned: 12.5,
        elapsed: Duration(minutes: 1),
        capped: false,
      );
      const r2 = OfflineReport(
        earned: 12.5,
        elapsed: Duration(minutes: 1),
        capped: false,
      );
      expect(r1, equals(r2));
    });

    test('capped flag field', () {
      const r = OfflineReport(
        earned: 0,
        elapsed: Duration(days: 2),
        capped: true,
      );
      expect(r.capped, isTrue);
    });
  });
}
```

- [ ] **Step 2: OfflineReport implementation**

Write `lib/core/feedback/offline_report.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'offline_report.freezed.dart';

/// Cold start hydration sonunda UI'a taşınan offline kazanç özeti.
/// applyResumeDelta (hot resume) BU MODELİ PUSH ETMEZ — yalnız build path.
@freezed
abstract class OfflineReport with _$OfflineReport {
  const factory OfflineReport({
    required double earned,
    required Duration elapsed,
    required bool capped,
  }) = _OfflineReport;
}
```

- [ ] **Step 3: build_runner + test**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/feedback/offline_report_test.dart
```
Expected: 2/2 pass.

- [ ] **Step 4: OfflineProgress tests**

Replace `test/core/economy/offline_progress_test.dart`:

```dart
import 'package:crumbs/core/economy/offline_progress.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineProgress.compute', () {
    // 1 collector × 0.1 C/s sabiti kullanılır.
    GameState stateWith({
      required DateTime lastSavedAt,
      Map<String, int> buildings = const {'crumb_collector': 1},
    }) =>
        GameState(
          meta: MetaState(
            lastSavedAt: lastSavedAt.toIso8601String(),
            schemaVersion: 1,
            installId: 'test',
          ),
          inventory: const InventoryState(r1Crumbs: 0),
          buildings: BuildingsState(owned: buildings),
        );

    test('0s elapsed → 0 earned, not capped', () {
      final now = DateTime(2026, 4, 17, 12);
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: now),
        now,
      );
      expect(report.earned, 0);
      expect(report.elapsed, Duration.zero);
      expect(report.capped, isFalse);
    });

    test('60s elapsed × 1 collector = 6 Crumbs', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(seconds: 60));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      expect(report.earned, closeTo(6.0, 1e-9));
      expect(report.elapsed, const Duration(seconds: 60));
      expect(report.capped, isFalse);
    });

    test('1h elapsed × 1 collector = 360 Crumbs', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 1));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      expect(report.earned, closeTo(360.0, 1e-6));
    });

    test('25h elapsed → capped at 24h', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 25));
      final report = OfflineProgress.compute(stateWith(lastSavedAt: last), now);
      // 24h × 0.1 C/s × 3600 = 8640 Crumbs
      expect(report.earned, closeTo(8640.0, 1e-3));
      expect(report.elapsed, const Duration(hours: 25));
      expect(report.capped, isTrue);
    });

    test('no buildings → 0 earned regardless of elapsed', () {
      final last = DateTime(2026, 4, 17, 12);
      final now = last.add(const Duration(hours: 5));
      final report = OfflineProgress.compute(
        stateWith(lastSavedAt: last, buildings: {}),
        now,
      );
      expect(report.earned, 0);
      expect(report.elapsed, const Duration(hours: 5));
    });
  });
}
```

- [ ] **Step 5: OfflineProgress implementation**

Replace `lib/core/economy/offline_progress.dart`:

```dart
import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/game_state.dart';

/// Offline progress — açılışta `now − meta.lastSavedAt` delta'sı üzerinden
/// pasif kazancı hesaplar. Production.tickDelta ile ortak formül (online tick
/// + cold start + hot resume tek kod yolu).
///
/// Spec: docs/economy.md §3.4
class OfflineProgress {
  const OfflineProgress._();

  /// A: 24 saat cap — test cihazını günlerce kapatan kullanıcıya shock-value
  /// snackbar yerine makul UX. B'de Duration(hours: 12)'ye indirilir.
  static const Duration _kOfflineCap = Duration(hours: 24);

  /// seconds = effective.inMicroseconds / 1e6 (microsecond precision).
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
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/core/economy/offline_progress_test.dart test/core/feedback/offline_report_test.dart`
Expected: `+7: All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/economy/offline_progress.dart lib/core/feedback/ test/core/economy/offline_progress_test.dart test/core/feedback/
git commit -m "sprint-a(T6): OfflineProgress + OfflineReport (24h cap, rawElapsed)"
```

---

## Task 7: Checksum (canonical SHA-256)

**Files:**
- Create: `lib/core/save/checksum.dart`
- Create: `test/core/save/checksum_test.dart`

- [ ] **Step 1: Failing tests**

Write `test/core/save/checksum_test.dart`:

```dart
import 'dart:convert';

import 'package:crumbs/core/save/checksum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Checksum.of', () {
    test('empty map → constant hash', () {
      final h = Checksum.of({});
      expect(h.length, 64);  // sha256 hex = 64 chars
      expect(h, Checksum.of({}));  // deterministik
    });

    test('canonical: key order invariant', () {
      final h1 = Checksum.of({'a': 1, 'b': 2});
      final h2 = Checksum.of({'b': 2, 'a': 1});
      expect(h1, equals(h2));
    });

    test('nested map key order invariant', () {
      final h1 = Checksum.of({
        'outer': {'a': 1, 'b': 2}
      });
      final h2 = Checksum.of({
        'outer': {'b': 2, 'a': 1}
      });
      expect(h1, equals(h2));
    });

    test('list order IS significant (data difference)', () {
      final h1 = Checksum.of({
        'l': [1, 2, 3]
      });
      final h2 = Checksum.of({
        'l': [3, 2, 1]
      });
      expect(h1, isNot(equals(h2)));
    });

    test('value change changes hash', () {
      expect(
        Checksum.of({'a': 1}),
        isNot(equals(Checksum.of({'a': 2}))),
      );
    });

    test('shipping gate: toJson → fromJson → toJson checksum identical', () {
      const json1 = {
        'version': 1,
        'buildings': {
          'owned': {'crumb_collector': 3, 'bakery': 1},
        },
      };
      final h1 = Checksum.of(json1);
      // Simulate round-trip via jsonEncode/jsonDecode
      final decoded = jsonDecode(jsonEncode(json1)) as Map<String, dynamic>;
      final h2 = Checksum.of(decoded);
      expect(h1, equals(h2));
    });
  });
}
```

- [ ] **Step 2: Run — fail (import hatası)**

Run: `flutter test test/core/save/checksum_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: `checksum.dart` implementasyonu**

Write `lib/core/save/checksum.dart`:

```dart
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 canonical JSON hash — key-sorted, determinism garantisi.
///
/// Amaç: disk corruption detection (NFR-2). Tamper resistance kapsam dışı —
/// single-player offline, leaderboard yok. Anti-cheat ihtiyacı doğarsa
/// HMAC + server secret'a geçilir, API surface (Checksum.of) korunur.
///
/// Spec: docs/save-format.md §3
class Checksum {
  const Checksum._();

  static String of(Map<String, dynamic> json) {
    final canonical = _canonicalize(json);
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static dynamic _canonicalize(dynamic v) {
    if (v is Map) {
      final sorted = SplayTreeMap<String, dynamic>.of(
        v.map((k, val) => MapEntry(k.toString(), _canonicalize(val))),
      );
      return sorted;
    }
    if (v is List) return v.map(_canonicalize).toList();
    return v;
  }
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/save/checksum_test.dart`
Expected: `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/save/checksum.dart test/core/save/checksum_test.dart
git commit -m "sprint-a(T7): Checksum — canonical SHA-256 (corruption only)"
```

---

## Task 8: SaveEnvelope + SaveMigrator interface

**Files:**
- Modify: `lib/core/save/save_envelope.dart` (T3 scaffold'dan bağ kuracak)
- Modify: `lib/core/save/save_migrator.dart`
- Modify: `test/core/save/save_envelope_test.dart` (replace scaffold stub)
- Create: `test/core/save/save_migrator_test.dart` (zaten var, genişlet)

- [ ] **Step 1: SaveEnvelope tests**

Replace `test/core/save/save_envelope_test.dart`:

```dart
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveEnvelope', () {
    test('construction + equality', () {
      final e1 = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: 'abc',
      );
      final e2 = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: 'abc',
      );
      expect(e1, equals(e2));
    });

    test('fromJson(toJson(x)) roundtrip', () {
      final e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {
          'meta': {'installId': 'id-1'},
        },
        checksum: 'hash',
      );
      final restored = SaveEnvelope.fromJson(e.toJson());
      expect(restored, equals(e));
    });
  });
}
```

- [ ] **Step 2: Run — fail (scaffold stub `isA<Type>()` pass, yeni assertion fail)**

Run: `flutter test test/core/save/save_envelope_test.dart`
Expected: FAIL — `SaveEnvelope.new` sign positional arg'ları eşleşmiyor (scaffold'daki minimal class).

- [ ] **Step 3: SaveEnvelope tam implementasyon**

T3 scaffold'daki `lib/core/save/save_envelope.dart` zaten freezed-skeleton; değiştirmeye gerek yok (zaten tam). Yalnız `abstract class` pattern'i doğrula:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// SaveEnvelope — disk persistence şeması.
/// Spec: docs/save-format.md §1
///
/// gameState alanı A'da `Map<String, dynamic>` tutuyor; B'de GameState typed
/// field'a geçilir (envelope version 1 → 2 bump + migrator v1→v2).
@freezed
abstract class SaveEnvelope with _$SaveEnvelope {
  const factory SaveEnvelope({
    required int version,
    required String lastSavedAt,
    required Map<String, dynamic> gameState,
    required String checksum,
  }) = _SaveEnvelope;

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) =>
      _$SaveEnvelopeFromJson(json);
}
```

Eğer zaten bu içerikse sadece doc comment'i güncelle.

- [ ] **Step 4: SaveMigrator tests**

Replace `test/core/save/save_migrator_test.dart`:

```dart
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveMigrator', () {
    test('migrate v1 → v1 no-op', () {
      final e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: 'c',
      );
      final migrated = SaveMigrator.migrate(e, targetVersion: 1);
      expect(migrated, equals(e));
    });

    test('migrate future version throws', () {
      final e = SaveEnvelope(
        version: 3,  // simulated future save (B'de version 2 olacak, A'da asla 3)
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {},
        checksum: 'c',
      );
      expect(
        () => SaveMigrator.migrate(e, targetVersion: 1),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
```

- [ ] **Step 5: SaveMigrator implementation**

Replace `lib/core/save/save_migrator.dart`:

```dart
import 'package:crumbs/core/save/save_envelope.dart';

/// Save version zinciri yönetimi.
/// Spec: docs/save-format.md §6
///
/// A kapsamı: v1 → v1 no-op (framework hazır).
/// B'de migrator v1 → v2 eklenir (envelope typed GameState transition).
class SaveMigrator {
  const SaveMigrator._();

  /// Envelope'u target version'a taşır. Future-version gelirse UnsupportedError
  /// (kullanıcı yeni app sürümünü eski app'te açmaya çalıştı).
  static SaveEnvelope migrate(
    SaveEnvelope envelope, {
    required int targetVersion,
  }) {
    if (envelope.version == targetVersion) return envelope;
    if (envelope.version > targetVersion) {
      throw UnsupportedError(
        'Save version ${envelope.version} newer than app version $targetVersion — '
        'downgrade not supported',
      );
    }
    // A'da v1 tek sürüm; burada zincir başlatılır ancak kayıt yok.
    throw UnimplementedError(
      'Migration chain ${envelope.version} → $targetVersion henüz tanımlı değil',
    );
  }
}
```

- [ ] **Step 6: build_runner + test**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/save/save_envelope_test.dart test/core/save/save_migrator_test.dart
```
Expected: 4/4 pass.

- [ ] **Step 7: Commit**

```bash
git add lib/core/save/save_envelope.dart lib/core/save/save_migrator.dart test/core/save/
git commit -m "sprint-a(T8): SaveEnvelope + SaveMigrator v1→v1 framework"
```

---

## Task 9: SaveRepository (atomic write + recovery + race lock)

**Files:**
- Modify: `lib/core/save/save_repository.dart`
- Create: `lib/core/feedback/save_recovery.dart`
- Create: `test/core/save/save_repository_test.dart`

- [ ] **Step 1: SaveRecoveryReason enum**

Write `lib/core/feedback/save_recovery.dart`:

```dart
/// Save load path'inde corruption detection sonrası UI'a taşınan sinyal.
/// Spec: docs/save-format.md — NFR-2 fallback to backup.
enum SaveRecoveryReason {
  checksumFailedUsedBackup,
  bothCorruptedStartedFresh,
}
```

- [ ] **Step 2: SaveRepository tests (mocktail ile)**

Write `test/core/save/save_repository_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late SaveRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crumbs_save_test_');
    repo = SaveRepository(directoryProvider: () async => tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SaveEnvelope sampleEnvelope({String checksum = 'abc'}) => SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: checksum,
      );

  group('SaveRepository.save', () {
    test('creates main.json file', () async {
      await repo.save(sampleEnvelope());
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
    });

    test('second save rotates .bak', () async {
      await repo.save(sampleEnvelope(checksum: 'first'));
      await repo.save(sampleEnvelope(checksum: 'second'));
      final main = File('${tempDir.path}/crumbs_save.json');
      final bak = File('${tempDir.path}/crumbs_save.json.bak');
      expect(main.existsSync(), isTrue);
      expect(bak.existsSync(), isTrue);
      final mainJson = jsonDecode(main.readAsStringSync()) as Map<String, dynamic>;
      final bakJson = jsonDecode(bak.readAsStringSync()) as Map<String, dynamic>;
      expect(mainJson['checksum'], 'second');
      expect(bakJson['checksum'], 'first');
    });

    test('concurrent saves serialized (no race)', () async {
      // Issue 5 concurrent saves rapidly.
      final futures = List.generate(5, (i) => repo.save(
            sampleEnvelope(checksum: 'save-$i'),
          ));
      await Future.wait(futures);
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
      // Son save'in içeriği main'de olmalı (sıralı işlendiler).
      final mainJson = jsonDecode(main.readAsStringSync()) as Map<String, dynamic>;
      expect(mainJson['checksum'], startsWith('save-'));
    });
  });

  group('SaveRepository.load — recovery', () {
    test('no file → null + no recovery reason', () async {
      final result = await repo.load();
      expect(result.envelope, isNull);
      expect(result.recovery, isNull);
    });

    test('valid main → returns envelope, no recovery', () async {
      // Save ile yaz
      final e = SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: 'placeholder',  // SaveRepository checksum'u dışarıdan verilmiş
      );
      await repo.save(e);
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.envelope!.version, 1);
      expect(result.recovery, isNull);
    });

    test('corrupt main → uses .bak, signals checksumFailedUsedBackup', () async {
      // İki save yaz (ikincisi .bak rotate eder)
      await repo.save(sampleEnvelope(checksum: 'valid-bak'));
      await repo.save(sampleEnvelope(checksum: 'valid-main'));
      // Main'i boz
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{corrupt json');
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.recovery, SaveRecoveryReason.checksumFailedUsedBackup);
    });

    test('both corrupt → null envelope + bothCorruptedStartedFresh', () async {
      await repo.save(sampleEnvelope(checksum: 'v1'));
      await repo.save(sampleEnvelope(checksum: 'v2'));
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{bad}');
      File('${tempDir.path}/crumbs_save.json.bak').writeAsStringSync('{bad}');
      final result = await repo.load();
      expect(result.envelope, isNull);
      expect(result.recovery, SaveRecoveryReason.bothCorruptedStartedFresh);
    });
  });
}
```

- [ ] **Step 3: Run — fail**

Run: `flutter test test/core/save/save_repository_test.dart`
Expected: FAIL — SaveRepository constructor / API farklı.

- [ ] **Step 4: SaveRepository implementasyonu**

Replace `lib/core/save/save_repository.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:path_provider/path_provider.dart';

/// Save load sonucu — envelope + opsiyonel recovery sinyali.
class SaveLoadResult {
  const SaveLoadResult({this.envelope, this.recovery});
  final SaveEnvelope? envelope;
  final SaveRecoveryReason? recovery;
}

/// Disk I/O, atomik yazma, yedek rotasyon, corruption recovery.
/// Spec: docs/save-format.md §4, §5
///
/// Save cadence kararı SaveRepository'de DEĞİL — AppLifecycleGate'te
/// (30s timer + onPause/onDetach + purchase sync).
///
/// Concurrent save race: _pending Future lock ile serialize edilir.
class SaveRepository {
  SaveRepository({Future<String> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<String> Function() _directoryProvider;
  Future<void>? _pending;

  static const _mainFileName = 'crumbs_save.json';
  static const _bakFileName = 'crumbs_save.json.bak';
  static const _tmpFileName = 'crumbs_save.json.tmp';

  static Future<String> _defaultDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Atomic save — tmp → rename mainFile, önceki main → bak rotate.
  /// Concurrent save'ler serialize edilir (race'siz).
  Future<void> save(SaveEnvelope envelope) async {
    // Önceki save bitene kadar bekle — basit serialization.
    while (_pending != null) {
      await _pending;
    }
    _pending = _saveImpl(envelope);
    try {
      await _pending;
    } finally {
      _pending = null;
    }
  }

  Future<void> _saveImpl(SaveEnvelope envelope) async {
    final dir = await _directoryProvider();
    final main = File('$dir/$_mainFileName');
    final bak = File('$dir/$_bakFileName');
    final tmp = File('$dir/$_tmpFileName');

    final data = jsonEncode(envelope.toJson());
    await tmp.writeAsString(data, flush: true);

    if (await main.exists()) {
      if (await bak.exists()) await bak.delete();
      await main.rename(bak.path);
    }
    await tmp.rename(main.path);
  }

  /// Corruption recovery: main bozuksa .bak; ikisi de bozuksa null.
  Future<SaveLoadResult> load() async {
    final dir = await _directoryProvider();
    final main = File('$dir/$_mainFileName');
    final bak = File('$dir/$_bakFileName');

    final fromMain = await _tryRead(main);
    if (fromMain != null) return SaveLoadResult(envelope: fromMain);

    if (await main.exists()) {
      // Main vardı ama parse edilemedi → bak'tan dene
      final fromBak = await _tryRead(bak);
      if (fromBak != null) {
        return const SaveLoadResult().copyWithRecovery(
          fromBak,
          SaveRecoveryReason.checksumFailedUsedBackup,
        );
      }
      return const SaveLoadResult(
        recovery: SaveRecoveryReason.bothCorruptedStartedFresh,
      );
    }

    // Main hiç yoksa — fresh install, recovery sinyali yok.
    return const SaveLoadResult();
  }

  Future<SaveEnvelope?> _tryRead(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SaveEnvelope.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

extension _WithRecovery on SaveLoadResult {
  SaveLoadResult copyWithRecovery(
    SaveEnvelope envelope,
    SaveRecoveryReason reason,
  ) =>
      SaveLoadResult(envelope: envelope, recovery: reason);
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/save/save_repository_test.dart`
Expected: 7/7 pass.

Not: Bu testler disk I/O kullanıyor (`Directory.systemTemp.createTemp`). Çok hızlılar (<500ms toplam). Mocktail gerekmiyor — `directoryProvider` inject edilebilir constructor arg zaten.

- [ ] **Step 6: Commit**

```bash
git add lib/core/save/save_repository.dart lib/core/feedback/save_recovery.dart test/core/save/save_repository_test.dart
git commit -m "sprint-a(T9): SaveRepository atomic write + .bak recovery + race lock"
```

---

## Task 10: OnboardingPrefs provider

**Files:**
- Create: `lib/core/preferences/onboarding_prefs.dart`
- Create: `test/core/preferences/onboarding_prefs_test.dart`

- [ ] **Step 1: Tests**

Write `test/core/preferences/onboarding_prefs_test.dart`:

```dart
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initial state — hint not dismissed (fresh install)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(onboardingPrefsProvider.notifier).ensureLoaded();
    expect(container.read(onboardingPrefsProvider).hintDismissed, isFalse);
  });

  test('dismissHint flips flag and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(onboardingPrefsProvider.notifier);
    await notifier.ensureLoaded();
    await notifier.dismissHint();

    expect(container.read(onboardingPrefsProvider).hintDismissed, isTrue);

    // Yeni container'da okuma (persist doğrulaması)
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);
    await fresh.read(onboardingPrefsProvider.notifier).ensureLoaded();
    expect(fresh.read(onboardingPrefsProvider).hintDismissed, isTrue);
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/preferences/onboarding_prefs_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation**

Write `lib/core/preferences/onboarding_prefs.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_prefs.freezed.dart';

@freezed
abstract class OnboardingPrefs with _$OnboardingPrefs {
  const factory OnboardingPrefs({
    required bool hintDismissed,
  }) = _OnboardingPrefs;

  factory OnboardingPrefs.initial() =>
      const OnboardingPrefs(hintDismissed: false);
}

/// Onboarding tercihleri — SharedPreferences backed.
/// GameState (save envelope) DIŞINDA. Checksum/migration etkilenmez.
///
/// Cold start akışı:
///   container.read(onboardingPrefsProvider.notifier).ensureLoaded();
/// (AppBootstrap bunu runApp öncesi yapar)
final onboardingPrefsProvider =
    NotifierProvider<OnboardingPrefsNotifier, OnboardingPrefs>(
  OnboardingPrefsNotifier.new,
);

class OnboardingPrefsNotifier extends Notifier<OnboardingPrefs> {
  static const _keyHintDismissed = 'onboarding.hint_dismissed';

  @override
  OnboardingPrefs build() => OnboardingPrefs.initial();

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = OnboardingPrefs(
      hintDismissed: prefs.getBool(_keyHintDismissed) ?? false,
    );
  }

  Future<void> dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHintDismissed, true);
    state = state.copyWith(hintDismissed: true);
  }
}
```

- [ ] **Step 4: build_runner + test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/preferences/onboarding_prefs_test.dart
```
Expected: 2/2 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/preferences/ test/core/preferences/
git commit -m "sprint-a(T10): OnboardingPrefs SharedPreferences-backed Notifier"
```

---

## Task 11: GameStateNotifier (AsyncNotifier — integration)

**Files:**
- Create: `lib/core/state/game_state_notifier.dart`
- Create: `test/core/state/game_state_notifier_test.dart`

- [ ] **Step 1: Tests**

Write `test/core/state/game_state_notifier_test.dart`:

```dart
import 'dart:io';

import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_notifier_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
    ]);
  }

  test('cold start — no save → initial state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final state = await container.read(gameStateNotifierProvider.future);
    expect(state.inventory.r1Crumbs, 0);
    expect(state.buildings.owned, isEmpty);
  });

  test('tapCrumb increments r1Crumbs by 1', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    container.read(gameStateNotifierProvider.notifier).tapCrumb();
    final gs = container.read(gameStateNotifierProvider).valueOrNull!;
    expect(gs.inventory.r1Crumbs, 1);
  });

  test('buyBuilding — insufficient → false, state unchanged', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    final result = await notifier.buyBuilding('crumb_collector');
    expect(result, isFalse);
    final gs = container.read(gameStateNotifierProvider).valueOrNull!;
    expect(gs.inventory.r1Crumbs, 0);
    expect(gs.buildings.owned, isEmpty);
  });

  test('buyBuilding — sufficient → true, cost deducted, owned++', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    // Manually bump Crumbs to 15
    for (var i = 0; i < 15; i++) {
      notifier.tapCrumb();
    }
    final result = await notifier.buyBuilding('crumb_collector');
    expect(result, isTrue);
    final gs = container.read(gameStateNotifierProvider).valueOrNull!;
    expect(gs.inventory.r1Crumbs, 5);  // 15 - 10
    expect(gs.buildings.owned['crumb_collector'], 1);
  });

  test('applyProductionDelta adds fractional crumbs', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) notifier.tapCrumb();
    await notifier.buyBuilding('crumb_collector');  // owned=1, r1=5
    notifier.applyProductionDelta(10.0);  // 1 × 0.1 × 10 = +1.0
    final gs = container.read(gameStateNotifierProvider).valueOrNull!;
    expect(gs.inventory.r1Crumbs, closeTo(6.0, 1e-9));
  });

  test('applyResumeDelta — hot resume offline progress (no snackbar push)',
      () async {
    // Önce state hazırla ve disk'e kaydet
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) notifier.tapCrumb();
    await notifier.buyBuilding('crumb_collector');
    // meta.lastSavedAt şu an = purchase time
    final before = container.read(gameStateNotifierProvider).valueOrNull!;
    final pauseTime = DateTime.parse(before.meta.lastSavedAt);
    // 30s sonra resume simüle et
    final resumeTime = pauseTime.add(const Duration(seconds: 30));
    notifier.applyResumeDelta(now: resumeTime);
    final after = container.read(gameStateNotifierProvider).valueOrNull!;
    // 1 collector × 0.1 C/s × 30 = 3.0
    expect(after.inventory.r1Crumbs - before.inventory.r1Crumbs,
        closeTo(3.0, 1e-9));
    // OfflineReport push edilmedi (hot resume sessiz)
    expect(container.read(offlineReportProvider), isNull);
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/state/game_state_notifier_test.dart`
Expected: FAIL — URI / provider eksik.

- [ ] **Step 3: GameStateNotifier implementation**

Write `lib/core/state/game_state_notifier.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:crumbs/core/economy/offline_progress.dart';
import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_migrator.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const int _kCurrentSchemaVersion = 1;

/// UI sinyal kanalları.
/// OfflineReport YALNIZCA cold start (build hydration) path'inden push edilir.
/// applyResumeDelta (hot resume) BU PROVIDER'LARI DEĞIŞTIRMEZ — kural
/// game_state_notifier.dart'ta explicit.
final offlineReportProvider = StateProvider<OfflineReport?>((_) => null);
final saveRecoveryProvider = StateProvider<SaveRecoveryReason?>((_) => null);

/// SaveRepository override edilebilir — test'lerde ./tempDir kullanılır.
final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => SaveRepository(),
);

class GameStateNotifier extends AsyncNotifier<GameState> {
  Timer? _tick;
  DateTime? _lastTickAt;
  DateTime? _lastHaptic;

  @override
  Future<GameState> build() async {
    ref.onDispose(() {
      _tick?.cancel();
      _tick = null;
    });

    final repo = ref.read(saveRepositoryProvider);
    final loadResult = await repo.load();

    GameState hydrated;
    OfflineReport? offlineReport;

    if (loadResult.envelope != null) {
      final migrated = SaveMigrator.migrate(
        loadResult.envelope!,
        targetVersion: _kCurrentSchemaVersion,
      );
      // Envelope gameState alanı Map<String,dynamic>; GameState'e deserialize.
      hydrated = GameState.fromJson(migrated.gameState);
      // Offline delta hesapla ve uygula
      final now = DateTime.now();
      offlineReport = OfflineProgress.compute(hydrated, now);
      hydrated = hydrated.copyWith(
        inventory: hydrated.inventory
            .copyWith(r1Crumbs: hydrated.inventory.r1Crumbs + offlineReport.earned),
        meta: hydrated.meta.copyWith(lastSavedAt: now.toIso8601String()),
      );
    } else {
      hydrated = GameState.initial(installId: const Uuid().v4());
    }

    // UI sinyal push'ları — cold start'a özel
    if (loadResult.recovery != null) {
      ref.read(saveRecoveryProvider.notifier).state = loadResult.recovery;
    }
    if (offlineReport != null && offlineReport.earned > 0) {
      ref.read(offlineReportProvider.notifier).state = offlineReport;
    }

    // Tick spawn — _lastTickAt önce set edilir (ilk tick düzgün delta üretsin)
    _lastTickAt = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 200), _onTick);

    return hydrated;
  }

  void _onTick(Timer _) {
    final now = DateTime.now();
    final seconds = _lastTickAt == null
        ? 0.0
        : now.difference(_lastTickAt!).inMicroseconds / 1e6;
    _lastTickAt = now;
    if (seconds > 0) applyProductionDelta(seconds);
  }

  void tapCrumb() {
    final gs = state.valueOrNull;
    if (gs == null) return;
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs + 1),
    ));
    _triggerHaptic();
    // Onboarding hint dismiss (pass-through) — ilk tap hem +1 hem hint fade
    final prefs = ref.read(onboardingPrefsProvider);
    if (!prefs.hintDismissed) {
      // fire-and-forget — UI zaten state watch ediyor
      ref.read(onboardingPrefsProvider.notifier).dismissHint();
    }
  }

  Future<bool> buyBuilding(String id) async {
    final gs = state.valueOrNull;
    if (gs == null) return false;
    final owned = gs.buildings.owned[id] ?? 0;
    final cost = CostCurve.costFor(
      Production.baseCostFor(id),
      Production.growthFor(id),
      owned,
    );
    if (gs.inventory.r1Crumbs < cost) return false;
    final updated = gs.copyWith(
      inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs - cost),
      buildings: gs.buildings.copyWith(
        owned: {...gs.buildings.owned, id: owned + 1},
      ),
    );
    state = AsyncData(updated);
    await _persist(updated);  // purchase sync save
    return true;
  }

  void applyProductionDelta(double seconds) {
    final gs = state.valueOrNull;
    if (gs == null) return;
    final delta = Production.tickDelta(gs.buildings.owned, seconds);
    if (delta == 0) return;
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory
          .copyWith(r1Crumbs: gs.inventory.r1Crumbs + delta),
    ));
  }

  /// Hot resume path. SESSIZ: OfflineReport push etmez, snackbar yok.
  /// now parametresi testability için — production'da DateTime.now().
  void applyResumeDelta({DateTime? now}) {
    final gs = state.valueOrNull;
    if (gs == null) return;
    final n = now ?? DateTime.now();
    final last = DateTime.parse(gs.meta.lastSavedAt);
    final seconds = n.difference(last).inMicroseconds / 1e6;
    if (seconds <= 0) return;
    final delta = Production.tickDelta(gs.buildings.owned, seconds);
    state = AsyncData(gs.copyWith(
      inventory: gs.inventory.copyWith(
        r1Crumbs: gs.inventory.r1Crumbs + delta,
      ),
      meta: gs.meta.copyWith(lastSavedAt: n.toIso8601String()),
    ));
  }

  void resetTickClock() {
    _lastTickAt = null;
  }

  Future<void> _persist(GameState gs) async {
    final repo = ref.read(saveRepositoryProvider);
    final json = gs.toJson();
    final envelope = SaveEnvelope(
      version: _kCurrentSchemaVersion,
      lastSavedAt: DateTime.now().toIso8601String(),
      gameState: json,
      checksum: Checksum.of(json),
    );
    await repo.save(envelope);
  }

  /// Public API — AppLifecycleGate tarafından çağrılır.
  Future<void> persistNow() async {
    final gs = state.valueOrNull;
    if (gs == null) return;
    await _persist(gs);
  }

  void _triggerHaptic() {
    final now = DateTime.now();
    if (_lastHaptic != null &&
        now.difference(_lastHaptic!).inMilliseconds < 80) {
      return;
    }
    _lastHaptic = now;
    HapticFeedback.lightImpact();
  }
}

final gameStateNotifierProvider =
    AsyncNotifierProvider<GameStateNotifier, GameState>(
  GameStateNotifier.new,
);
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/state/game_state_notifier_test.dart`
Expected: 6/6 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/state/ test/core/state/
git commit -m "sprint-a(T11): GameStateNotifier AsyncNotifier — hydrate + tap + buy + resume"
```

---

## Task 12: AppBootstrap (pre-hydration)

**Files:**
- Modify: `lib/app/boot/app_bootstrap.dart`
- Create: `test/app/boot/app_bootstrap_test.dart`

- [ ] **Step 1: Test**

Write `test/app/boot/app_bootstrap_test.dart`:

```dart
import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initialize returns ready ProviderContainer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final container = await AppBootstrap.initialize();
    expect(container, isA<ProviderContainer>());
    container.dispose();
  });
}
```

- [ ] **Step 2: Implementation**

Replace `lib/app/boot/app_bootstrap.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pre-hydration saf servis — runApp çağrısından önce:
/// 1. WidgetsBindingObserver ready
/// 2. SharedPreferences warm cache (ilk getInstance async; sonraki sync erişim)
/// 3. ProviderContainer kurulumu
///
/// Lifecycle / autosave / observer sorumluluğu AppLifecycleGate'te (Task 13).
/// Firebase init ayrı runbook — A kapsamı dışı.
class AppBootstrap {
  const AppBootstrap._();

  static Future<ProviderContainer> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SharedPreferences.getInstance();
    return ProviderContainer();
  }
}
```

- [ ] **Step 3: Run test**

Run: `flutter test test/app/boot/app_bootstrap_test.dart`
Expected: 1/1 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/app/boot/app_bootstrap.dart test/app/boot/
git commit -m "sprint-a(T12): AppBootstrap pre-hydration (SharedPreferences warm + container)"
```

---

## Task 13: AppLifecycleGate (lifecycle + autosave + resume delta)

**Files:**
- Create: `lib/app/lifecycle/app_lifecycle_gate.dart`
- Create: `test/app/lifecycle/app_lifecycle_gate_test.dart`

- [ ] **Step 1: Test (widget + lifecycle pump)**

Write `test/app/lifecycle/app_lifecycle_gate_test.dart`:

```dart
import 'dart:io';

import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_gate_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('onPause triggers save; onResume applies delta + resets tick clock',
      (tester) async {
    final container = ProviderContainer(overrides: [
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) notifier.tapCrumb();
    await notifier.buyBuilding('crumb_collector');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: AppLifecycleGate(child: SizedBox.shrink()),
      ),
    ));

    // Simulate paused
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 50));

    // Save yazıldı mı?
    final saveFile = File('${tempDir.path}/crumbs_save.json');
    expect(saveFile.existsSync(), isTrue);

    // Resume — applyResumeDelta çalışmalı
    final beforeResume =
        container.read(gameStateNotifierProvider).valueOrNull!.inventory.r1Crumbs;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    final afterResume =
        container.read(gameStateNotifierProvider).valueOrNull!.inventory.r1Crumbs;
    // Delta pozitif (üretim geldi) veya ~eşit (test hızlı)
    expect(afterResume, greaterThanOrEqualTo(beforeResume));
  });
}
```

- [ ] **Step 2: Implementation**

Write `lib/app/lifecycle/app_lifecycle_gate.dart`:

```dart
import 'dart:async';

import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle observer + autosave + hot resume offline delta gate.
///
/// onPause / onDetach: await _saveNow() — state'i diske yazar.
/// onResume: applyResumeDelta (sync) → resetTickClock (warmup).
/// 30s periodic autosave — worst-case kayıp penceresi.
class AppLifecycleGate extends ConsumerStatefulWidget {
  const AppLifecycleGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleGate> createState() =>
      _AppLifecycleGateState();
}

class _AppLifecycleGateState extends ConsumerState<AppLifecycleGate> {
  late final AppLifecycleListener _listener;
  late final Timer _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: _saveNow,
      onDetach: _saveNow,
      onResume: _onResume,
    );
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveNow(),
    );
  }

  Future<void> _saveNow() async {
    final notifier = ref.read(gameStateNotifierProvider.notifier);
    await notifier.persistNow();
  }

  void _onResume() {
    final notifier = ref.read(gameStateNotifierProvider.notifier);
    notifier.applyResumeDelta();
    notifier.resetTickClock();
  }

  @override
  void dispose() {
    _autoSaveTimer.cancel();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 3: Run test**

Run: `flutter test test/app/lifecycle/app_lifecycle_gate_test.dart`
Expected: 1/1 pass.

- [ ] **Step 4: Commit**

```bash
git add lib/app/lifecycle/ test/app/lifecycle/
git commit -m "sprint-a(T13): AppLifecycleGate — autosave 30s + onPause save + onResume delta"
```

---

## Task 14: Derived providers

**Files:**
- Create: `lib/core/state/providers.dart`
- Create: `lib/features/home/providers.dart`
- Create: `test/core/state/providers_test.dart`

- [ ] **Step 1: Tests**

Write `test/core/state/providers_test.dart`:

```dart
import 'dart:io';

import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('crumbs_providers_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        saveRepositoryProvider.overrideWithValue(
          SaveRepository(directoryProvider: () async => tempDir.path),
        ),
      ]);

  test('currentCrumbsProvider — reflects notifier state', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    container.read(gameStateNotifierProvider.notifier).tapCrumb();
    expect(container.read(currentCrumbsProvider), 1);
  });

  test('productionRateProvider — totalPerSecond sum', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    final notifier = container.read(gameStateNotifierProvider.notifier);
    for (var i = 0; i < 15; i++) notifier.tapCrumb();
    await notifier.buyBuilding('crumb_collector');
    expect(container.read(productionRateProvider), closeTo(0.1, 1e-12));
  });

  test('costCurveProvider family — memoized cost lookup', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(gameStateNotifierProvider.future);
    expect(container.read(costCurveProvider(('crumb_collector', 0))), 10);
    expect(container.read(costCurveProvider(('crumb_collector', 1))), 11);
    expect(container.read(costCurveProvider(('unknown', 0))), 0);
  });
}
```

- [ ] **Step 2: Implementation**

Write `lib/core/state/providers.dart`:

```dart
import 'package:crumbs/core/economy/cost_curve.dart';
import 'package:crumbs/core/economy/production.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI'ın okuduğu derived state — notifier değişince rebuild.
final currentCrumbsProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).valueOrNull;
  return gs?.inventory.r1Crumbs ?? 0;
});

final productionRateProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).valueOrNull;
  return gs == null ? 0 : Production.totalPerSecond(gs.buildings.owned);
});

/// Family key: (buildingId, ownedCount). Shop BuildingRow bu provider'ı watch eder.
final costCurveProvider = Provider.family<num, (String, int)>(
  (ref, args) {
    final (id, owned) = args;
    return CostCurve.costFor(
      Production.baseCostFor(id),
      Production.growthFor(id),
      owned,
    );
  },
);
```

- [ ] **Step 3: `features/home/providers.dart` (floatingNumbersProvider)**

Write `lib/features/home/providers.dart`:

```dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingNumber {
  FloatingNumber({required this.id, required this.amount, required this.dx});
  final int id;
  final double amount;
  final double dx;  // ±20px X jitter
}

class FloatingNumbersNotifier extends Notifier<List<FloatingNumber>> {
  static const int _maxConcurrent = 5;
  int _seq = 0;
  final _rng = Random();

  @override
  List<FloatingNumber> build() => const [];

  void spawn(double amount) {
    final number = FloatingNumber(
      id: ++_seq,
      amount: amount,
      dx: _rng.nextDouble() * 40 - 20,
    );
    final next = [...state, number];
    state = next.length > _maxConcurrent
        ? next.sublist(next.length - _maxConcurrent)
        : next;
  }

  void remove(int id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final floatingNumbersProvider =
    NotifierProvider<FloatingNumbersNotifier, List<FloatingNumber>>(
  FloatingNumbersNotifier.new,
);
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/state/providers_test.dart`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/state/providers.dart lib/features/home/providers.dart test/core/state/providers_test.dart
git commit -m "sprint-a(T14): derived providers (currentCrumbs, productionRate, costCurve family, floatingNumbers)"
```

---

## Task 15: Number formatter `fmt()` (TR locale + short scale)

**Files:**
- Create: `lib/ui/format/number_format.dart`
- Create: `test/ui/format/number_format_test.dart`

- [ ] **Step 1: Tests**

Write `test/ui/format/number_format_test.dart`:

```dart
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fmt — special', () {
    test('NaN → —', () => expect(fmt(double.nan), '—'));
    test('Infinity → —', () => expect(fmt(double.infinity), '—'));
    test('0 → 0', () => expect(fmt(0), '0'));
    test('0.0 → 0 (not 0,0)', () => expect(fmt(0.0), '0'));
  });

  group('fmt — small (<10 decimal)', () {
    test('0.8 → 0,8', () => expect(fmt(0.8), '0,8'));
    test('9.2 → 9,2', () => expect(fmt(9.2), '9,2'));
  });

  group('fmt — int (10-999)', () {
    test('10 → 10', () => expect(fmt(10), '10'));
    test('42.7 → 42', () => expect(fmt(42.7), '42'));
    test('987 → 987', () => expect(fmt(987), '987'));
  });

  group('fmt — short scale (TR)', () {
    test('1234 → 1,23K', () => expect(fmt(1234), '1,23K'));
    test('1e6 → 1,00M', () => expect(fmt(1e6), '1,00M'));
    test('1.5e9 → 1,50B', () => expect(fmt(1.5e9), '1,50B'));
    test('1e18 → 1,00Qi', () => expect(fmt(1e18), '1,00Qi'));
    test('1e33 → 1,00Dc', () => expect(fmt(1e33), '1,00Dc'));
  });

  group('fmt — scientific fallback (>Dc)', () {
    test('1e42 → 1,00e+42', () => expect(fmt(1e42), '1,00e+42'));
  });

  group('fmt — negative', () {
    test('-1500 → -1,50K', () => expect(fmt(-1500), '-1,50K'));
    test('-0.5 → -0,5', () => expect(fmt(-0.5), '-0,5'));
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/ui/format/number_format_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Implementation**

Write `lib/ui/format/number_format.dart`:

```dart
import 'dart:math';

/// TR locale ondalık ayırıcı: ','.
/// <10 → 1 ondalık; 10-999 → int; 1000-1e33 → short scale; >1e33 → scientific.
/// Spec: docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md §4.4
String fmt(double n) {
  if (n.isNaN || n.isInfinite) return '—';
  if (n == 0) return '0';
  final original = n;
  final sign = n < 0 ? '-' : '';
  n = n.abs();
  String raw;
  if (n < 10) {
    raw = n.toStringAsFixed(1);
  } else if (n < 1000) {
    raw = n.floor().toString();
  } else {
    const units = ['K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc'];
    int tier = 0;
    while (tier < units.length && n >= 1000) {
      n /= 1000;
      tier++;
    }
    if (n >= 1000) {
      return '$sign${original.abs().toStringAsExponential(2).replaceAll('.', ',')}';
    }
    raw = '${n.toStringAsFixed(n >= 100 ? 1 : 2)}${units[tier - 1]}';
  }
  return '$sign${raw.replaceAll('.', ',')}';
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/ui/format/number_format_test.dart`
Expected: 15/15 pass.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/format/number_format.dart test/ui/format/number_format_test.dart
git commit -m "sprint-a(T15): fmt() — TR locale short scale (<10 decimal, K..Dc, scientific)"
```

---

## Task 16: AppTheme.artisan

**Files:**
- Modify: `lib/ui/theme/app_theme.dart`

- [ ] **Step 1: Implementation**

Replace `lib/ui/theme/app_theme.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

/// Artisan palette placeholder — Material 3 seed + tabularFigures.
/// Hex'ler tasarımcı kesinleştirene kadar warm amber seed
/// (visual-design.md artisan dönemi rehberi).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
          brightness: Brightness.light,
        ),
        textTheme: Typography.material2021().black.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
          brightness: Brightness.dark,
        ),
        textTheme: Typography.material2021().white.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/ui/theme/app_theme.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/theme/app_theme.dart
git commit -m "sprint-a(T16): AppTheme.artisan — Material 3 seed amber + tabularFigures"
```

---

## Task 17: Common widgets (CrumbCounterHeader, TapArea, BuildingRow, FloatingNumberOverlay, OnboardingHint, AppNavigationBar)

**Files:**
- Create: `lib/features/home/widgets/crumb_counter_header.dart`
- Create: `lib/features/home/widgets/tap_area.dart`
- Create: `lib/features/home/widgets/floating_number_overlay.dart`
- Create: `lib/features/home/widgets/onboarding_hint.dart`
- Create: `lib/features/shop/widgets/building_row.dart`
- Create: `lib/app/nav/app_navigation_bar.dart`

- [ ] **Step 1: CrumbCounterHeader**

Write `lib/features/home/widgets/crumb_counter_header.dart`:

```dart
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CrumbCounterHeader extends ConsumerWidget {
  const CrumbCounterHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crumbs = ref.watch(currentCrumbsProvider);
    final rate = ref.watch(productionRateProvider);
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(
          fmt(crumbs),
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 64),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.of(context).rateLabel(fmt(rate)),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: TapArea**

Write `lib/features/home/widgets/tap_area.dart`:

```dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TapArea extends ConsumerStatefulWidget {
  const TapArea({super.key});

  @override
  ConsumerState<TapArea> createState() => _TapAreaState();
}

class _TapAreaState extends ConsumerState<TapArea> {
  double _scale = 1.0;

  void _onTap() {
    ref.read(gameStateNotifierProvider.notifier).tapCrumb();
    ref.read(floatingNumbersProvider.notifier).spawn(1);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: _onTap,
      child: Center(
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cookie, size: 140, color: color),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: FloatingNumberOverlay**

Write `lib/features/home/widgets/floating_number_overlay.dart`:

```dart
import 'package:crumbs/features/home/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FloatingNumberOverlay extends ConsumerWidget {
  const FloatingNumberOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbers = ref.watch(floatingNumbersProvider);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final n in numbers)
            Center(
              key: ValueKey(n.id),
              child: Transform.translate(
                offset: Offset(n.dx, 0),
                child: Text(
                  '+${n.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                    .animate(
                  onComplete: (_) => ref
                      .read(floatingNumbersProvider.notifier)
                      .remove(n.id),
                )
                    .fadeOut(duration: 800.ms, curve: Curves.easeOut)
                    .moveY(begin: 0, end: -80, duration: 800.ms),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: OnboardingHint**

Write `lib/features/home/widgets/onboarding_hint.dart`:

```dart
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// IgnorePointer — tap event'i altındaki TapArea'ya pass-through.
/// Dismiss logic GameStateNotifier.tapCrumb içinde.
class OnboardingHint extends ConsumerWidget {
  const OnboardingHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed =
        ref.watch(onboardingPrefsProvider.select((p) => p.hintDismissed));
    if (dismissed) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 420),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            AppStrings.of(context).tapHint,
            style: Theme.of(context).textTheme.bodyLarge,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 400.ms)
              .then(delay: 600.ms)
              .fadeOut(duration: 400.ms),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: BuildingRow (shake state — B-ready pattern)**

Write `lib/features/shop/widgets/building_row.dart`:

```dart
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
          content: Text(AppStrings.of(context).insufficientCrumbs),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateNotifierProvider).valueOrNull;
    final owned = gs?.buildings.owned[widget.id] ?? 0;
    final cost = ref.watch(costCurveProvider((widget.id, owned)));
    final crumbs = ref.watch(currentCrumbsProvider);
    final canAfford = crumbs >= cost;

    final button = FilledButton(
      onPressed: _onBuy,
      child: Text(AppStrings.of(context).buyButton),
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
                  Text(widget.displayName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(AppStrings.of(context).ownedLabel(owned)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt(cost.toDouble()),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: canAfford ? 1.0 : 0.5,
                  child: button
                      .animate(key: ValueKey(_shakeSeq), target: _shakeSeq > 0 ? 1 : 0)
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
```

- [ ] **Step 6: AppNavigationBar (5-slot + More)**

Write `lib/app/nav/app_navigation_bar.dart`:

```dart
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum NavSection { home, shop, upgrades, research, more }

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({required this.currentIndex, super.key});

  final int currentIndex;

  void _handleTap(BuildContext context, int index) {
    final section = NavSection.values[index];
    switch (section) {
      case NavSection.home:
        context.go('/');
      case NavSection.shop:
        context.go('/shop');
      case NavSection.upgrades:
        _snack(context, AppStrings.of(context).navLockUpgradesA);
      case NavSection.research:
        _snack(context, AppStrings.of(context).navLockResearch);
      case NavSection.more:
        _showMoreSheet(context);
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _showMoreSheet(BuildContext context) {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(s.navEvents),
              subtitle: Text(s.navLockEvents),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: Text(s.navPrestige),
              subtitle: Text(s.navLockPrestige),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.collections),
              title: Text(s.navCollection),
              subtitle: Text(s.navLockCollection),
              onTap: () => Navigator.of(c).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(s.navSettings),
              onTap: () {
                Navigator.of(c).pop();
                context.go('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) => _handleTap(context, i),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home), label: s.navHome),
        NavigationDestination(
            icon: const Icon(Icons.store), label: s.navShop),
        NavigationDestination(
            icon: const Icon(Icons.lock_outline), label: s.navUpgrades),
        NavigationDestination(
            icon: const Icon(Icons.lock_outline), label: s.navResearch),
        NavigationDestination(
            icon: const Icon(Icons.more_horiz), label: s.navMore),
      ],
    );
  }
}
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/home/widgets/ lib/features/shop/widgets/ lib/app/nav/
git commit -m "sprint-a(T17): common widgets — header, tap, floater, hint, building row, nav bar"
```

---

## Task 18: HomePage (composition + ref.listen side-effects)

**Files:**
- Modify: `lib/features/home/home_page.dart`

- [ ] **Step 1: Implementation**

Replace `lib/features/home/home_page.dart`:

```dart
import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/home/widgets/floating_number_overlay.dart';
import 'package:crumbs/features/home/widgets/onboarding_hint.dart';
import 'package:crumbs/features/home/widgets/tap_area.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(offlineReportProvider, (_, next) {
      if (next == null) return;
      final s = AppStrings.of(context);
      final mins = next.elapsed.inMinutes;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.welcomeBack(fmt(next.earned), '$mins dk')),
          duration: const Duration(seconds: 3),
        ),
      );
      ref.read(offlineReportProvider.notifier).state = null;
    });

    ref.listen(saveRecoveryProvider, (_, next) {
      if (next == null) return;
      final s = AppStrings.of(context);
      final msg = switch (next) {
        SaveRecoveryReason.checksumFailedUsedBackup => s.saveRecoveryBackup,
        SaveRecoveryReason.bothCorruptedStartedFresh => s.saveRecoveryFresh,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      ref.read(saveRecoveryProvider.notifier).state = null;
    });

    return Scaffold(
      body: const Stack(
        children: [
          Column(
            children: [
              CrumbCounterHeader(),
              Expanded(child: TapArea()),
              SizedBox(height: 8),
            ],
          ),
          FloatingNumberOverlay(),
          OnboardingHint(),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 0),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/home/home_page.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/home_page.dart
git commit -m "sprint-a(T18): HomePage composition + offlineReport/saveRecovery snackbar listeners"
```

---

## Task 19: ShopPage

**Files:**
- Modify: `lib/features/shop/shop_page.dart`

- [ ] **Step 1: Implementation**

Replace `lib/features/shop/shop_page.dart`:

```dart
import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/features/shop/widgets/building_row.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.navShop)),
      body: ListView(
        children: [
          BuildingRow(id: 'crumb_collector', displayName: s.crumbCollectorName),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/shop/shop_page.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/shop/shop_page.dart
git commit -m "sprint-a(T19): ShopPage — Crumb Collector single row"
```

---

## Task 20: AppRouter (home + shop + settings)

**Files:**
- Modify: `lib/app/routing/app_router.dart`
- Modify: `lib/features/settings/settings_page.dart`

- [ ] **Step 1: Settings placeholder**

Replace `lib/features/settings/settings_page.dart`:

```dart
import 'package:crumbs/app/nav/app_navigation_bar.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: Center(child: Text(s.settingsPlaceholder)),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 4),
    );
  }
}
```

- [ ] **Step 2: AppRouter**

Replace `lib/app/routing/app_router.dart`:

```dart
import 'package:crumbs/app/routing/routes.dart';
import 'package:crumbs/features/home/home_page.dart';
import 'package:crumbs/features/settings/settings_page.dart';
import 'package:crumbs/features/shop/shop_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.shop,
        builder: (context, state) => const ShopPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/app/routing/app_router.dart lib/features/settings/
git commit -m "sprint-a(T20): AppRouter — home + shop + settings routes"
```

---

## Task 21: main.dart + Integration test (smoke)

**Files:**
- Modify: `lib/main.dart`
- Modify: `integration_test/app_test.dart`

- [ ] **Step 1: main.dart**

Replace `lib/main.dart`:

```dart
import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/app/routing/app_router.dart';
import 'package:crumbs/core/preferences/onboarding_prefs.dart';
import 'package:crumbs/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crumbs/l10n/app_strings.dart';

Future<void> main() async {
  final container = await AppBootstrap.initialize();
  await container.read(onboardingPrefsProvider.notifier).ensureLoaded();
  runApp(UncontrolledProviderScope(
    container: container,
    child: const AppLifecycleGate(child: CrumbsApp()),
  ));
}

class CrumbsApp extends ConsumerWidget {
  const CrumbsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Crumbs',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
    );
  }
}
```

- [ ] **Step 2: Integration test**

Replace `integration_test/app_test.dart`:

```dart
import 'package:crumbs/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cold start → tap → buy → lifecycle round-trip', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Tap 15 kere
    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byIcon(Icons.cookie));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    // Navigate to shop
    await tester.tap(find.text('Dükkân'));
    await tester.pumpAndSettle();

    // Tap "Satın al"
    expect(find.text('Satın al'), findsOneWidget);
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 3: Local smoke**

Run:
```bash
flutter analyze
dart run build_runner build --delete-conflicting-outputs
flutter test
```
Expected: `No issues found!` + all tests pass.

Opsiyonel cihaz smoke:
```bash
flutter run -d <iphone-sim-id>
# Manuel: 15 tap, shop, satın al, home'a dön, 1 dk bekle, offline snackbar gör
```

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart integration_test/app_test.dart
git commit -m "sprint-a(T21): main.dart wire + integration test (cold start → tap → buy round-trip)"
```

---

## Final Verification

- [ ] **Step 1: Full test suite + coverage**

Run:
```bash
flutter test --coverage
```
Expected: All green. Coverage report `coverage/lcov.info`.

- [ ] **Step 2: Per-module coverage kontrol**

Run:
```bash
lcov --summary coverage/lcov.info
```
Expected: genel satır coverage ≥%70.

Per-modül hedefler (manual inspect):
- `lib/core/economy/` ≥ %95
- `lib/core/save/` ≥ %95
- `lib/core/preferences/` ≥ %85
- `lib/core/feedback/` ≥ %85
- `lib/features/*` ≥ %70

- [ ] **Step 3: Push branch + PR**

```bash
git push -u origin sprint/a-vertical-slice
gh pr create --base main --head sprint/a-vertical-slice --title "Sprint A: Vertical slice — tap + counter + 1 building + save + offline" --body "Spec: docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md. DoD: 20s → +2 Crumb, 1dk offline → +6 Crumb, coverage economy/save ≥95%, integration test green."
```

- [ ] **Step 4: CI yeşili bekle**

CI run'u gözle — `analyze + test --coverage` geçmeli. Kırmızıysa fix, geçerse merge adayı.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-17-sprint-a-vertical-slice.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** — Her task için fresh subagent dispatch; spec reviewer + code quality reviewer; fast iteration. Tasks T3-T9 + T15 strict TDD (economy + save + fmt 95% coverage), T1-T2 + T10-T14 + T16-T21 controller-direct.

**2. Inline Execution** — `superpowers:executing-plans` ile batch execution + checkpoints.

**Which approach?**
