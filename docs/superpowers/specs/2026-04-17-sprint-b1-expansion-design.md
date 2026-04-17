# Sprint B1 — Expansion Design

**Hedef:** Sprint A'nın vertical slice'ını genişlet — 3 bina, ilk upgrade sistemi (Golden Recipe I), typed SaveEnvelope + v1→v2 migration, 12h offline cap, Upgrades nav slotu aktif, AsyncError friendly screen.

**Sonraki:** Sprint B2 (Full FR-3 tutorial + telemetry wiring + 48dp accessibility audit). Sprint C (R2 Research Shards + 3 bina daha + Research Lab).

**Tarih:** 2026-04-17
**Referans:** `cookie_clicker_derivative_prd.md`, `docs/economy.md §4, §6`, `docs/upgrade-catalog.md §1`, `CLAUDE.md §6 (mimari kuralları), §8 (save migration)`

---

## 1. Kapsam

### 1.1 In Scope (B1)

- **3 bina Shop'ta görünür** (static visible pattern — Cookie Clicker convention):
  - `crumb_collector`: base 0.1 C/s, cost 15, growth 1.12
  - `oven`: base 1.0 C/s, cost 120, growth 1.12
  - `bakery_line`: base 8.0 C/s, cost 1,200, growth 1.13
- **1 upgrade** (`golden_recipe_i`): `globalMultiplier × 1.5`, cost 200 C, one-time purchase
- **Upgrade sistemi infrastructure:** `Effect` + `UpgradeDefs` + `MultiplierChain` (globalMultiplier layer implemented; diğer 6 katman 1.0 return eden placeholder)
- **Typed SaveEnvelope v2:** `gameState: Map<String, dynamic>` → `gameState: GameState` shape migration + yeni `upgrades: UpgradeState` field
- **SaveMigrator v1→v2:** disk'teki mevcut v1 save'leri yükle, `upgrades.owned={}` ile v2'ye taşı, yeniden yaz
- **Offline cap:** 24h → 12h (tek `const` değişimi)
- **Upgrades nav slotu:** lock kaldırılır, `/upgrades` route aktif
- **UpgradesPage:** BuildingRow pattern'ine paralel `UpgradeRow` widget + single-item list
- **ErrorScreen:** AsyncError fallback (path_provider/SharedPreferences fail gibi non-save hatalar için), `ref.invalidate` ile retry
- **Persist error visibility:** `unawaited(_persist)` → `catchError` + `debugPrint` ekleme (tüm 3 purchase yolu)

### 1.2 Out of Scope (B1)

- FR-3 tutorial (→ B2)
- Telemetry provider wiring (Firebase Analytics events) (→ B2)
- 48dp accessibility audit (→ B2)
- Crashlytics integration (→ B2 veya Sprint C)
- Upgrade-catalog.md'deki kalan 35 upgrade (→ C + sonrası)
- Research, Prestige, Events, Achievements (→ C + sonrası)
- `buildingSpecific` / `event` / `research` / `prestige` multiplier katmanları (layer stubs placeholder kalır)
- Repeat-purchasable upgrade desteği (Golden Recipe I one-time; gelecek requirement ayrı state field)
- No-ads IAP + rewarded ad integration (→ post-Sprint-C)

### 1.3 Design assumptions

- Sprint A PR (#2) merge sonrası B1 branch'i `main`'den çıkar. Ara branch bağımlılığı yok.
- economy.md §4 tek parametre kaynağıdır (CLAUDE.md §12). Sprint A'daki `crumb_collector` drift (10/1.15) B1'de düzeltilir — pre-release olduğu için save migration impact'i yok (cost save'de tutulmuyor).
- Sprint A'da shipped 21 task'ın altyapısı (Riverpod 3.1 NotifierProvider pattern, freezed 3 + explicit_to_json, AppLifecycleListener, SaveRepository race lock, canonical JSON + SHA-256 checksum) B1'de değişmez — üzerine inşa edilir.

---

## 2. Architecture

### 2.1 Yeni modüller

```
lib/core/economy/
├── effect.dart                          [YENİ]
│     └── EffectType enum (B1: globalMultiplier)
│     └── Effect const class (type, value)
├── upgrade_defs.dart                    [YENİ]
│     └── effectFor(id) → Effect
│     └── baseCostFor(id) → num
│     └── exists(id) → bool
├── multiplier_chain.dart                [stub → implemented]
│     └── globalMultiplier(Map<String, bool> owned) → double
└── production.dart                      [refactored]
      └── totalPerSecond(buildings, {globalMultiplier = 1.0})
      └── tickDelta(buildings, seconds, {globalMultiplier = 1.0})

lib/core/save/
├── upgrade_state.dart                   [YENİ]
│     └── UpgradeState freezed — owned: Map<String, bool>
├── save_envelope.dart                   [shape migration]
│     └── gameState: GameState (eskiden Map<String, dynamic>)
└── migrations/
      └── v1_to_v2.dart                  [YENİ]
            └── migrateV1ToV2(rawMap) — add upgrades + type-cast GameState

lib/features/upgrades/                   [YENİ dizin]
├── upgrades_page.dart
└── widgets/
      └── upgrade_row.dart

lib/app/error/                           [YENİ dizin]
└── error_screen.dart
```

### 2.2 Değişen dosyalar

| Dosya | Değişim |
|-------|---------|
| `lib/core/save/game_state.dart` | `upgrades: UpgradeState` field eklenir; `copyWith`/`fromJson` freezed regen |
| `lib/core/save/save_envelope.dart` | `gameState` typed GameState, version default 2 |
| `lib/core/save/save_migrator.dart` | `v1ToV2` migration zincirine eklenir |
| `lib/core/save/save_repository.dart` | `Checksum.of(env.gameState.toJson())` (2 yer — save + _tryRead) |
| `lib/core/economy/offline_progress.dart` | `compute({required buildings, required elapsed, double globalMultiplier = 1.0})` |
| `lib/core/state/game_state_notifier.dart` | `buyUpgrade(id)` action; tick/hydrate/resume'de MultiplierChain enjeksiyonu; `catchError` wrapper |
| `lib/features/shop/shop_page.dart` | 3 BuildingRow (oven, bakery_line eklendi) |
| `lib/app/nav/app_navigation_bar.dart` | `NavSection.upgrades` artık `/upgrades`'e push (lock snack yerine) |
| `lib/app/routing/app_router.dart` | `/upgrades` route eklenir |
| `lib/main.dart` | `async.when(data/loading/error)` branch — error → ErrorScreen |
| `lib/l10n/tr.arb` | `goldenRecipeIName`, `goldenRecipeIDescription`, `upgradeOwnedBadge`, `errorScreenTitle/Body/Retry` |

### 2.3 Data flow — upgrade satın alma

```
UpgradeRow.onBuy tap
    → GameStateNotifier.buyUpgrade('golden_recipe_i')
        → UpgradeDefs.exists? → UpgradeDefs.baseCostFor? → afford check
        → state = AsyncData(gs.copyWith(inventory, upgrades))
        → unawaited(_persist(updated).catchError(debugPrint))
    → productionRateProvider invalidate (gameState değişti)
        → MultiplierChain.globalMultiplier({'golden_recipe_i': true}) = 1.5
        → Production.totalPerSecond(buildings, globalMultiplier: 1.5) → yeni C/s
    → CrumbCounterHeader rebuild → fmt(newRate) render
```

### 2.4 Critical invariants (Sprint A'dan sürdürülüyor + yeni)

Sprint A'dan:
1. OfflineReport yalnızca cold start; applyResumeDelta sessiz
2. saveRecoveryProvider aynı kural
3. `_lastTickAt` Timer spawn'dan ÖNCE set
4. Tick + cold hydrate + hot resume tek formül: `Production.tickDelta`
5. Haptic fire-and-forget, non-blocking

B1 yeni invariant'lar:
6. **Tek-kaynak multiplier:** Production.totalPerSecond / tickDelta sadece `globalMultiplier` parametresi kabul eder; upgrade ID'lerine erişemez — MultiplierChain'den geçmek zorunludur (CLAUDE.md §6/6)
7. **Chain enjeksiyonu 3 site'ta aynı pattern:** `MultiplierChain.globalMultiplier(gs.upgrades.owned)` → `Production.*` parametresi. Sapma olursa test başarısız.
8. **UpgradeState pure bool map:** `owned[id] == true` purchase marker; `false` ve absent semantik olarak denk (test'te iki durum da assert edilir)
9. **Migration idempotency:** v1→v2 sonrası re-migration aynı state'i verir (test pin'li)
10. **applyResumeDelta upgrade preserve:** pause/resume boyunca `gs.upgrades.owned` mutate olmaz (Sprint A invariant testine assert eklenir)

---

## 3. Data Model

### 3.1 UpgradeState (yeni freezed class)

```dart
// lib/core/save/upgrade_state.dart
@freezed
abstract class UpgradeState with _$UpgradeState {
  const factory UpgradeState({
    @Default(<String, bool>{}) Map<String, bool> owned,
  }) = _UpgradeState;

  factory UpgradeState.fromJson(Map<String, dynamic> json) =>
      _$UpgradeStateFromJson(json);
}
```

**Semantik:**
- `owned[id] == true` → satın alınmış
- `owned[id] == false` ve `absent` → henüz satın alınmamış
- B1'de one-time purchase only; `false` durumu pratikte görülmez ama fromJson tolere eder
- Repeat-purchasable upgrade (level-based) gelecekte ayrı field (`levels: Map<String, int>`)

### 3.2 GameState (değişim)

```dart
@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    // ...existing fields (meta, run, inventory, buildings)
    @Default(UpgradeState()) UpgradeState upgrades,   // ← YENİ
  }) = _GameState;
  ...
}
```

### 3.3 SaveEnvelope (shape migration)

**Öncesi:**
```dart
const factory SaveEnvelope({
  required int version,
  required String lastSavedAt,
  required Map<String, dynamic> gameState,   // raw map
  required String checksum,
}) = _SaveEnvelope;
```

**Sonrası:**
```dart
const factory SaveEnvelope({
  required int version,
  required String lastSavedAt,
  required GameState gameState,              // typed
  required String checksum,
}) = _SaveEnvelope;
```

- `SaveEnvelope.fromJson` artık `GameState.fromJson(json['gameState'])` çağırır — malformed data burada fail eder, `_tryRead`'in try/catch'i yakalar
- `SaveEnvelope.toJson` otomatik `gameState.toJson()` üretir (json_serializable)
- Checksum: `Checksum.of(env.gameState.toJson())` — 2 call site (`save`, `_tryRead`)

### 3.4 SaveMigrator v1→v2

```dart
// lib/core/save/migrations/v1_to_v2.dart

/// v1 → v2 migration (combined shape + upgrades addition).
///
/// Idempotent: rawMap içinde `upgrades` zaten varsa korunur.
Map<String, dynamic> migrateV1ToV2(Map<String, dynamic> rawGameState) {
  final copy = Map<String, dynamic>.from(rawGameState);
  copy.putIfAbsent('upgrades', () => {'owned': <String, bool>{}});
  return copy;
}
```

**SaveMigrator.migrate** zincirine:
```dart
if (env.version == 1) {
  final migratedMap = migrateV1ToV2(rawGameState);   // raw hala Map
  final typedGameState = GameState.fromJson(migratedMap);
  return SaveEnvelope(
    version: 2,
    lastSavedAt: env.lastSavedAt,
    gameState: typedGameState,
    checksum: Checksum.of(typedGameState.toJson()),
  );
}
```

**Not:** Migration typed envelope'a çıkarken raw map'ten tek seferlik geçiş yapar. Disk'ten okuma path'i:

```
diskJSON (Map) → SaveEnvelope.fromJson
  ├── version == 2 → typed GameState directly
  └── version == 1 → _upgradeV1Envelope (internal helper): rawMap handling +
      GameState.fromJson after putIfAbsent('upgrades')
```

Bu detay plan'da netleşecek (migration path typed envelope entry point'i ile çakışmaması için).

---

## 4. Economy Layer

### 4.1 Effect class

```dart
// lib/core/economy/effect.dart
enum EffectType { globalMultiplier }

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

- Düz const class (freezed overkill; yalnız value equality + readable)
- B1'de tek type; B2/C'de enum'a entry eklenir

### 4.2 UpgradeDefs

```dart
// lib/core/economy/upgrade_defs.dart
class UpgradeDefs {
  const UpgradeDefs._();

  /// Tablo-içi id için gerçek Effect; tanımsız id için no-op sentinel
  /// (globalMultiplier × 1.0).
  ///
  /// Defensive contract: GameStateNotifier.buyUpgrade(id), UpgradeDefs.exists(id)
  /// ile gate eder; MultiplierChain de exists() kontrolü yapar — tanımsız id
  /// Map<String, bool> owned'a normal yoldan giremez.
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

### 4.3 MultiplierChain

```dart
// lib/core/economy/multiplier_chain.dart
class MultiplierChain {
  const MultiplierChain._();

  /// Global upgrade multiplier — satın alınmış upgrade'lerin
  /// globalMultiplier tip'indeki etkilerini çarparak birleştirir.
  ///
  /// economy.md §6 layer sequence — bu method katman 4 (global_multiplier).
  /// Diğer katmanlar (buildingSpecific, event, research, prestige) B1 scope
  /// dışı; şu an 1.0 dönen method stub'ları eklenmez — YAGNI.
  static double globalMultiplier(Map<String, bool> owned) {
    var multiplier = 1.0;
    owned.forEach((id, isOwned) {
      if (!isOwned) return;
      if (!UpgradeDefs.exists(id)) return;   // defensive: unknown skip
      final effect = UpgradeDefs.effectFor(id);
      if (effect.type == EffectType.globalMultiplier) {
        multiplier *= effect.value;
      }
    });
    return multiplier;
  }
}
```

### 4.4 Production refactor

```dart
// lib/core/economy/production.dart
class Production {
  // ...existing baseProductionFor, baseCostFor, growthFor

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

  static double tickDelta(
    Map<String, int> buildings,
    double seconds, {
    double globalMultiplier = 1.0,
  }) =>
      totalPerSecond(buildings, globalMultiplier: globalMultiplier) * seconds;
}
```

**Backward-compat:** `globalMultiplier` named param default `1.0` → Sprint A'nın mevcut test ve call-site'ları kırılmaz (ya da aynı testlerde refactor yapılır — tercih plan aşamasında).

### 4.5 OfflineProgress refactor

```dart
static OfflineReport compute({
  required Map<String, int> buildings,
  required Duration elapsed,
  double globalMultiplier = 1.0,
});
```

Internal: `Production.tickDelta(buildings, seconds, globalMultiplier: ...)` — tek code path (Sprint A invariant korunuyor).

### 4.6 economy.md §4 senkronizasyonu

`Production` data switch'leri:

```dart
static double baseProductionFor(String id) => switch (id) {
      'crumb_collector' => 0.1,
      'oven' => 1.0,
      'bakery_line' => 8.0,
      _ => 0,
    };

static num baseCostFor(String id) => switch (id) {
      'crumb_collector' => 15,              // ← 10 idi
      'oven' => 120,
      'bakery_line' => 1200,
      _ => 0,
    };

static double growthFor(String id) => switch (id) {
      'crumb_collector' => 1.12,            // ← 1.15 idi
      'oven' => 1.12,
      'bakery_line' => 1.13,
      _ => 1.0,
    };
```

**B2 follow-up:** Sprint A pre-release olduğu için numerical drift'ten kullanıcı etkilenmiyor; ama **post-release** değişikliklerinde `purchase_funnel_building_1` telemetry'de funnel dip izlenmeli — "2 min to first building" (NFR-1) regression varsa revert candidate.

---

## 5. State Layer

### 5.1 GameStateNotifier.buyUpgrade

```dart
Future<bool> buyUpgrade(String id) async {
  final gs = state.value;
  if (gs == null) return false;
  if (!UpgradeDefs.exists(id)) return false;
  if (gs.upgrades.owned[id] == true) return false;   // idempotent
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

### 5.2 Chain injection — 3 site

**Tick (`_onTick`):**
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
    gs.buildings.owned, seconds, globalMultiplier: multiplier,
  );
  if (delta <= 0) return;

  state = AsyncData(gs.copyWith(
    inventory: gs.inventory.copyWith(
      r1Crumbs: gs.inventory.r1Crumbs + delta,
    ),
  ));
}
```

**Cold hydrate (`build`):**
```dart
final multiplier = MultiplierChain.globalMultiplier(restored.upgrades.owned);
final offline = OfflineProgress.compute(
  buildings: restored.buildings.owned,
  elapsed: elapsed,
  globalMultiplier: multiplier,
);
```

**Hot resume (`applyResumeDelta`):**
```dart
final multiplier = MultiplierChain.globalMultiplier(gs.upgrades.owned);
final delta = Production.tickDelta(
  gs.buildings.owned, seconds, globalMultiplier: multiplier,
);
```

### 5.3 Persist error visibility

Sprint A'nın `tapCrumb` + `buyBuilding` metodları da aynı `.catchError` + `debugPrint` pattern'ine çekilir (B1 Task #12 cleanup — tek commit).

---

## 6. UI Layer

### 6.1 UpgradeRow widget

BuildingRow pattern'inin upgrade versiyonu:

```dart
class UpgradeRow extends ConsumerStatefulWidget {
  const UpgradeRow({required this.id, required this.displayName, super.key});
  final String id;
  final String displayName;
  // ...state extends ConsumerState
}

class _UpgradeRowState extends ConsumerState<UpgradeRow> {
  int _shakeSeq = 0;

  Future<void> _onBuy() async { /* buyUpgrade(id) → shake on fail */ }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateNotifierProvider).value;
    final owned = gs?.upgrades.owned[widget.id] ?? false;
    final cost = UpgradeDefs.baseCostFor(widget.id);
    final crumbs = ref.watch(currentCrumbsProvider);
    final canAfford = crumbs >= cost;

    return Card(child: Padding(child: Row(children: [
      // left: displayName + description ("Global üretim ×1.5")
      // right: cost (if not owned) OR "Sahip ✓" badge (if owned)
      //        Buy button with shake animation (BuildingRow pattern)
    ])));
  }
}
```

**Owned state UI:**
- `owned == true` → button yerine `Chip(label: Text(AppStrings.of(context)!.upgradeOwnedBadge))` + cost text invisible
- `owned == false` → BuildingRow'daki button pattern (affordable opacity + shake)

### 6.2 UpgradesPage

```dart
class UpgradesPage extends StatelessWidget {
  const UpgradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.navUpgrades)),
      body: ListView(children: [
        UpgradeRow(
          id: 'golden_recipe_i',
          displayName: s.goldenRecipeIName,
        ),
      ]),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
    );
  }
}
```

### 6.3 AppNavigationBar — unlock Upgrades slot

`_handleTap` içinde `case NavSection.upgrades:` artık snack yerine `context.go('/upgrades')`.

**Icon:** `Icons.lock_outline` → `Icons.auto_awesome` (upgrade semantiği)

### 6.4 ShopPage — 3 bina listele

```dart
body: ListView(children: [
  BuildingRow(id: 'crumb_collector', displayName: s.crumbCollectorName),
  BuildingRow(id: 'oven', displayName: s.ovenName),
  BuildingRow(id: 'bakery_line', displayName: s.bakeryLineName),
]),
```

### 6.5 AppRouter

```dart
GoRoute(
  path: Routes.upgrades,
  builder: (context, state) => const UpgradesPage(),
),
```

---

## 7. ErrorScreen

### 7.1 Widget

```dart
// lib/app/error/error_screen.dart
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
              Text(s.errorScreenTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(s.errorScreenBody,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.invalidate(gameStateNotifierProvider),
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

### 7.2 main.dart wiring

```dart
class CrumbsApp extends ConsumerWidget {
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
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: ErrorScreen(error: e),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
      ),
    );
  }
}
```

### 7.3 Loop guard — gerekmiyor

Corruption senaryoları Sprint A'da `_tryRead` + Checksum + `.bak` fallback + `bothCorruptedStartedFresh` → `saveRecoveryProvider` snack zincirinde zaten absorbe olur. AsyncError yalnızca path_provider / SharedPreferences init / Flutter binding gibi non-save dış hatalarda tetiklenir — bunlar genelde transient. Retry makul.

B2 follow-up: gerçek hayatta AsyncError loop görülürse `retryCount` state + "Contact support" fallback.

---

## 8. Testing Strategy

### 8.1 Unit test matrisi

| Test dosyası | Test count | Konu |
|--------------|-----------|------|
| `test/core/economy/effect_test.dart` | 3 | Effect equality + hashCode |
| `test/core/economy/upgrade_defs_test.dart` | 6 | effectFor/baseCostFor/exists — known + unknown |
| `test/core/economy/multiplier_chain_test.dart` | 7 | empty, single, multi, owned=false, unknown defensive, 3-way multiplicative |
| `test/core/economy/production_test.dart` | +9 | economy.md §4 tablosu assert (oven, bakery_line, updated collector) + globalMultiplier injection (before/after) |
| `test/core/economy/offline_progress_test.dart` | +2 | globalMultiplier 1.0 (backward-compat) + 1.5 (delta scaling) |
| `test/core/save/upgrade_state_test.dart` | 3 | default empty, roundtrip, fromJson with owned entries |
| `test/core/save/game_state_test.dart` | +2 | upgrades default + copyWith preserve |
| `test/core/save/save_envelope_test.dart` | +2 | typed gameState roundtrip + v2 default |
| `test/core/save/save_migrator_test.dart` | +5 | v1→v2 happy, idempotent, malformed v1 parse fail, partial v1 (missing buildings), disk v1→v2 via SaveRepository |
| `test/core/save/save_repository_test.dart` | +2 | v1 disk file → v2 load path; re-save after migration writes v2 |
| `test/core/state/game_state_notifier_test.dart` | +6 | buyUpgrade (happy, insufficient, unowned, unknown, already owned) + chain injection in 3 sites + upgrade preserve across resume |
| `test/features/upgrades/upgrade_row_test.dart` | 3 | button enabled/disabled by affordability, shake on fail, badge on owned |
| `test/features/upgrades/upgrades_page_test.dart` | 1 | page smoke — tek row render |
| `test/app/error/error_screen_test.dart` | 2 | render + retry invalidates provider |

**Yeni + güncelleme toplamı: ~55 test** (Sprint A sonrası 84 → B1 sonrası ~139).

### 8.2 Integration test (update)

`integration_test/app_test.dart` — cold start → tap → buy → upgrade round-trip:

```dart
testWidgets('cold start → tap → buy building → buy upgrade', (tester) async {
  await app.main();
  await tester.pumpAndSettle();

  // 1 Crumb Collector alabilmek için 15 C gerekir
  for (var i = 0; i < 20; i++) {
    await tester.tap(find.byIcon(Icons.cookie));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();

  // Shop → Collector satın al
  await tester.tap(find.byIcon(Icons.store));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();

  // ~200 C biriktir (collector passive + taps)
  for (var i = 0; i < 200; i++) {
    await tester.tap(find.byIcon(Icons.cookie));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();

  // Upgrades → Golden Recipe I satın al
  await tester.tap(find.byIcon(Icons.auto_awesome));
  await tester.pumpAndSettle();
  expect(find.byType(UpgradeRow), findsOneWidget);
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();

  // Production rate provider assertion — 1 Collector × 1.5 = 0.15 C/s
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CrumbCounterHeader)),
  );
  expect(container.read(productionRateProvider), closeTo(0.15, 1e-9));
});
```

Not: "200 tap ile 200 C birikir" yaklaşımı 50ms pump ile gerçek test süresini 10+ sn yapar; alternatif: test container'a `GameStateNotifier.applyProductionDelta(200)` inject ile short-circuit. Plan aşamasında kararlaştırılır.

### 8.3 Coverage hedefleri (Sprint A ile aynı)

- `lib/core/economy/` ≥ %95
- `lib/core/save/` ≥ %95
- `lib/core/state/` ≥ %85
- `lib/features/*` ≥ %70
- `lib/app/error/` ≥ %80 (ErrorScreen için)

### 8.4 Invariant tests

Sprint A invariant bundle'ına eklenecek:
- "upgrade satın alma → state.upgrades.owned.id=true → productionRateProvider'daki multiplier yeni değer" (chain injection end-to-end)
- "resume öncesi ve sonrası upgrades.owned aynı" (applyResumeDelta preserve)
- "migration v1→v2 deterministic — aynı v1 input her zaman aynı v2 output"

---

## 9. Task Breakdown + Execution Order

### 9.1 Dependency chain

```
#1 (economy.md sync) ─┐
#2 (Effect)            ├─► #3 (UpgradeDefs) ─► #4 (MultiplierChain)
                       │                                       │
                       ▼                                       ▼
                     #5 (Production refactor) ─────► #6 (OfflineProgress refactor)
                                                              │
#7 (UpgradeState) ─► #8 (GameState.upgrades)                  │
                             │                                │
                             ▼                                │
                           #9 (SaveEnvelope typed) ─► #10 (SaveMigrator v1→v2)
                                                              │
                                                              ▼
                                                      #11 (Notifier buyUpgrade + chain)
                                                              │
                   ┌──────────────────────────────────────────┤
                   │                                          │
                   ▼                                          ▼
               #12 (catchError)                          Parallel UI:
               #13 (cap 12h)                             #14 (l10n)
               #18 (ErrorScreen + main.dart)             #15 (UpgradeRow)
                                                         #16 (UpgradesPage + route + nav)
                                                         #17 (ShopPage 3 bina)
                                                              │
                                                              ▼
                                                         #19 (integration test)
```

### 9.2 Task list

| # | Task | S/C | Critical | Dosya(lar) |
|---|------|-----|----------|-----------|
| 1 | Economy.md senkronizasyonu (Production data + testler) | **S** | | `production.dart`, `production_test.dart` |
| 2 | Effect class + EffectType enum + test | S | | `effect.dart`, `effect_test.dart` |
| 3 | UpgradeDefs catalog + testler | **S** | | `upgrade_defs.dart`, `upgrade_defs_test.dart` |
| 4 | MultiplierChain.globalMultiplier + testler | **S** | | `multiplier_chain.dart`, `multiplier_chain_test.dart` |
| 5 | Production refactor: globalMultiplier param | **S** | | `production.dart`, test update |
| 6 | OfflineProgress refactor: globalMultiplier param | **S** | | `offline_progress.dart`, test update |
| 7 | UpgradeState freezed + roundtrip test | **S** | | `upgrade_state.dart` |
| 8 | GameState.upgrades field + copyWith/roundtrip tests | **S** | ★ | `game_state.dart`, test update |
| 9 | SaveEnvelope typed gameState + Checksum.toJson rewrite | **S** | ★ | `save_envelope.dart`, `save_repository.dart` |
| 10 | SaveMigrator v1→v2 (combined) + idempotency + disk path tests | **S** | ★ | `migrations/v1_to_v2.dart`, `save_migrator.dart`, tests |
| 11 | GameStateNotifier.buyUpgrade + chain 3-site + invariant test | **S** | ★ | `game_state_notifier.dart`, `game_state_notifier_test.dart` |
| 12 | Persist catchError + debugPrint (tap + buyBuilding + buyUpgrade) | C | | `game_state_notifier.dart` |
| 13 | Offline cap 24h → 12h + test threshold | C | | `offline_progress.dart` |
| 14 | l10n strings: upgrade + error screen + building names | C | | `tr.arb` |
| 15 | UpgradeRow widget | C | | `features/upgrades/widgets/upgrade_row.dart` |
| 16 | UpgradesPage + `/upgrades` route + nav slot unlock | C | | `upgrades_page.dart`, `app_router.dart`, `app_navigation_bar.dart` |
| 17 | ShopPage 3 BuildingRow (oven + bakery_line eklendi) | C | | `shop_page.dart` |
| 18 | ErrorScreen + main.dart `async.when` wiring + test | **S** | ★ | `error_screen.dart`, `main.dart` |
| 19 | Integration test update + productionRateProvider assertion | C | | `integration_test/app_test.dart` |

**Toplam: 19 task.**

★ = critical: spec reviewer + code quality reviewer zorunlu, invariant impact var.

### 9.3 Execution modu

- **S-strict TDD (subagent-driven):** #1, #3, #4, #5, #8, #9, #10, #11, #18
- **S (subagent TDD, normal):** #2, #6, #7
- **C (controller-direct):** #12, #13, #14, #15, #16, #17, #19
- **Final cross-cutting review** branch bütününe (Sprint A ile aynı pattern)

### 9.4 Branch strategy

- Branch: `sprint/b1-expansion` (main'den)
- Ön-koşul: Sprint A PR (#2) merge edilmiş veya `sprint/a-vertical-slice` tip'inden çıkabilir
- PR başlığı: "Sprint B1: 3 buildings + Golden Recipe I + v2 save migration + error screen"

---

## 10. Definition of Done

### 10.1 Quality gates (hard)

- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test --coverage` → tüm modül coverage hedefleri karşılanır
- [ ] `flutter test integration_test/app_test.dart` → pass
- [ ] Her critical task (★) iki-aşamalı review (spec + code quality) ✅
- [ ] Final cross-cutting review ✅
- [ ] Sprint A invariant bundle regression'sız (83/83 testler geçmeye devam eder)

### 10.2 Functional smoke

- [ ] **Cold boot:** Fresh install → Home ekranı → 3 bina Shop'ta görünür (Collector affordable, diğerleri gray)
- [ ] **Upgrade visibility:** Upgrades tab unlock'lu (auto_awesome icon, snack yok) → Golden Recipe I listelenir
- [ ] **Upgrade purchase:** 200 C biriktir → Golden Recipe I satın al → "Sahip ✓" badge görünür → `productionRateProvider` 1 Collector için 0.1 → 0.15 değişir
- [ ] **Offline cap:** 13 saat kill → resume → OfflineReport `elapsed == 12h` (capped) — telemetry alanı B2'de bağlanacak; DoD'da assertion test'te
- [ ] **Save migration:** v1 formatında manuel hazırlanmış JSON dosyası disk'e yaz → app cold start → v2 dosyası disk'te, upgrades alanı `{owned: {}}`, game state kaybı yok
- [ ] **Error screen:** `AppBootstrap.initialize` test'te `Future.error` injection ile throw → ErrorScreen render → "Tekrar dene" tap → `ref.invalidate(gameStateNotifierProvider)` → tekrar deneniyor

### 10.3 Non-functional

- [ ] **NFR-1 (responsive):** Tap → counter update < 100 ms (Sprint A hâlâ geçiyor)
- [ ] **NFR-2 (save robustness):** Sprint A checksum verify + byte-flip test hâlâ yeşil
- [ ] **Progression:** affordability tempo unit testler ile pinlenmiş; playtest tempo doğrulama post-merge

### 10.4 Documentation

- [ ] `CLAUDE.md §12` gotcha'larına "B1 numerical drift: Crumb Collector cost 10→15" notu
- [ ] `docs/save-format.md §5` migration chain docunda v1→v2 entry
- [ ] `docs/economy.md` senkronize (post-B1 gerçek values)

---

## 11. Risks + Mitigations

| Risk | Olasılık | Etki | Mitigasyon |
|------|----------|------|------------|
| SaveEnvelope shape migration bozuk (typed geçişi GameState.fromJson'u tetikler, eski saves fail edebilir) | Orta | Yüksek (data loss) | v1→v2 migration testi: v1 raw JSON → v2 envelope; idempotency; bad-v1 graceful degrade (.bak fallback) |
| MultiplierChain floating-point drift | Düşük | Orta (numerical jitter) | Unit test `closeTo(expected, 1e-12)`; integration test `closeTo(0.15, 1e-9)` |
| Sprint A numeric drift (Crumb Collector cost 10→15) oyuncu surpriseı | Düşük | Düşük (pre-release) | B2'de telemetry `purchase_funnel_building_1` funnel dip izle; regression → revert candidate |
| Paralel purchase (tap + upgrade aynı frame'de) race | Düşük | Orta | `SaveRepository._pending` while-loop zaten serialize (Sprint A T9) — test'te concurrent buy fire-and-forget verified |
| ErrorScreen retry loop (non-save exception recurring) | Düşük | Düşük | B1 scope dışı; gerçek hayatta görülürse B2 `retryCount` guard |
| Integration test flakiness (200 tap with 50ms pump → 10 sn) | Orta | Düşük (CI time) | `applyProductionDelta` inject ile short-circuit; alternatif plan'da kararlaştırılır |

---

## 12. Followups (B2 ve sonrası)

- Full FR-3 tutorial (3-step, skip, first-session gate, telemetry events)
- Telemetry provider wiring (Firebase Analytics, event map)
- `tutorial_started`, `tutorial_step_complete`, `tutorial_skipped`, `tutorial_complete` event emission
- 48dp accessibility audit (BuildingRow, UpgradeRow, nav items, TapArea)
- Firebase Crashlytics entegrasyonu
- `saveFailureProvider` (structured persist error signaling beyond debugPrint)
- `purchase_funnel_building_1` telemetry dashboard — Crumb Collector cost regression izleme
- Unused scaffold stub cleanup (`home_controller.dart`, `shop_controller.dart`)
- AsyncError retry loop guard (real-world trigger varsa)
- `buildingSpecific`, `event`, `research`, `prestige` multiplier katmanları (C + sonrası)

---

## 13. Handoff

Spec onaylandıktan sonra `writing-plans` skill'i ile implementation plan yazılır. Plan branch'i `sprint/b1-expansion` olarak oluşturulur, 19 task TDD + subagent-driven akışla execute edilir.
