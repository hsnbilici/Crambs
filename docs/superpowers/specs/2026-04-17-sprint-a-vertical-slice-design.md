# Sprint A — Vertical Slice Design

**Tarih:** 2026-04-17
**Kapsam:** Project Crumbs'ın ilk oynanabilir dilimi — tıkla, sayaç artsın, bina al, kaydet, offline kazancı al.
**Önkoşul:** Scaffold PR merged (commit `94ae7dd`); 13 doc + Flutter iskelet hazır.
**Sonraki:** Sprint B (3 bina, 1 upgrade, offline cap 12h), sonra Sprint C (Research + R2 unlock).

---

## 1. Hedef ve Kabul Kriterleri

### Hedef
En küçük bitmiş idle oyun döngüsü: **tap → R1 kazan → Crumb Collector al → pasif üretim başlasın → kaydet → kapatıp aç, offline kazancı al**. Sonunda kullanıcı 5 dakika oynayıp "bu gerçek bir oyun" hissini almalı.

### Kapsam İÇİ
- **R1 (Crumbs)** tek kaynak; start value `0`
- **Tap loop:** Home'da büyük tap alanı → `+1` Crumb; light haptic (80ms throttle); `+1` floating number animation (800ms fade+rise, ±20px X jitter)
- **Tek bina:** Crumb Collector (`economy.md §2` birebir — base_cost `10`, base_production `0.1 C/s`, growth `1.15`)
- **Shop ekranı:** tek satır "Crumb Collector" (isim + owned count + cost + satın al butonu)
- **Passive tick:** 200ms `Timer.periodic`, gerçek elapsed time (`DateTime.now()` delta), drift-free
- **5-slot alt nav + More overflow** (ux-flows.md §3.1'e birebir uyum): Home ✓, Shop ✓, Upgrades 🔒, Research 🔒, More ✓ (Events 🔒, Prestige 🔒, Collection 🔒, Settings placeholder)
- **Number format:** `<10` → 1 ondalık; `10-999` → int; `1000+` → short scale K/M/B/T/Qa/Qi/Sx/Sp/Oc/No/Dc; `>Dc` → bilimsel gösterim; TR locale ondalık ayırıcı `,`
- **Save:** atomic write (tmp→rename), SHA-256 checksum (canonical JSON), 30s auto-save + app lifecycle (paused/detached) save + purchase-sonrası sync save
- **Offline progress:** açılışta `now − meta.lastSavedAt` delta × `Production.totalPerSecond`; sayaca eklenir; snackbar "Yokken X Crumb kazandın (Y dk)"; cap `Duration(hours: 24)` (A: makul — shock-value yok; B'de 12h)
- **Inline onboarding hint:** ilk açılışta overlay "Cupcake'e dokun, Crumbs kazan"; 1 tap sonrası dismiss + persist (SharedPreferences)
- **Visual-design.md artisan palette wire:** Material 3 `ColorScheme.fromSeed(Color(0xFFE8A53C))` placeholder warm amber; `tabularFigures` display typography
- **SaveEnvelope tam impl:** freezed 3.x `abstract class`, migration interface v1 no-op (framework hazır)
- **L10n (gen-l10n + intl):** `lib/l10n/tr.arb` tek locale, `AppStrings.of(context).*` pattern; tüm UI string'leri ARB'dan

### Kapsam DIŞI
- Diğer 7 bina; upgrade'ler; research nodes; event spawn; prestige; achievements; collection; session recap modal
- Firebase analytics (flutterfire configure ayrı runbook)
- Rewarded ad; no-ads IAP
- Settings ekranının gerçek davranışı (placeholder kalır)
- Tam FR-3 tutorial (Sprint B)
- Accessibility 48dp minimum tap hedefi audit (Sprint B)
- AsyncError friendly error screen (default Flutter red A'da kabul, Sprint B)
- `.tmp` orphan recovery (iOS/Android atomic rename garanti; skip)

### Bitti Tanımı
- [ ] `flutter run` iOS sim → tap → sayaç artıyor, floating `+1` animasyonu oynuyor, haptic hissediliyor
- [ ] Shop → 10 Crumb topladıktan sonra 1 Collector satın alınıyor; yetersiz Crumb'da button dimmed görünür, tap'te shake + "Yetersiz Crumb" tooltip 2s
- [ ] 1 Collector ile **20 saniyede +2 Crumb** birikiyor (pasif, UI smooth ilerliyor)
- [ ] Uygulama kapatıp **1 dakika** sonra açılınca sayaç `~+6` daha yüksek + welcome-back snackbar
- [ ] `flutter test` yeşil; `lib/core/economy/` + `lib/core/save/` modüllerinde **≥%95 line** coverage
- [ ] `flutter analyze` → `No issues found!`
- [ ] CI yeşil, PR merge edilebilir
- [ ] Integration test: tap, buy, lifecycle pause, save round-trip, resume — hepsi geçer

---

## 2. Mimari ve Veri Modeli

### 2.1 Modül sınırları (CLAUDE.md §6 ile birebir)

```
lib/
├── core/
│   ├── economy/          → saf fonksiyonlar: CostCurve, Production, OfflineProgress
│   ├── save/             → SaveEnvelope, SaveRepository, SaveMigrator, Checksum
│   ├── state/            → GameStateNotifier (AsyncNotifier — cross-feature)
│   ├── preferences/      → OnboardingPrefs (SharedPreferences)
│   ├── feedback/         → OfflineReport, SaveRecoveryReason (UI signal taşıma)
│   ├── progression/      → unchanged (A'da prerequisite yok)
│   └── events/           → unchanged (A'da event yok)
├── features/
│   ├── home/             → HomePage, HomeController, FloatingNumberOverlay, OnboardingHint
│   └── shop/             → ShopPage, BuildingRow
├── app/
│   ├── boot/             → AppBootstrap (pre-hydration saf servis)
│   ├── lifecycle/        → AppLifecycleGate (WidgetsBindingObserver wrapper)
│   └── routing/          → AppRouter (home + shop routes), Routes sabitleri
├── ui/
│   ├── theme/            → AppTheme.artisan (Material 3 seed + tabularFigures)
│   ├── format/           → fmt() number formatter (TR locale)
│   └── components/       → (empty in A — bileşenler features altında)
└── l10n/                 → tr.arb (tek locale), AppStrings codegen çıktı
```

**Import yönü (zorunlu):** `features/ → core/` ✓; `core/` hiçbir şey import etmez; `ui/` bağımsız; `app/` → `core/ + features/`.

### 2.2 GameState — 3'lü freezed

`lib/core/save/game_state.dart`:

```dart
@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    required MetaState meta,
    required InventoryState inventory,
    required BuildingsState buildings,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) => _$GameStateFromJson(json);

  factory GameState.initial({DateTime? now, String? installId}) => GameState(
    meta: MetaState(
      lastSavedAt: (now ?? DateTime.now()).toIso8601String(),
      schemaVersion: 1,
      installId: installId ?? const Uuid().v4(),
    ),
    inventory: const InventoryState(r1Crumbs: 0),
    buildings: const BuildingsState(owned: {}),
  );
}

@freezed
abstract class MetaState with _$MetaState {
  const factory MetaState({
    required String lastSavedAt,     // ISO 8601
    required int schemaVersion,
    required String installId,       // UUID v4, ilk kurulumda üretilir
  }) = _MetaState;
  factory MetaState.fromJson(Map<String, dynamic> j) => _$MetaStateFromJson(j);
}

@freezed
abstract class InventoryState with _$InventoryState {
  const factory InventoryState({
    required double r1Crumbs,
  }) = _InventoryState;
  factory InventoryState.fromJson(Map<String, dynamic> j) => _$InventoryStateFromJson(j);
}

@freezed
abstract class BuildingsState with _$BuildingsState {
  const factory BuildingsState({
    required Map<String, int> owned,  // key: building id (örn. 'crumb_collector')
  }) = _BuildingsState;
  factory BuildingsState.fromJson(Map<String, dynamic> j) => _$BuildingsStateFromJson(j);
}
```

**`r1Crumbs: double`** zorunlu — 0.2s tick × fraksiyonel üretim için.

**OnboardingPrefs** ayrıdır, GameState dışında (checksum dışı, migration dışı):

```dart
// lib/core/preferences/onboarding_prefs.dart
@freezed
abstract class OnboardingPrefs with _$OnboardingPrefs {
  const factory OnboardingPrefs({
    required bool hintDismissed,
  }) = _OnboardingPrefs;
  factory OnboardingPrefs.initial() => const OnboardingPrefs(hintDismissed: false);
}
```

### 2.3 Riverpod provider topolojisi

```
gameStateNotifierProvider    AsyncNotifier<GameState>
  ├─ build() async: hydrate(load → migrate → offlineDelta) → push OfflineReport+SaveRecoveryReason
  │                 → _lastTickAt = now → Timer.periodic(200ms, _onTick) → ref.onDispose(timer.cancel)
  ├─ tapCrumb()                       — sync, +1, haptic throttle, floating number spawn
  ├─ Future<bool> buyBuilding(id)     — true=success (sync save), false=insufficient
  ├─ applyProductionDelta(seconds)    — tick + offline common formula
  ├─ Future<void> applyResumeDelta()  — onResume: offline progress since meta.lastSavedAt
  │                                     + update lastSavedAt + optionally push OfflineReport
  └─ resetTickClock()                  — _lastTickAt = null; applyResumeDelta sonrası çağrılır

onboardingPrefsProvider      Notifier<OnboardingPrefs>     SharedPreferences backed
saveRepositoryProvider       Provider<SaveRepository>      saf servis (save/load/migrate)
productionRateProvider       Provider<double>              derived: totalPerSecond(gs.buildings.owned)
currentCrumbsProvider        Provider<double>              derived: gs.inventory.r1Crumbs
costCurveProvider            Provider.family<num, (String, int)>  memoized per (id, owned)
floatingNumbersProvider      StateNotifier<List<FloatingNumber>>  UI-only, max 5 concurrent
offlineReportProvider        StateProvider<OfflineReport?> UI side-effect sinyali
saveRecoveryProvider         StateProvider<SaveRecoveryReason?>   NFR-2 bildirim kanalı
```

**Kural:** UI yalnızca derived provider'lardan okur; mutasyon yalnızca notifier action'ları ile.

### 2.4 Lifecycle akışı

```
main.dart
  └─ runZonedGuarded(() async {
      final container = await AppBootstrap.initialize();
      runApp(UncontrolledProviderScope(
        container: container,
        child: const AppLifecycleGate(child: CrumbsApp()),
      ));
     })

AppBootstrap.initialize()
  1. WidgetsFlutterBinding.ensureInitialized()
  2. await SharedPreferences.getInstance()  // warm cache
  3. return ProviderContainer()
  (Firebase + flutterfire ayrı runbook — A scope dışı)

AppLifecycleGate (ConsumerStatefulWidget wrapper)
  initState:
    _listener = AppLifecycleListener(
      onPause:  () async => await _saveNow(),
      onDetach: () async => await _saveNow(),
      onResume: () async {
        final notifier = ref.read(gameStateNotifierProvider.notifier);
        await notifier.applyResumeDelta();  // offline progress from meta.lastSavedAt
        notifier.resetTickClock();            // warmup tick, _lastTickAt = null
      },
    )
    _autoSaveTimer = Timer.periodic(30s, (_) async => await _saveNow())
  dispose: timer.cancel + listener.dispose
```

**Neden AppLifecycleListener:** Flutter 3.13+ tercih; sadece ihtiyaç olan callback'ler alınır (`didChangeAppLifecycleState` switch'i yok).

**Neden `applyResumeDelta() + resetTickClock()` onResume'da:**
Pause'da `_saveNow()` state'i diskle hizalar, `meta.lastSavedAt = pauseTime`. 5 dk sonra resume:
- **Sadece `resetTickClock()` çağrılırsa** → tick warmup'lar (0s ilk tick), arada geçen 5 dk'lık pasif üretim kaybolur (uygulama foreground'da olmadığı için Timer fire etmedi).
- **`applyResumeDelta()` ilk çağrılırsa** → `OfflineProgress.compute(state, now)` çalışır (`seconds = now − meta.lastSavedAt`), delta sayaca eklenir, `meta.lastSavedAt = now` olur. Sonra `resetTickClock()` warmup'ı başlatır.

Tick drift fix'iyle aynı kod yolu kullanılır (`Production.tickDelta`). Cold start (build) + hot resume aynı formülü çağırır — single source of truth.

`applyResumeDelta` snackbar göstermez (hot resume'da "yokken kazandın" ürpertici). Sadece state'i günceller ve sessiz devam eder. `OfflineReport` yalnızca cold start'ta gösterilir.

---

## 3. Oyun Döngüsü ve Persistans

### 3.1 Production — saf fonksiyon, tek kod yolu

`lib/core/economy/production.dart`:

```dart
class Production {
  const Production._();

  /// Bina id'sine göre base production (C/s).
  /// economy.md §2 — Crumb Collector 0.1 C/s. Diğerleri Sprint B+'ta.
  static double baseProductionFor(String buildingId) => switch (buildingId) {
    'crumb_collector' => 0.1,
    _ => 0.0,  // unknown id → no production, no exception (forward-compat)
  };

  /// Base cost (economy.md §2). CostCurve.costFor bu değeri büyütür.
  static num baseCostFor(String buildingId) => switch (buildingId) {
    'crumb_collector' => 10,
    _ => 0,
  };

  /// Growth rate — cost(n) = base × growth^owned.
  static double growthFor(String buildingId) => switch (buildingId) {
    'crumb_collector' => 1.15,
    _ => 1.0,
  };

  /// Toplam üretim hızı (C/s) — UI, tick ve offline burada birleşir.
  static double totalPerSecond(Map<String, int> buildings) {
    double total = 0;
    buildings.forEach((id, owned) {
      total += owned * baseProductionFor(id);
    });
    return total;
  }

  /// Tick veya offline delta; seconds = wall-clock elapsed.
  static double tickDelta(Map<String, int> buildings, double seconds) =>
    totalPerSecond(buildings) * seconds;
}
```

### 3.2 Tick — drift-free

`GameStateNotifier._onTick`:

```dart
Timer? _tick;
DateTime? _lastTickAt;

void _onTick(Timer _) {
  final now = DateTime.now();
  final seconds = _lastTickAt == null
    ? 0.0
    : now.difference(_lastTickAt!).inMicroseconds / 1e6;
  _lastTickAt = now;
  if (seconds > 0) applyProductionDelta(seconds);
}

void applyProductionDelta(double seconds) {
  final gs = state.valueOrNull;
  if (gs == null) return;
  final delta = Production.tickDelta(gs.buildings.owned, seconds);
  if (delta == 0) return;
  state = AsyncData(gs.copyWith(
    inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs + delta),
  ));
}
```

Online + offline tek formül (`Production.tickDelta`). Bug surface yarıya iner.

### 3.3 Tap ve Satın Alma

```dart
void tapCrumb() {
  final gs = state.valueOrNull;
  if (gs == null) return;  // hydration sürerken no-op
  state = AsyncData(gs.copyWith(
    inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs + 1),
  ));
  _spawnFloatingNumber(1);
  _triggerHaptic();  // 80ms throttled
}

/// true: success (sessiz — idle UX spam yok), false: insufficient (UI shake + tooltip).
Future<bool> buyBuilding(String id) async {
  final gs = state.valueOrNull;
  if (gs == null) return false;
  final owned = gs.buildings.owned[id] ?? 0;
  final cost = CostCurve.costFor(baseCostFor(id), growthFor(id), owned);
  if (gs.inventory.r1Crumbs < cost) return false;
  state = AsyncData(gs.copyWith(
    inventory: gs.inventory.copyWith(r1Crumbs: gs.inventory.r1Crumbs - cost),
    buildings: gs.buildings.copyWith(
      owned: {...gs.buildings.owned, id: owned + 1},
    ),
  ));
  await ref.read(saveRepositoryProvider).save(state.valueOrNull!);  // sync persistence
  return true;
}
```

**Haptic throttle:**
```dart
DateTime? _lastHaptic;
void _triggerHaptic() {
  final now = DateTime.now();
  if (_lastHaptic != null && now.difference(_lastHaptic!).inMilliseconds < 80) return;
  _lastHaptic = now;
  HapticFeedback.lightImpact();
}
```

### 3.4 CostCurve — saf fonksiyon

`lib/core/economy/cost_curve.dart`:
```dart
class CostCurve {
  const CostCurve._();

  /// economy.md §5: cost(n) = floor(baseCost × growthRate^owned)
  static num costFor(num baseCost, double growthRate, int owned) =>
    (baseCost * pow(growthRate, owned)).floor();
}
```

### 3.5 Save akışı

**Atomic write:**
```
1. envelope = SaveEnvelope(version: 1, lastSavedAt: now.toIso8601String(),
                           gameState: gs.toJson(), checksum: Checksum.of(gs.toJson()))
2. tmpFile = "${docsDir}/crumbs_save.json.tmp"
3. mainFile = "${docsDir}/crumbs_save.json"
4. bakFile = "${docsDir}/crumbs_save.json.bak"
5. write tmpFile (json)
6. if mainFile exists: rename mainFile → bakFile
7. rename tmpFile → mainFile   (atomic on same FS)
```

**Read + recovery:**
```
1. try mainFile → parse envelope → verify Checksum.of(envelope.gameState) == envelope.checksum
2. if fail: try bakFile → verify → signal SaveRecoveryReason.checksumFailedUsedBackup
3. if both fail: GameState.initial() → signal SaveRecoveryReason.bothCorruptedStartedFresh
4. migrate(envelope, currentVersion: 1)  // A'da v1 no-op
5. OfflineProgress.compute(gs, DateTime.now()) → apply delta → signal OfflineReport
6. return hydrated
```

**Save cadence:**
- 30s periodic (AppLifecycleGate Timer)
- `AppLifecycleState.paused` — arka plana atınca
- `AppLifecycleState.detached` — app killed (garanti yok ama çağrılırsa)
- `buyBuilding(true)` sonrası sync save (satın alma worst-case kaybını önler)
- `OnboardingPrefs.dismissHint()` SharedPreferences kendi persistence'ı — GameState tetiklemez

### 3.6 Checksum — canonical JSON

`lib/core/save/checksum.dart`:
```dart
class Checksum {
  const Checksum._();

  /// SHA-256 canonical JSON hash — key-sorted, determinism garantisi.
  /// Amaç: disk corruption detection (NFR-2). Tamper resistance kapsam dışı
  /// — single-player offline, leaderboard yok. Anti-cheat ihtiyacı doğarsa
  /// HMAC + server secret'a geçilir, API surface (Checksum.of) korunur.
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

**Shipping gate test:** `save → load → re-save → checksum aynı` (determinism koruması).

### 3.7 Offline progress

`lib/core/economy/offline_progress.dart`:
```dart
class OfflineProgress {
  const OfflineProgress._();

  /// A: 24 saat cap — test cihazını günlerce kapatan kullanıcıya shock-value
  /// snackbar yerine makul UX. B'de Duration(hours: 12)'ye indirir; spec §3.4.
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
```

`OfflineReport` model (`lib/core/feedback/offline_report.dart`):
```dart
@freezed
abstract class OfflineReport with _$OfflineReport {
  const factory OfflineReport({
    required double earned,
    required Duration elapsed,
    required bool capped,
  }) = _OfflineReport;
}
```

`SaveRecoveryReason` enum (`lib/core/feedback/save_recovery.dart`):
```dart
enum SaveRecoveryReason {
  checksumFailedUsedBackup,
  bothCorruptedStartedFresh,
}
```

Her iki sinyal UI katmanında `ref.listen` ile yakalanıp snackbar gösterildikten sonra `null`'lanır.

---

## 4. UI ve Görsel Cila

### 4.1 Ekran topolojisi

```
/ (HomePage)
  Scaffold (full-bleed — no AppBar; Settings More overflow üzerinden)
    body: Stack
      ├─ Column
      │   ├─ CrumbCounterHeader   (48pt display, "C/s: 0.0")
      │   ├─ TapArea              (Expanded, cupcake asset placeholder)
      │   └─ SizedBox(bottom padding for nav)
      ├─ FloatingNumberOverlay    (Stack, +1 anims, ±20px X jitter, max 5 concurrent)
      └─ OnboardingHint           (absolute positioned; first-run only)
    bottomNavigationBar: AppNavigationBar  (5 slots + More overflow BottomSheet)

/shop (ShopPage)
  Scaffold
    ├─ AppBar: "Dükkân"
    └─ ListView
        └─ BuildingRow: Crumb Collector
              ├─ sol: isim + owned "Sahip: 0"
              ├─ orta: cost icon + fmt(cost)
              └─ sağ: FilledButton "Satın al" (disabled + shake on tap insufficient)

/settings (SettingsPage — placeholder)
  AppBar: "Ayarlar"
  Center: Text("Ayarlar yakında eklenecek")
```

### 4.2 Alt Navigation (ux-flows.md §3.1 — 5 slot + More)

| Slot | A durumu | onTap |
|---|---|---|
| Home | ✓ active | `/` route |
| Shop | ✓ active | `/shop` route |
| Upgrades | 🔒 A-scope | snackbar `AppStrings.navLockUpgradesA` |
| Research | 🔒 spec-conditional | snackbar `AppStrings.navLockResearch` |
| More | ✓ active | BottomSheet açılır (4 item) |
| More → Events | 🔒 | snackbar `navLockEvents` |
| More → Prestige | 🔒 | snackbar `navLockPrestige` |
| More → Collection | 🔒 | snackbar `navLockCollection` |
| More → Settings | ✓ active | `/settings` placeholder |

### 4.3 Tema (AppTheme.artisan)

`lib/ui/theme/app_theme.dart`:
```dart
class AppTheme {
  const AppTheme._();

  /// visual-design.md artisan dönemi: warm amber placeholder.
  /// Hex tasarımcı kesinleştirene kadar Material 3 seed ile türetilir.
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE8A53C),  // warm amber placeholder
      brightness: Brightness.light,
    ),
    textTheme: Typography.material2021().black.copyWith(
      displayLarge: const TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        fontFeatures: [FontFeature.tabularFigures()],  // sayaç digit jitter'ını öldürür
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

`MaterialApp.router(theme: AppTheme.light(), darkTheme: AppTheme.dark())` — T5'te atlanan wire-up burada yapılır.

### 4.4 Number formatter (TR locale)

`lib/ui/format/number_format.dart`:
```dart
String fmt(double n) {
  if (n.isNaN || n.isInfinite) return '—';
  if (n == 0) return '0';
  final original = n;
  final sign = n < 0 ? '-' : '';
  n = n.abs();
  String raw;
  if (n < 10) {
    raw = n.toStringAsFixed(1);          // 0.8, 9.2
  } else if (n < 1000) {
    raw = n.floor().toString();          // 42, 987
  } else {
    const units = ['K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'];
    int tier = 0;
    while (tier < units.length && n >= 1000) {
      n /= 1000;
      tier++;
    }
    // Overflow kontrolü: units tükendiyse hala n >= 1000 demektir
    if (n >= 1000) {
      // Bilimsel gösterim orijinal sayı üzerinden
      return '${original.abs().toStringAsExponential(2).replaceAll('.', ',')}'
             .replaceFirst(RegExp(r'^'), sign);
    }
    raw = '${n.toStringAsFixed(n >= 100 ? 1 : 2)}${units[tier - 1]}';
  }
  return '$sign${raw.replaceAll('.', ',')}';
}
```

**Düzeltme:** eski kod `while (n >= 1000 && tier < units.length)` + `if (tier > units.length)` — ikinci koşul asla true olamıyordu (ölü kod). Yeni: while döngüsü units tükendiğinde durur; sonraki `if (n >= 1000)` kontrolü overflow'u yakalar → bilimsel gösterim orijinal sayıdan üretilir.

**Test matrisi ekle:** `1e42` → bilimsel notasyon (Dc'yi geçer), overflow branch coverage.

**Test matrisi:** `0 → '0'`, `0.8 → '0,8'`, `9.2 → '9,2'`, `10 → '10'`, `42.7 → '42'`, `987 → '987'`, `1234 → '1,23K'`, `1e6 → '1,00M'`, `1.5e9 → '1,50B'`, `1e18 → Dc civarı`, `1e42 → scientific fallback`, `-1500 → '-1,50K'`, `NaN → '—'`, `infinity → '—'`.

### 4.5 L10n (gen-l10n + intl)

`pubspec.yaml`:
```yaml
flutter:
  generate: true

dependencies:
  flutter_localizations:
    sdk: flutter
```

`l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: tr.arb
output-localization-file: app_strings.dart
output-class: AppStrings
```

`lib/l10n/tr.arb`:
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

### 4.6 Floating number animation (flutter_animate)

`lib/features/home/floating_number_overlay.dart`:
```dart
// +1 text spawn: random X jitter (±20px) + fadeOut + moveY over 800ms
Text('+${amount.toStringAsFixed(0)}')
  .animate()
  .fadeOut(duration: 800.ms, curve: Curves.easeOut)
  .moveY(begin: 0, end: -40, duration: 800.ms);
```

State management: `floatingNumbersProvider` (`StateNotifier<List<FloatingNumber>>`) — max 5 concurrent, yenisi en eskiyi pop eder. `FloatingNumber(id, amount, x, spawnedAt)`.

### 4.7 Onboarding hint

```dart
// OnboardingHint widget
// Absolute positioned overlay, dismissable on first tap anywhere.
// On dismiss:
//   ref.read(onboardingPrefsProvider.notifier).dismissHint()
//     → SharedPreferences.setBool('hint_dismissed', true)
// Render conditional: ref.watch(onboardingPrefsProvider).hintDismissed == false
```

---

## 5. Test Stratejisi

### 5.1 Coverage hedefleri (test-plan.md §5 ile hizalı)

| Modül | Line | Branch | TDD disiplini |
|---|---|---|---|
| `lib/core/economy/` | ≥%95 | ≥%90 | strict (subagent-driven, red-green-refactor) |
| `lib/core/save/` | ≥%95 | ≥%90 | strict |
| `lib/core/preferences/` | ≥%85 | %75 | normal |
| `lib/core/feedback/` | ≥%85 | %75 | normal |
| `lib/features/home/` | ≥%70 | — | widget smoke |
| `lib/features/shop/` | ≥%70 | — | widget smoke |
| `lib/app/` | ≥%60 | — | integration smoke |
| `lib/ui/theme/format/` | ≥%80 | — | unit |

### 5.2 Kritik test senaryoları

**Economy (unit):**
- `CostCurve.costFor` — owned 0/1/5/25 beklenen değerler (economy.md §5 örneği)
- `Production.totalPerSecond` — 0/1/5 Collector; boş/unknown id map invariant
- `Production.tickDelta` — 0.2s, 1.0s, 0s edge cases
- **Lineer akkümülasyon:** `5 × tickDelta(b, 0.2)` ≈ `tickDelta(b, 1.0)` (relative tolerance: `abs(a-b) < max(abs(a), abs(b)) * 1e-12` — bina sayısı scale'ine göre sağlam; absolute 1e-9 yüksek owned'da riskli)
- `OfflineProgress.compute` — 0/30s/1h/>365d (cap bayrağı test)
- Cap senaryosu: 2 gün offline → 1 yıl cap devreye girer mi (A için `capped: false` beklenen, çünkü cap 365 gün)

**Save (unit):**
- `Checksum.of` — canonical determinism (key sırası bağımsız)
- **Shipping gate:** `save → load → re-save → checksum identical`
- `SaveEnvelope` round-trip: `fromJson(toJson(x)) == x`
- `SaveRepository` atomic write: .tmp yaratılıyor, rename sonrası .bak rotate ediyor
- Corruption A: main.json checksum fail → .bak'tan yükle → `saveRecovery.checksumFailedUsedBackup`
- Corruption B: ikisi de bozuk → `GameState.initial()` + `saveRecovery.bothCorruptedStartedFresh`
- Migration v1 → v1 no-op; v2 için stub interface mevcut

**UI (widget):**
- Tap → counter incremented (integration smoke)
- Buy insufficient → button dimmed (80% opacity); tap'te `.shake(duration: 300ms)` + tooltip 2s gösterilir; state değişmedi
- Buy sufficient → cost düşüldü, owned++, `saveRepositoryProvider.save` çağrıldı (mock)
- Offline report snackbar → shown once, state cleared after
- Save recovery snackbar → shown once per startup
- Onboarding hint → first-run only, dismiss persists SharedPreferences
- Nav lock tap → doğru snackbar mesajı (AppStrings lookup)

**Number formatter (unit):**
- Tüm matris: `0, 0.8, 9.2, 10, 42.7, 987, 1234, 1e6, 1.5e9, 1e18, 1e42, -1500, NaN, infinity`

**Integration (integration_test/app_test.dart):**
```
1. App cold start → hint görünür
2. Tap cupcake → +1 counter, hint dismiss
3. 10 tap → sayaç 10
4. Navigate to shop → Crumb Collector row görünür
5. Tap "Satın al" → owned 1, crumbs 0
6. Resume to home → sayaç pasif olarak artıyor
7. Simulate lifecycle paused → save dosyası yazılı, meta.lastSavedAt güncel
8. Simulate 5s wall-clock + lifecycle resumed → applyResumeDelta çağrıldı (5s × owned × 0.1 C/s eklendi), lastSavedAt = resume time; resetTickClock sonrası warmup tick 0.0s; snackbar GÖSTERİLMEZ (hot resume sessiz)
9. Full restart (new container) → save load, offline progress applied, welcome-back snackbar GÖSTERİLİR
10. Corrupt main save → restart → .bak'tan yüklendi, recovery snackbar
```

---

## 6. Görev Listesi

21 task; `S` = subagent-driven (implementer → spec reviewer → code quality reviewer), `C` = controller-direct.

| # | Task | Mod | Çıktı |
|---|---|---|---|
| 1 | **Pubspec ekle:** `flutter_animate ^4.5.2`, `shared_preferences ^2.3.4`, `uuid ^4.5.1`, `flutter_localizations` sdk | C | pubspec.yaml |
| 2 | **L10n kurulum:** `l10n.yaml`, `lib/l10n/tr.arb` initial strings, `flutter: generate: true` | C | l10n iskelet + AppStrings codegen |
| 3 | **GameState freezed 3'lü:** meta + inventory + buildings + `GameState.initial()` + tests | S | `lib/core/save/game_state.dart` |
| 4 | **CostCurve:** saf fonksiyon + unit tests (owned 0/1/5/25 matris) | S | `lib/core/economy/cost_curve.dart` |
| 5 | **Production + BuildingDefs:** `baseProductionFor`, `baseCostFor`, `growthFor` lookup switch'leri (crumb_collector: 0.1 C/s, cost 10, growth 1.15 — economy.md §2 mirror) + `totalPerSecond` + `tickDelta` + lineer akk testi | S | `lib/core/economy/production.dart` |
| 6 | **OfflineProgress + OfflineReport:** compute + cap const + flag + tests | S | `lib/core/economy/offline_progress.dart`, `lib/core/feedback/offline_report.dart` |
| 7 | **Checksum:** canonical SHA-256 + determinism shipping-gate test + round-trip | S | `lib/core/save/checksum.dart` |
| 8 | **SaveEnvelope + SaveMigrator interface:** freezed abstract v1, migration v1 no-op, framework | S | `lib/core/save/save_envelope.dart`, `save_migrator.dart` |
| 9 | **SaveRepository:** path_provider paths, atomic write, .bak rotation, corruption recovery, `SaveRecoveryReason` sinyali, **save serialization lock** (`Future<void>? _pending` ile in-flight save'ler serialize; 30s timer + purchase sync + lifecycle pause çakışmasını önler — Fix #3), mocktail unit tests (concurrent save race test dahil) | S | `lib/core/save/save_repository.dart`, `lib/core/feedback/save_recovery.dart` |
| 10 | **OnboardingPrefs provider:** SharedPreferences Notifier, `hintDismissed` persist | C | `lib/core/preferences/onboarding_prefs.dart` |
| 11 | **GameStateNotifier (AsyncNotifier):** build hydrate flow, `tapCrumb`, `buyBuilding`, `applyProductionDelta`, **`applyResumeDelta`** (hot resume offline progress, sessiz), `resetTickClock`; offlineReport + saveRecovery push cold start'ta; cross-feature (Home + Shop okur). Timer spawn öncesi `_lastTickAt = DateTime.now()` set (Fix #4). | C (integration) | `lib/core/state/game_state_notifier.dart` |
| 12 | **AppBootstrap (pre-hydration):** `initialize()` ProviderContainer + SharedPreferences warm | C | `lib/app/boot/app_bootstrap.dart` |
| 13 | **AppLifecycleGate:** `AppLifecycleListener` (onPause/onDetach → `_saveNow` await; **onResume → `applyResumeDelta` → `resetTickClock` — hot resume offline progress bug fix**) + 30s autoSaveTimer | C | `lib/app/lifecycle/app_lifecycle_gate.dart` |
| 14 | **Derived providers:** `currentCrumbsProvider`, `productionRateProvider`, `costCurveProvider.family` (core/state) + `floatingNumbersProvider` (features/home) | C | `lib/core/state/providers.dart`, `lib/features/home/providers.dart` |
| 15 | **Number formatter `fmt()`** + TR locale + full test matrix | S | `lib/ui/format/number_format.dart` |
| 16 | **AppTheme.artisan:** Material 3 seed + tabularFigures + light/dark | C | `lib/ui/theme/app_theme.dart` |
| 17 | **Common widgets:** CrumbCounterHeader, TapArea, BuildingRow (+shake), FloatingNumberOverlay, OnboardingHint, AppNavigationBar (5-slot + More BottomSheet) | C | `lib/features/home/widgets/*`, `lib/features/shop/widgets/*` |
| 18 | **HomePage:** composition + `ref.listen` side-effects (offlineReport, saveRecovery snackbars) | C | `lib/features/home/home_page.dart` |
| 19 | **ShopPage:** Crumb Collector row + buy flow | C | `lib/features/shop/shop_page.dart` |
| 20 | **AppRouter:** home + shop + settings routes + nav lock snackbar handler | C | `lib/app/routing/app_router.dart` |
| 21 | **main.dart + Integration test:** AppBootstrap wire + `AppLifecycleGate`; 10-step integration scenario (tap, buy, lifecycle, corruption recovery) | C | `lib/main.dart`, `integration_test/app_test.dart` |

**Yürütme sırası:** 1-2 (foundation) → 3-9 (core modules, TDD-strict sırasıyla) → 10-14 (provider layer) → 15-17 (UI atomics) → 18-20 (composition) → 21 (entry point + integration smoke).

Paralel yasak (skill kuralı). Her S task'ı: implementer → spec compliance reviewer → code quality reviewer → mark complete. Her C task'ı: implementation → self-verify → commit.

---

## 7. Roadmap ve Taşınan Borç

### Sprint B eklenecekler
- 2 bina daha (`baker` base 0.5 C/s base_cost 100, `bakery` base 2 C/s base_cost 1000 — economy.md §2)
- 1 upgrade (golden_recipe — upgrade-catalog.md)
- Offline cap 12 saat (tek const değişimi)
- Upgrades nav slotu aktif
- Full FR-3 tutorial (ux-flows.md §4)

### Sprint C eklenecekler
- 3 bina daha (Machine, Factory, Industrial Oven)
- R2 Research Shards unlock mekanizması (~15-30 dk)
- Research Lab ekranı + 2 node
- Research nav slotu aktif

### Post-Sprint C / Post-first-prestige
- Kalan 2 bina (Automation, Portal Kitchen)
- Prestige reset döngüsü + R3 Prestige Essence
- Prestige nav slotu 5. slot olarak eklenir — Material 3 NavigationBar 3-5 limit sınırı; More menüsü içeriği kısaltılır
- Full 12 research node, 30-40 upgrade, 3 event, Session Recap modal
- Achievements + Collection ekranları

### Followups / Taşınan Borç
- **I18n template rotation:** İngilizce eklenirken `en.arb` template'e promote; `tr.arb` çeviri haline gelir. Translator araçları TR→diğer yönünü desteklemiyor. Tek commit.
- **Accessibility 48dp audit:** BuildingRow + TapArea + nav items tap target'ları manual Flutter Inspector ile teyit.
- **AsyncError friendly screen:** Default Flutter red error screen yerine "Restart"lı friendly ekran. Sprint B.
- **Post-prestige nav limit:** Material 3 NavigationBar 3-5 destination sınırı; 6+ için NavigationRail (tablet) veya custom FAB + overflow.
- **Anti-cheat (gerekirse):** SHA-256 → HMAC geçişi, server-side secret. `Checksum.of` API surface korunur.
- **economy.md §5 floor/round doğrulama:** CostCurve `.floor()` kullanıyor; `economy.md §5` metninin `floor` mu `round` mu dediği onay gerektirir. B sprint başında cross-check; farkın 1-2 birim ama early-game cost tempo hissiyatını etkiler. — Fix #5
- **SaveEnvelope typed GameState migration:** A'da envelope `Map<String, dynamic> gameState` tutuyor (T3 scaffold carryover). B'de `GameState gameState` typed field'a geçilir; `Checksum.of(envelope.gameState.toJson())` explicit olur. Tek migration commit (envelope shape değişir ama `version: 1 → 2` bump + migrator v1→v2 no-op-shape). — Fix #7
- **BuildingRow shake state pattern:** A'da tek Crumb Collector row var. B'de 3 bina olunca her row bağımsız shake state ister. Widget şimdiden `StatefulWidget` + local `AnimationController` ile kurgulanır (Task 17 notu) — B'de refactor gerekmez. — Fix #8
- **Freezed 3.x `abstract class` tutarlılığı:** A'daki yeni freezed'lar (GameState, OfflineReport, OnboardingPrefs, MetaState, InventoryState, BuildingsState) hepsi `abstract class X with _$X` pattern'iyle yazılır; scaffold'daki mevcut `SaveEnvelope` + controllers aynı convention'da. Karışım yapılmaz. — Fix #9
- **install_id persistence:** A'da `GameState.initial({installId})` UUID üretir; save corruption'da fresh `initial()` → yeni UUID, telemetry'de aynı user çoklu install. B'de (telemetry bağlanırken) `installIdProvider` SharedPreferences backed Notifier eklenir; AppBootstrap ilk açılışta persist eder, sonraki tüm `GameState.initial()` bu stable ID'yi kullanır. — Fix #10

---

## 8. Referanslar

- `cookie_clicker_derivative_prd.md` §6 (ekran kataloğu), §7 (state + save), §8 (ekonomi), §12 (NFR), §13 (MVP scope), §17 (sprint planı)
- `docs/economy.md` §2 (bina tablosu), §3 (üretim), §5 (cost curve), §6 (çarpanlar — A'da tek seviye), §A.4 (buff — A'da yok)
- `docs/save-format.md` §1 (envelope), §3 (checksum — §3 metni güncellenecek: corruption-only niyet), §5 (atomic write), §6 (migration)
- `docs/ux-flows.md` §3.1 (5-slot + More), §4 (FR-3 onboarding — A'da inline subset), §5.1 (Home), §5.2 (Shop)
- `docs/telemetry.md` — Sprint A'da telemetry event hiçbiri push edilmiyor; provider'lar Sprint B'de bağlanır
- `docs/test-plan.md` §5 (coverage hedefleri), §10.1 (CI gate)
- `docs/scaffold-plan.md` §2, §3, §4 (pubspec, analysis, dizin)
- `docs/visual-design.md` — AppTheme amber seed placeholder kaynağı
- `CLAUDE.md` §6 (mimari), §7 (state), §8 (save), §9 (test), §10 (plan mode), §12 (gotcha'lar)
- `_dev/tasks/lessons.md` — spec drift, import sırası, codegen order, Flutter pin caveatleri
