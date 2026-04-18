# Sprint B4 — Settings + Developer Experience + Telemetry Event Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settings ekranı gerçek implementation (Audio stub + Developer flag-gated), TutorialNotifier.reset() + TutorialStarted.isReplay cohort analytics integrity, PurchaseMade + UpgradePurchased telemetry events, AppInstall trigger canonical form (FirstBootNotifier disjoint from tutorial state).

**Architecture:** `FirstBootNotifier` yeni `Notifier<bool?>` (SharedPreferences-backed `crumbs.first_launch_observed`), AppBootstrap step b' rewire — `isFirstLaunch` artık buradan okunur (tutorial state disjoint). Migration proxy: `install_id` varlığı (B1+ evrensel) pre-B4 user sinyali, backfill observed=true. `PurchaseMade` + `UpgradePurchased` events GameStateNotifier successful purchase path'ten emit ([I19]). `TutorialStarted.isReplay: bool` required field; `consumeReplayFlag()` single-use pattern (`reset()` true'ya flip'ler, ilk reader false'a sıfırlar — [I20]). Settings page 2-section (Audio stub + Developer flag-gated); `developerVisibilityProvider` test override-able wrapper. Firebase Crashlytics test button `isInitialized` guard + snackbar fallback.

**Tech Stack:** Flutter 3.41.5, Dart 3.11, Riverpod 3.1, freezed 3.0, firebase_core 4.7, firebase_analytics 12.3, firebase_crashlytics 5.0, shared_preferences 2.3, mocktail 1.0. B3 altyapısı korunur: TelemetryLogger interface + FirebaseAnalyticsLogger + FirebaseBootstrap 3-phase + InstallIdNotifier disk-wins.

**Referans:** `docs/superpowers/specs/2026-04-18-sprint-b4-settings-dev-experience-design.md` (spec — 3 clarifying choice + 7 review fixes applied).

---

## Önkoşullar (plan öncesi)

- **Sprint B3 merge edilmiş:** PR #5 (`sprint/b3-telemetry-activation`) main'e merge edilmiş (`aead20f`). B4 branch spec commit ile `main`'den çıktı.
- **Branch:** `sprint/b4-settings-dev-experience` (spec + plan bu branch'te).
- **Flutter 3.41.5 FVM pinned.**
- **Baseline:** `flutter test -j 1` 219 pass (B3 sonrası), `flutter analyze` 0 issue.
- **Firebase dev stub:** `lib/firebase_options.dart` gitignored; B3 T3'te dev stub oluşturuldu, local'de mevcut.

```bash
git checkout sprint/b4-settings-dev-experience
flutter pub get
flutter test -j 1  # 219 pass baseline
flutter analyze  # 0 issue baseline
```

---

## Dependency Chain

```
T3 (event shapes) ──► T4 (regex list + log tests) ──► T7 (isReplay emission)
                                                      ▲
T1 (FirstBootNotifier) ──► T2 (AppBootstrap wire) ──► T13 (integration test)
                                                      ▲
T5 (GameState emit) ──────────────────────────────────┤
                                                      │
T6 (TutorialNotifier.reset + consumeReplayFlag) ────► T7
                                                      │
T8 (dev provider) ──► T9, T10, T11 sıralı ──► T13 ──► T14 (docs)
T12 (l10n) ──► T10, T11 (compile dep)
```

**Kritik kurallar:**
- **T1 → T2 atomic** — FirstBootNotifier + AppBootstrap rewire (tutorialState.firstLaunchMarked usage'ı kaldırılır)
- **T3 → T4 ayrı commit** — T3 event shape + event_test.dart, T4 FirebaseAnalyticsLogger regex list + log tests (T4 atlanırsa regex coverage eksik kalır)
- **T6 → T7** — consumeReplayFlag producer → consumer
- **T12 (l10n) T10+T11 öncesi** — widget compile'da string key'ler
- **T13 SON** — T1+T2+T5+T7 wiring tamamlandıktan sonra integration coverage mümkün

**Task modu:** `(S)` = subagent-driven TDD strict, `(C)` = controller-direct.

---

## Task 1 (S) ★: FirstBootNotifier + migration proxy

**Amaç:** `FirstBootNotifier extends Notifier<bool?>` — `ensureObserved()` method pre-B4 migration proxy (`install_id` varlığı → backfill observed=true) + fresh B4 install (observed=true yaz, state=true döndür).

**Files:**
- Create: `lib/core/launch/first_boot_notifier.dart`
- Create: `test/core/launch/first_boot_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/launch/first_boot_notifier_test.dart`:

```dart
import 'package:crumbs/core/launch/first_boot_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('FirstBootNotifier', () {
    test('fresh B4 install (no prefs) → ensureObserved true + pref write',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, true, reason: 'fresh install → AppInstall should emit');
      expect(c.read(firstBootProvider), true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true);
    });

    test(
        'pre-B4 migration (install_id mevcut, observed yok) → '
        'state=false + backfill', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
      });
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, false, reason: 'pre-B4 user — AppInstall suppressed');
      expect(c.read(firstBootProvider), false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true,
          reason: 'backfill: pref yazıldı ki ikinci boot idempotent olsun');
    });

    test('second boot (observed=true pref) → state=false idempotent',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_observed': true,
        'crumbs.install_id': 'some-id',
      });
      final c = buildContainer();

      final result =
          await c.read(firstBootProvider.notifier).ensureObserved();

      expect(result, false);
      expect(c.read(firstBootProvider), false);
    });

    test('B4 fresh install second boot — observed stays true', () async {
      // İlk boot
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c1 = buildContainer();
      final r1 = await c1.read(firstBootProvider.notifier).ensureObserved();
      expect(r1, true);

      // Aynı SharedPreferences mock ile "ikinci boot" — state preserved
      // (setMockInitialValues persistent test boyunca, ama yeni container)
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final r2 = await c2.read(firstBootProvider.notifier).ensureObserved();
      expect(r2, false, reason: 'observed pref idempotent korunur');
    });
  });
}
```

- [ ] **Step 2: Run test — fail**

Run: `flutter test test/core/launch/first_boot_notifier_test.dart`
Expected: FAIL — `first_boot_notifier.dart` yok (`uri_does_not_exist`).

- [ ] **Step 3: Implementation**

Create `lib/core/launch/first_boot_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppInstall event trigger'ı için "bu cihazın ilk boot'u mu?" sinyali.
///
/// Tutorial state'inden DISJOINT — TutorialNotifier.reset() bu provider'a
/// dokunmaz, yani tutorial replay sonrası AppInstall re-emit EDİLMEZ
/// (invariant [I18]).
///
/// Pre-B4 migration: B4 öncesi install'lar `first_launch_observed` pref'ine
/// sahip değil, ama `install_id` pref'i B1'den beri mevcut. `install_id`
/// varlığı "bu cihaz daha önce boot edilmiş" kanıtı — backfill observed=true.
class FirstBootNotifier extends Notifier<bool?> {
  static const _prefKey = 'crumbs.first_launch_observed';

  @override
  bool? build() => null;

  /// Boot'ta bir kez çağrılır. İdempotent (ikinci çağrı pref'ten okur).
  ///
  /// Returns: bu cihazın ilk B4 boot'u mu?
  ///   - true  → fresh B4 install (AppInstall emit edilmeli)
  ///   - false → pre-B4 migration OR second+ boot (AppInstall suppressed)
  Future<bool> ensureObserved() async {
    final prefs = await SharedPreferences.getInstance();
    final wasObserved = prefs.getBool(_prefKey) ?? false;
    if (!wasObserved) {
      // Pre-B4 migration check: install_id B1'den beri tüm user'larda yazılı.
      final installId = prefs.getString('crumbs.install_id');
      if (installId != null) {
        // Pre-B4 user (B1-B3 arası install) — backfill observed, no emit.
        await prefs.setBool(_prefKey, true);
        state = false;
        return false;
      }
      // Gerçek fresh B4+ install.
      await prefs.setBool(_prefKey, true);
      state = true;
      return true;
    }
    state = false;
    return false;
  }
}

final firstBootProvider =
    NotifierProvider<FirstBootNotifier, bool?>(FirstBootNotifier.new);
```

- [ ] **Step 4: Run test — pass**

Run: `flutter test test/core/launch/first_boot_notifier_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Analyze + full suite**

Run:
```bash
flutter analyze
flutter test -j 1
```

Expected: analyze 0 issue; full suite 223 pass (219 baseline + 4 yeni).

- [ ] **Step 6: Commit**

```bash
git add lib/core/launch/first_boot_notifier.dart test/core/launch/first_boot_notifier_test.dart
git commit -m "sprint-b4(T1): FirstBootNotifier + migration proxy (install_id backfill)"
```

---

## Task 2 (S) ★: AppBootstrap step b' — firstBootProvider wire

**Amaç:** `AppBootstrap.initialize` step b' — `firstBootProvider.ensureObserved()` çağrısı (step b ile d arasında). Step f'te `isFirstLaunch` artık bu provider'dan okunur, `tutorialState.firstLaunchMarked` usage kaldırılır.

**Files:**
- Modify: `lib/app/boot/app_bootstrap.dart`
- Modify: `test/app/boot/app_bootstrap_test.dart`

- [ ] **Step 1: Read current AppBootstrap**

Inspect `lib/app/boot/app_bootstrap.dart`. Mevcut B3 sequence:
- step a: binding + prefs
- step b: installIdProvider.ensureLoaded()
- step c: gameStateNotifier.future
- step d: installIdProvider.adoptFromGameState
- step d': Crashlytics setUserIdentifier (B3)
- step e: tutorialNotifier.future
- step f: `final isFirstLaunch = !tutorialState.firstLaunchMarked;`
         `sessionController.onLaunch(isFirstLaunch: isFirstLaunch);`

- [ ] **Step 2: Modify — step b' + step f rewire**

Replace in `lib/app/boot/app_bootstrap.dart`:

```dart
// Mevcut imports'a ekle:
import 'package:crumbs/core/launch/first_boot_notifier.dart';

// Mevcut initialize() içinde:

    await container.read(installIdProvider.notifier).ensureLoaded();

    // B4 YENİ — step b': FirstBootNotifier observe (AppInstall trigger
    // source — tutorial state'inden disjoint, invariant [I18])
    final isFirstLaunch =
        await container.read(firstBootProvider.notifier).ensureObserved();

    final gs = await container.read(gameStateNotifierProvider.future);
    await container
        .read(installIdProvider.notifier)
        .adoptFromGameState(gs.meta.installId);

    if (FirebaseBootstrap.isInitialized) {
      unawaited(
        FirebaseCrashlytics.instance.setUserIdentifier(gs.meta.installId),
      );
    }

    final tutorialState =
        await container.read(tutorialNotifierProvider.future);

    // B4 DEĞİŞTİ — step f: isFirstLaunch firstBootProvider'dan okunur
    // (B3'teki !tutorialState.firstLaunchMarked kullanımı kaldırıldı)
    container
        .read(sessionControllerProvider)
        .onLaunch(isFirstLaunch: isFirstLaunch);
```

Eski line `final firstLaunchBefore = !tutorialState.firstLaunchMarked;` (veya benzeri) SİL.

- [ ] **Step 3: Verify compile — full suite pre-check**

Run: `flutter analyze`
Expected: 0 issue.

Run: `flutter test test/app/boot/app_bootstrap_test.dart`
Expected: B3 test'leri hâlâ PASS (B4 step b' ekleme T3 guard ile — test env'da sessizce çalışır).

- [ ] **Step 4: Write new test — B4 integration invariant**

`test/app/boot/app_bootstrap_test.dart`'a yeni test ekle (main() kapanış `}` ÖNCESİNDE):

```dart
  group('AppBootstrap — B4 firstBootProvider wire', () {
    test(
        'fresh B4 install: firstBootProvider true → isFirstLaunch propagated',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final boot = await AppBootstrap.initialize(
        containerFactory: _testContainer,
      );
      addTearDown(boot.container.dispose);

      // FirstBootNotifier ensureObserved çağrıldı ve state=true
      expect(boot.container.read(firstBootProvider), true);

      // SharedPreferences pref yazıldı (idempotency için)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_observed'), true);
    });

    test('pre-B4 migration: install_id mevcut → firstBootProvider false',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
      });

      final boot = await AppBootstrap.initialize(
        containerFactory: _testContainer,
      );
      addTearDown(boot.container.dispose);

      expect(boot.container.read(firstBootProvider), false,
          reason: 'pre-B4 backfill — AppInstall suppressed');
    });
  });
```

**Import eklenecek test dosyası başına:**
```dart
import 'package:crumbs/core/launch/first_boot_notifier.dart';
```

- [ ] **Step 5: Run test — pass**

Run: `flutter test test/app/boot/app_bootstrap_test.dart`
Expected: PASS (B3 test'leri + 2 yeni B4).

- [ ] **Step 6: Full suite verify**

Run:
```bash
flutter analyze
flutter test -j 1
```

Expected: 0 issue; 225 pass (223 + 2 yeni).

- [ ] **Step 7: Commit**

```bash
git add lib/app/boot/app_bootstrap.dart test/app/boot/app_bootstrap_test.dart
git commit -m "sprint-b4(T2): AppBootstrap step b' firstBootProvider wire (isFirstLaunch disjoint from tutorial state)"
```

---

## Task 3 (S) ★: TelemetryEvent — PurchaseMade + UpgradePurchased + TutorialStarted.isReplay

**Amaç:** Sealed `TelemetryEvent` hierarchy'ye 2 yeni event class + `TutorialStarted.isReplay: bool` required field. T3 kapsamı sadece shape change + event_test.dart update — T4 FirebaseAnalyticsLogger regex list ayrı commit.

**Files:**
- Modify: `lib/core/telemetry/telemetry_event.dart`
- Modify: `test/core/telemetry/telemetry_event_test.dart`

- [ ] **Step 1: Write failing tests**

`test/core/telemetry/telemetry_event_test.dart` içine yeni group'lar ekle + mevcut `TutorialStarted` group'unu güncelle:

**Mevcut `TutorialStarted` group'unu değiştir:**

```dart
  group('TelemetryEvent — TutorialStarted', () {
    test('eventName is tutorial_started', () {
      const e = TutorialStarted(installId: 'abc', isReplay: false);
      expect(e.eventName, 'tutorial_started');
    });

    test('payload has install_id + is_replay', () {
      const e = TutorialStarted(installId: 'abc', isReplay: false);
      expect(e.payload, {'install_id': 'abc', 'is_replay': false});
    });

    test('isReplay=true propagates in payload', () {
      const e = TutorialStarted(installId: 'abc', isReplay: true);
      expect(e.payload['is_replay'], true);
    });
  });
```

**Yeni group'lar dosya sonuna (kapanış `}` ÖNCESİNDE) ekle:**

```dart
  group('TelemetryEvent — PurchaseMade (B4)', () {
    test('eventName is purchase_made', () {
      const e = PurchaseMade(
        installId: 'abc',
        buildingId: 'crumb_collector',
        cost: 15,
        ownedAfter: 1,
      );
      expect(e.eventName, 'purchase_made');
    });

    test('payload has install_id, building_id, cost, owned_after', () {
      const e = PurchaseMade(
        installId: 'abc',
        buildingId: 'oven',
        cost: 120,
        ownedAfter: 3,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'building_id': 'oven',
        'cost': 120,
        'owned_after': 3,
      });
    });
  });

  group('TelemetryEvent — UpgradePurchased (B4)', () {
    test('eventName is upgrade_purchased', () {
      const e = UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      );
      expect(e.eventName, 'upgrade_purchased');
    });

    test('payload has install_id, upgrade_id, cost', () {
      const e = UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'upgrade_id': 'golden_recipe_i',
        'cost': 200,
      });
    });
  });
```

Ayrıca mevcut **exhaustive switch test**'ini (`TelemetryEvent is sealed — pattern match exhaustive`) 2 yeni event arm ile genişlet:

```dart
  test('TelemetryEvent is sealed — pattern match exhaustive', () {
    TelemetryEvent e = const AppInstall(installId: 'x', platform: 'ios');
    final name = switch (e) {
      AppInstall() => 'install',
      SessionStart() => 'start',
      SessionEnd() => 'end',
      TutorialStarted() => 'tut_start',
      TutorialCompleted() => 'tut_done',
      PurchaseMade() => 'purchase',
      UpgradePurchased() => 'upgrade',
    };
    expect(name, 'install');
  });
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/telemetry_event_test.dart`
Expected: FAIL — `TutorialStarted(installId:, isReplay:)` signature yok + `PurchaseMade`/`UpgradePurchased` tanımı yok.

- [ ] **Step 3: Implementation — telemetry_event.dart**

`lib/core/telemetry/telemetry_event.dart` içinde:

**Mevcut `TutorialStarted`'ı değiştir:**

```dart
class TutorialStarted extends TelemetryEvent {
  const TutorialStarted({
    required this.installId,
    required this.isReplay,
  });

  final String installId;
  final bool isReplay;

  @override
  String get eventName => 'tutorial_started';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'is_replay': isReplay,
      };
}
```

**Dosya sonuna 2 yeni event class ekle (kapanış ) `}` yok, dosya son class'tan sonra biter):**

```dart
class PurchaseMade extends TelemetryEvent {
  const PurchaseMade({
    required this.installId,
    required this.buildingId,
    required this.cost,
    required this.ownedAfter,
  });

  final String installId;
  final String buildingId;
  final int cost;
  final int ownedAfter;

  @override
  String get eventName => 'purchase_made';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'building_id': buildingId,
        'cost': cost,
        'owned_after': ownedAfter,
      };
}

class UpgradePurchased extends TelemetryEvent {
  const UpgradePurchased({
    required this.installId,
    required this.upgradeId,
    required this.cost,
  });

  final String installId;
  final String upgradeId;
  final int cost;

  @override
  String get eventName => 'upgrade_purchased';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'upgrade_id': upgradeId,
        'cost': cost,
      };
}
```

- [ ] **Step 4: Run — compile fail expected**

Run: `flutter analyze`
Expected: **ERROR** — `TutorialStarted` mevcut call site'ları (`TutorialScaffold` + `integration_test/tutorial_telemetry_integration_test.dart`) `isReplay` eksik. **Bu T7 ve T13'te fix edilecek.** Geçici olarak T3 commit'i tek başına compile-broken state bırakır.

Alternatif: T3 commit'inden önce T7+T13'ü hazırla. Ama B3 T6/T7 atomic chain pattern'inde de benzer compile-red interval kabul edildi. **Önerilen flow: T3 commit + T7 hemen sonrası + T13 + compile-green restore.**

- [ ] **Step 5: Run test — event test PASS (tek başına)**

Run: `flutter test test/core/telemetry/telemetry_event_test.dart`
Expected: PASS (11 existing + 3 TutorialStarted updated + 4 yeni event tests = 18 test).

Not: `tutorial_scaffold_test.dart` ve `firebase_analytics_logger_test.dart` compile fail — T7/T4'te çözülür.

- [ ] **Step 6: Commit (atomic intermediate state — T7 takip eder)**

```bash
git add lib/core/telemetry/telemetry_event.dart test/core/telemetry/telemetry_event_test.dart
git commit -m "sprint-b4(T3): TelemetryEvent — PurchaseMade + UpgradePurchased + TutorialStarted.isReplay"
```

**UYARI:** `flutter test` full suite şimdi FAIL eder — `TutorialScaffold` + FirebaseAnalyticsLogger compile fail. T4/T7 derhal takip eder. Git history bu intermediate state'i açıkça gösterir.

---

## Task 4 (C): FirebaseAnalyticsLogger regex invariant list + log tests

**Amaç:** Firebase event name regex invariant test events list 4 → 6 (PurchaseMade + UpgradePurchased eklenir). Ayrıca 2 yeni event için log() tests + TutorialStarted.isReplay coercion test. **T3'ten sonra atomic chain kritik** — compile fail'i kapatır.

**Files:**
- Modify: `test/core/telemetry/firebase_analytics_logger_test.dart`

- [ ] **Step 1: Update events list + regex compliance tests**

`test/core/telemetry/firebase_analytics_logger_test.dart` içinde `group('Firebase compliance invariant', ...)` events list'ini genişlet:

```dart
  group('FirebaseAnalyticsLogger — Firebase compliance invariant', () {
    final events = <TelemetryEvent>[
      const AppInstall(installId: 'x', platform: 'ios'),
      const SessionStart(installId: 'x', sessionId: 'y', installIdAgeMs: 0),
      const SessionEnd(installId: 'x', sessionId: 'y', durationMs: 0),
      const TutorialStarted(installId: 'x', isReplay: false),  // B4 updated
      const TutorialCompleted(installId: 'x', skipped: false, durationMs: 0),
      // B4 YENİ:
      const PurchaseMade(
        installId: 'x',
        buildingId: 'crumb_collector',
        cost: 15,
        ownedAfter: 1,
      ),
      const UpgradePurchased(
        installId: 'x',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      ),
    ];
    // ... regex + reserved prefix checks devam eder (değişmez)
  });
```

- [ ] **Step 2: Add log() tests — 2 new events + isReplay coercion**

Mevcut `group('FirebaseAnalyticsLogger — log()', ...)` içinde yeni test'ler ekle:

```dart
    test('PurchaseMade → logEvent with 4-field payload', () {
      logger.log(const PurchaseMade(
        installId: 'abc',
        buildingId: 'oven',
        cost: 120,
        ownedAfter: 3,
      ));
      verify(() => analytics.logEvent(
            name: 'purchase_made',
            parameters: {
              'install_id': 'abc',
              'building_id': 'oven',
              'cost': 120,
              'owned_after': 3,
            },
          )).called(1);
    });

    test('UpgradePurchased → logEvent with 3-field payload', () {
      logger.log(const UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      ));
      verify(() => analytics.logEvent(
            name: 'upgrade_purchased',
            parameters: {
              'install_id': 'abc',
              'upgrade_id': 'golden_recipe_i',
              'cost': 200,
            },
          )).called(1);
    });

    test('TutorialStarted isReplay=true → coerced to int 1', () {
      logger.log(const TutorialStarted(installId: 'abc', isReplay: true));
      verify(() => analytics.logEvent(
            name: 'tutorial_started',
            parameters: {'install_id': 'abc', 'is_replay': 1},
          )).called(1);
    });

    test('TutorialStarted isReplay=false → coerced to int 0', () {
      logger.log(const TutorialStarted(installId: 'abc', isReplay: false));
      verify(() => analytics.logEvent(
            name: 'tutorial_started',
            parameters: {'install_id': 'abc', 'is_replay': 0},
          )).called(1);
    });
```

- [ ] **Step 3: Run test — pass**

Run: `flutter test test/core/telemetry/firebase_analytics_logger_test.dart`
Expected: PASS — existing 13 test + 4 yeni log + 4 yeni compliance (2 events × 2 checks) = 21 test.

- [ ] **Step 4: Analyze — full suite still compile fail (T7 bekliyor)**

Run: `flutter analyze`
Expected: **ERROR** — `tutorial_scaffold.dart` `TutorialStarted` missing `isReplay`. T7'de fix.

- [ ] **Step 5: Commit**

```bash
git add test/core/telemetry/firebase_analytics_logger_test.dart
git commit -m "sprint-b4(T4): FirebaseAnalyticsLogger regex events list 6 + 2 new log tests + isReplay coercion"
```

---

## Task 5 (S) ★: GameStateNotifier — buyBuilding + buyUpgrade emission

**Amaç:** `GameStateNotifier.buyBuilding` successful path'ten `PurchaseMade` emit; `GameStateNotifier.buyUpgrade` successful path'ten `UpgradePurchased` emit. Failed/rejected path'lerde emission YOK ([I19]). `_persistSafe` sonrası sync emit (crash window %0.01 kabul, B5 analysis).

**Files:**
- Modify: `lib/core/state/game_state_notifier.dart`
- Create: `test/core/state/game_state_notifier_telemetry_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/core/state/game_state_notifier_telemetry_test.dart`:

```dart
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crumbs_gs_telemetry');
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-install-id',
    });
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer(_CaptureLogger logger) {
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(
          saveDir: () async => tempDir,
          fileName: 'save.json',
        ),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('GameStateNotifier telemetry — PurchaseMade (B4 [I19])', () {
    test('successful buyBuilding → PurchaseMade event emit', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      // 1000 Crumbs tap — crumb_collector (cost 15) satın alınabilir
      for (var i = 0; i < 100; i++) {
        notifier.tapCrumb();
      }

      logger.events.clear(); // tap event'leri temizle (B4 scope dışı)
      final ok = await notifier.buyBuilding('crumb_collector');
      expect(ok, true);

      final purchases = logger.events.whereType<PurchaseMade>();
      expect(purchases, hasLength(1));
      final event = purchases.single;
      expect(event.installId, 'test-install-id');
      expect(event.buildingId, 'crumb_collector');
      expect(event.cost, 15);
      expect(event.ownedAfter, 1);
    });

    test('insufficient crumbs buyBuilding → NO emission [I19]', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      // 0 crumbs — satın alma başarısız
      final ok = await notifier.buyBuilding('crumb_collector');
      expect(ok, false);

      expect(logger.events.whereType<PurchaseMade>(), isEmpty,
          reason: 'Failed purchase → no emission [I19]');
    });

    test('unknown building id buyBuilding → NO emission', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      final ok = await notifier.buyBuilding('unknown_building');
      expect(ok, false);

      expect(logger.events.whereType<PurchaseMade>(), isEmpty);
    });
  });

  group('GameStateNotifier telemetry — UpgradePurchased (B4 [I19])', () {
    test('successful buyUpgrade → UpgradePurchased event emit', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      // 200 Crumbs için 200 tap
      for (var i = 0; i < 200; i++) {
        notifier.tapCrumb();
      }

      logger.events.clear();
      final ok = await notifier.buyUpgrade('golden_recipe_i');
      expect(ok, true);

      final purchases = logger.events.whereType<UpgradePurchased>();
      expect(purchases, hasLength(1));
      final event = purchases.single;
      expect(event.installId, 'test-install-id');
      expect(event.upgradeId, 'golden_recipe_i');
      expect(event.cost, 200);
    });

    test('already owned buyUpgrade → NO emission [I19]', () async {
      final logger = _CaptureLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final notifier = c.read(gameStateNotifierProvider.notifier);
      await c.read(gameStateNotifierProvider.future);

      for (var i = 0; i < 400; i++) {
        notifier.tapCrumb();
      }
      await notifier.buyUpgrade('golden_recipe_i');

      logger.events.clear();
      final ok = await notifier.buyUpgrade('golden_recipe_i'); // second buy
      expect(ok, false);

      expect(logger.events.whereType<UpgradePurchased>(), isEmpty,
          reason: 'Already owned → no re-emission [I19]');
    });
  });
}
```

**Import gerekli test dosyasına (eklenmeli):**
```dart
import 'dart:io';
```

- [ ] **Step 2: Run test — fail**

Run: `flutter test test/core/state/game_state_notifier_telemetry_test.dart`
Expected: FAIL — `GameStateNotifier.buyBuilding` + `buyUpgrade` emission henüz eklenmedi.

- [ ] **Step 3: Implementation — GameStateNotifier emission**

`lib/core/state/game_state_notifier.dart` içinde `buyBuilding` ve `buyUpgrade` metodlarını güncelle. Mevcut `buyBuilding`:

**Öncesi (örnek — mevcut kod):**
```dart
Future<bool> buyBuilding(String id) async {
  // ... validation
  final g = state.valueOrNull;
  if (g == null) return false;
  final cost = _buildingCost(id, g);
  if (!_canAfford(g, cost)) return false;
  if (!Production.knownBuildings.contains(id)) return false;

  final updated = g.copyWith(...);
  _persistSafe(updated, 'buyBuilding');
  return true;
}
```

**Sonrası (emission eklendi):**
```dart
Future<bool> buyBuilding(String id) async {
  final g = state.valueOrNull;
  if (g == null) return false;
  final cost = _buildingCost(id, g);
  if (!_canAfford(g, cost)) return false;
  if (!Production.knownBuildings.contains(id)) return false;

  final updated = g.copyWith(
    inventory: g.inventory.copyWith(r1Crumbs: g.inventory.r1Crumbs - cost),
    buildings: BuildingsState(
      owned: {
        ...g.buildings.owned,
        id: (g.buildings.owned[id] ?? 0) + 1,
      },
    ),
  );
  state = AsyncData(updated);
  _persistSafe(updated, 'buyBuilding');

  // B4 YENİ — telemetry emit (successful path only [I19])
  // Emission _persistSafe sonrası sync; crash window %0.01 kabul,
  // B5 analysis followup.
  final ownedAfter = updated.buildings.owned[id] ?? 0;
  ref.read(telemetryLoggerProvider).log(PurchaseMade(
    installId: resolveInstallIdForTelemetry(ref.read(installIdProvider)),
    buildingId: id,
    cost: cost,
    ownedAfter: ownedAfter,
  ));
  return true;
}
```

**Not:** Mevcut implementation detay farklı olabilir — mevcut state/copyWith pattern'i koru, yalnız `ref.read(telemetryLoggerProvider).log(...)` satırını `_persistSafe` SONRASINA + `return true` ÖNCESİNE ekle.

Aynı pattern `buyUpgrade` için:

```dart
Future<bool> buyUpgrade(String id) async {
  final g = state.valueOrNull;
  if (g == null) return false;
  if (g.upgrades.owned[id] == true) return false;  // already owned
  final cost = UpgradeDefs.baseCostFor(id);
  if (cost == 0) return false; // unknown
  if (g.inventory.r1Crumbs < cost) return false;

  final updated = g.copyWith(...);
  state = AsyncData(updated);
  _persistSafe(updated, 'buyUpgrade');

  // B4 YENİ
  ref.read(telemetryLoggerProvider).log(UpgradePurchased(
    installId: resolveInstallIdForTelemetry(ref.read(installIdProvider)),
    upgradeId: id,
    cost: cost,
  ));
  return true;
}
```

**Import eklenecek dosya başına (mevcutlara ek):**
```dart
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
```

- [ ] **Step 4: Run test — pass**

Run: `flutter test test/core/state/game_state_notifier_telemetry_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Analyze — compile fail T7 bekliyor**

Run: `flutter analyze`
Expected: **ERROR** hâlâ (T3 TutorialStarted.isReplay), T7'de çözülür.

- [ ] **Step 6: Commit**

```bash
git add lib/core/state/game_state_notifier.dart test/core/state/game_state_notifier_telemetry_test.dart
git commit -m "sprint-b4(T5): GameStateNotifier PurchaseMade + UpgradePurchased emission (successful path, [I19])"
```

---

## Task 6 (S): TutorialNotifier.reset() + consumeReplayFlag

**Amaç:** `TutorialNotifier` yeni `reset()` method — prefs clear + `_replayTriggered` flag flip + AsyncData fresh state. `consumeReplayFlag()` single-use ([I20]) — ilk reader true, sonraki false.

**Files:**
- Modify: `lib/core/tutorial/tutorial_notifier.dart`
- Modify: `test/core/tutorial/tutorial_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

`test/core/tutorial/tutorial_notifier_test.dart` içine yeni group ekle (main() kapanış `}` ÖNCESİNDE):

```dart
  group('TutorialNotifier.reset() + consumeReplayFlag (B4 [I20])', () {
    test('reset() → both prefs removed', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).reset();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_marked'), isNull);
      expect(prefs.getBool('crumbs.tutorial_completed'), isNull);
    });

    test('reset() → state fresh AsyncData defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).reset();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.firstLaunchMarked, false);
      expect(state.tutorialCompleted, false);
      expect(state.currentStep, null);
    });

    test('reset then consumeReplayFlag returns true', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);

      // Fresh start (no reset) → flag false
      final beforeReset =
          c.read(tutorialNotifierProvider.notifier).consumeReplayFlag();
      expect(beforeReset, false);

      // Reset → flag true
      await c.read(tutorialNotifierProvider.notifier).reset();
      final afterReset =
          c.read(tutorialNotifierProvider.notifier).consumeReplayFlag();
      expect(afterReset, true);
    });

    test('consumeReplayFlag single-use (second call returns false) [I20]',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).reset();

      final notifier = c.read(tutorialNotifierProvider.notifier);
      final first = notifier.consumeReplayFlag();
      final second = notifier.consumeReplayFlag();

      expect(first, true);
      expect(second, false,
          reason: 'Single-use: second call returns false [I20]');
    });
  });
```

**`buildContainer` helper varsa reuse et; yoksa dosyanın mevcut pattern'ini takip et (B2'de muhtemelen mevcut).**

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/tutorial/tutorial_notifier_test.dart`
Expected: FAIL — `reset()` method + `consumeReplayFlag()` yok.

- [ ] **Step 3: Implementation — TutorialNotifier.reset + consumeReplayFlag**

`lib/core/tutorial/tutorial_notifier.dart` içinde `TutorialNotifier` class'ına yeni field + method'lar ekle:

```dart
class TutorialNotifier extends AsyncNotifier<TutorialState> {
  // ... mevcut constants + fields

  bool _replayTriggered = false;

  // ... mevcut build(), start(), advance(), skip(), complete() methods

  /// Bir sonraki `start()` emit'inde `isReplay` ne olacak — `reset()` sonrası
  /// true döner, ilk okuyucu false'a sıfırlar (single-use). Invariant [I20].
  bool consumeReplayFlag() {
    final value = _replayTriggered;
    _replayTriggered = false;
    return value;
  }

  /// Tutorial state'i tamamen sıfırlar — Settings > Developer "Tutorial'i
  /// tekrar oyna" dan tetiklenir. Prefs clear + state fresh (null defaults).
  /// [FirstBootNotifier]'a dokunulmaz — AppInstall re-emit olmaz ([I18]).
  ///
  /// Concurrent call'lar `SharedPreferences` internal lock ile serialize
  /// edilir — idempotent.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyFirstLaunch);
    await prefs.remove(_prefKeyCompleted);
    _replayTriggered = true;
    state = const AsyncData(TutorialState(
      firstLaunchMarked: false,
      tutorialCompleted: false,
      currentStep: null,
    ));
  }
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/tutorial/tutorial_notifier_test.dart`
Expected: PASS — mevcut test'ler + 4 yeni B4 test.

- [ ] **Step 5: Analyze — compile fail hâlâ T7 bekliyor**

Run: `flutter analyze`
Expected: **ERROR** `tutorial_scaffold.dart` TutorialStarted.isReplay — T7.

- [ ] **Step 6: Commit**

```bash
git add lib/core/tutorial/tutorial_notifier.dart test/core/tutorial/tutorial_notifier_test.dart
git commit -m "sprint-b4(T6): TutorialNotifier.reset() + consumeReplayFlag single-use ([I20])"
```

---

## Task 7 (C): TutorialScaffold isReplay emission wiring

**Amaç:** `TutorialScaffold` postFrame emission'ına `isReplay` field — `consumeReplayFlag()` read + `TutorialStarted(isReplay: ...)`. Compile fail kapatır (T3 + T4 + T5 + T6 zincirin son halkası).

**Files:**
- Modify: `lib/features/tutorial/tutorial_scaffold.dart`

- [ ] **Step 1: Inspect current emission site**

`lib/features/tutorial/tutorial_scaffold.dart` içinde `TutorialStarted` emit edildiği yeri bul (B2'den):

```dart
if (postState?.currentStep == TutorialStep.tapCupcake) {
  _startedAt = DateTime.now();
  ref.read(telemetryLoggerProvider).log(
    TutorialStarted(
      installId: resolveInstallIdForTelemetry(ref.read(installIdProvider)),
    ),
  );
}
```

- [ ] **Step 2: Modify emission — add isReplay**

```dart
if (postState?.currentStep == TutorialStep.tapCupcake) {
  _startedAt = DateTime.now();
  final isReplay = ref
      .read(tutorialNotifierProvider.notifier)
      .consumeReplayFlag();
  ref.read(telemetryLoggerProvider).log(
    TutorialStarted(
      installId: resolveInstallIdForTelemetry(ref.read(installIdProvider)),
      isReplay: isReplay,
    ),
  );
}
```

- [ ] **Step 3: Analyze — compile GREEN restore**

Run: `flutter analyze`
Expected: **0 issue** (T3+T4+T5+T6+T7 atomic chain compile-green restore).

- [ ] **Step 4: Full suite verify**

Run: `flutter test -j 1`
Expected: PASS — ~235 test (219 B3 baseline + 4 B4-T1 + 2 B4-T2 + 7 B4-T3 event + 4 B4-T4 logger + 5 B4-T5 emission + 4 B4-T6 reset).

- [ ] **Step 5: Commit**

```bash
git add lib/features/tutorial/tutorial_scaffold.dart
git commit -m "sprint-b4(T7): TutorialScaffold isReplay emission wiring (compile-green restore)"
```

---

## Task 8 (C): developerVisibilityProvider

**Amaç:** `lib/features/settings/providers.dart` yeni dosya — `developerVisibilityProvider` (kDebugMode || CRASHLYTICS_TEST env gate, test override-able).

**Files:**
- Create: `lib/features/settings/providers.dart`

- [ ] **Step 1: Implementation**

Create `lib/features/settings/providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Developer subsection görünürlük gate'i.
/// - [kDebugMode]: her dev build'de visible
/// - `--dart-define=CRASHLYTICS_TEST=true`: release build'de QA/internal erişim
/// - Production release (flag yok): tamamen gizli — widget tree'de YOK
///
/// Test override:
///   ProviderScope(overrides: [
///     developerVisibilityProvider.overrideWithValue(true|false),
///   ])
///
/// `const bool.fromEnvironment` compile-time sabit — widget test'te doğrudan
/// manipüle edilemez. Provider wrapper test ergonomisini sağlar.
///
/// Production release gate (manual smoke zorunlu): `kDebugMode` test
/// ortamında her zaman true döner — automated test ile "release build'de
/// Developer section gizli" invariant'ı doğrulanamaz. DoD "Settings →
/// Developer production build'de gizli" manual smoke test zorunlu.
final developerVisibilityProvider = Provider<bool>((ref) {
  return kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST');
});
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/settings/providers.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/providers.dart
git commit -m "sprint-b4(T8): developerVisibilityProvider (kDebugMode || CRASHLYTICS_TEST gate)"
```

---

## Task 9 (C): AudioSettingsSection stub

**Amaç:** `AudioSettingsSection` — Music + SFX `SwitchListTile` stub (`onChanged: null` disabled, B5 hook).

**Files:**
- Create: `lib/features/settings/widgets/audio_settings_section.dart`
- Create: `test/features/settings/audio_settings_section_test.dart`

- [ ] **Step 1: Write smoke test**

Create `test/features/settings/audio_settings_section_test.dart`:

```dart
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AudioSettingsSection renders 2 disabled switches',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: const Scaffold(body: AudioSettingsSection()),
    ));
    await tester.pumpAndSettle();

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2));

    // İki switch de disabled (onChanged null) — B5 stub
    final switch1 = tester.widget<SwitchListTile>(switches.at(0));
    final switch2 = tester.widget<SwitchListTile>(switches.at(1));
    expect(switch1.onChanged, isNull);
    expect(switch2.onChanged, isNull);
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/features/settings/audio_settings_section_test.dart`
Expected: FAIL — widget + l10n key eksik.

- [ ] **Step 3: Implementation**

Create `lib/features/settings/widgets/audio_settings_section.dart`:

```dart
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Settings > Ses ve Müzik — B4'te stub; B5'te audio layer geldiğinde
/// `onChanged` handler'ları `audioSettingsProvider` üzerinden bağlanır.
class AudioSettingsSection extends StatelessWidget {
  const AudioSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.settingsAudioSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SwitchListTile(
          title: Text(s.settingsAudioMusicToggle),
          subtitle: Text(s.settingsAudioStubHint),
          value: false,
          onChanged: null, // B5 hook
        ),
        SwitchListTile(
          title: Text(s.settingsAudioSfxToggle),
          subtitle: Text(s.settingsAudioStubHint),
          value: false,
          onChanged: null,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: l10n key hazır değil — T12 öncesi compile fail**

Run: `flutter test test/features/settings/audio_settings_section_test.dart`
Expected: **FAIL** — `s.settingsAudioSection` / `settingsAudioMusicToggle` / `settingsAudioSfxToggle` / `settingsAudioStubHint` yok.

**Sıra: T12 (l10n) T9 + T10 + T11 ÖNCESİ gerekli.** T12'yi önce çalıştır veya bu task'ı T12 sonrasına ertele.

**Plan execution order fix:** T9 → T12 swap. Aşağıdaki task sırası:
- T8 → T12 (l10n) → T9 → T10 → T11 → ...

- [ ] **Step 5: Commit (after T12 completes l10n)**

Bu task commit T12'den sonra gerçekleşir. Aşağıdaki commit komutu T12 sonrası çalıştır:

```bash
git add lib/features/settings/widgets/audio_settings_section.dart \
        test/features/settings/audio_settings_section_test.dart
git commit -m "sprint-b4(T9): AudioSettingsSection stub widget (B5 hook)"
```

---

## Task 10 (S): DeveloperSettingsSection + TutorialReplayDialog

**Amaç:** `DeveloperSettingsSection` 2 ListTile (Test Crash + Tutorial Replay) + `TutorialReplayDialog` confirmation. Test Crash `FirebaseBootstrap.isInitialized` guard + snackbar fallback.

**Files:**
- Create: `lib/features/settings/widgets/developer_settings_section.dart`
- Create: `lib/features/settings/widgets/tutorial_replay_dialog.dart`
- Create: `test/features/settings/developer_settings_section_test.dart`
- Create: `test/features/settings/tutorial_replay_dialog_test.dart`

- [ ] **Step 1: TutorialReplayDialog impl + test**

Create `lib/features/settings/widgets/tutorial_replay_dialog.dart`:

```dart
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class TutorialReplayDialog extends StatelessWidget {
  const TutorialReplayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    return AlertDialog(
      title: Text(s.settingsDevTutorialReplayDialogTitle),
      content: Text(s.settingsDevTutorialReplayDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.settingsDevTutorialReplayCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.settingsDevTutorialReplayConfirm),
        ),
      ],
    );
  }
}
```

Create `test/features/settings/tutorial_replay_dialog_test.dart`:

```dart
import 'package:crumbs/features/settings/widgets/tutorial_replay_dialog.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> _pumpDialog(
    WidgetTester tester, {
    required void Function(bool?) onResult,
  }) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const TutorialReplayDialog(),
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('Confirm button returns true', (tester) async {
    bool? result;
    await _pumpDialog(tester, onResult: (v) => result = v);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evet, yeniden oyna'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('Cancel button returns false', (tester) async {
    bool? result;
    await _pumpDialog(tester, onResult: (v) => result = v);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('Dialog body contains reassurance copy', (tester) async {
    bool? result;
    await _pumpDialog(tester, onResult: (v) => result = v);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('kaybolmaz'), findsOneWidget);
  });
}
```

- [ ] **Step 2: DeveloperSettingsSection impl + test**

Create `lib/features/settings/widgets/developer_settings_section.dart`:

```dart
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/core/tutorial/tutorial_providers.dart';
import 'package:crumbs/features/settings/widgets/tutorial_replay_dialog.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperSettingsSection extends ConsumerWidget {
  const DeveloperSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.settingsDevSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: Text(s.settingsDevTestCrash),
          subtitle: Text(s.settingsDevTestCrashHint),
          onTap: () => _onTestCrashTap(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.replay),
          title: Text(s.settingsDevTutorialReplay),
          subtitle: Text(s.settingsDevTutorialReplayHint),
          onTap: () => _onTutorialReplayTap(context, ref),
        ),
      ],
    );
  }

  void _onTestCrashTap(BuildContext context, AppStrings s) {
    if (!FirebaseBootstrap.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsDevTestCrashNotInit)),
      );
      return;
    }
    FirebaseCrashlytics.instance.crash();
  }

  Future<void> _onTutorialReplayTap(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const TutorialReplayDialog(),
    );
    if (confirmed ?? false) {
      await ref.read(tutorialNotifierProvider.notifier).reset();
    }
  }
}
```

Create `test/features/settings/developer_settings_section_test.dart`:

```dart
import 'package:crumbs/features/settings/widgets/developer_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _appUnderTest({ProviderContainer? container}) {
    return UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(body: DeveloperSettingsSection()),
      ),
    );
  }

  testWidgets('Test Crash button isInitialized=false → snackbar shown',
      (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Test env: FirebaseBootstrap.isInitialized false (default) — snackbar'ı
    // verify eder, crash çağrısı yapılmaz.

    await tester.pumpWidget(_appUnderTest(container: c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Crash Gönder'));
    await tester.pumpAndSettle();

    // Snackbar rendered (not-init fallback)
    expect(find.textContaining('Firebase başlatılmadı'), findsOneWidget);
  });

  testWidgets('Tutorial Replay button opens dialog', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_appUnderTest(container: c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tutorial\'i Tekrar Oyna'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Tutorial yeniden oynatılsın mı?'),
      findsOneWidget,
    );
  });

  testWidgets('Widget structure smoke — 2 ListTile + Divider', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(_appUnderTest(container: c));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.byType(Divider), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests — fail (l10n key'ler T12 bekliyor)**

Run: `flutter test test/features/settings/`
Expected: FAIL — l10n key'ler yok.

- [ ] **Step 4: Commit (T12'den sonra)**

```bash
git add lib/features/settings/widgets/developer_settings_section.dart \
        lib/features/settings/widgets/tutorial_replay_dialog.dart \
        test/features/settings/developer_settings_section_test.dart \
        test/features/settings/tutorial_replay_dialog_test.dart
git commit -m "sprint-b4(T10): DeveloperSettingsSection + TutorialReplayDialog (isInitialized guard)"
```

---

## Task 11 (C): SettingsPage rewrite

**Amaç:** `SettingsPage` placeholder → 2-section `ConsumerWidget` (Audio + Developer flag-gated).

**Files:**
- Modify (rewrite): `lib/features/settings/settings_page.dart`
- Create: `test/features/settings/settings_page_test.dart`

- [ ] **Step 1: Rewrite SettingsPage**

Replace `lib/features/settings/settings_page.dart`:

```dart
import 'package:crumbs/features/settings/providers.dart';
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/features/settings/widgets/developer_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    final showDev = ref.watch(developerVisibilityProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        children: [
          const AudioSettingsSection(),
          if (showDev) const DeveloperSettingsSection(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write test — dev gate override**

Create `test/features/settings/settings_page_test.dart`:

```dart
import 'package:crumbs/features/settings/providers.dart';
import 'package:crumbs/features/settings/settings_page.dart';
import 'package:crumbs/features/settings/widgets/audio_settings_section.dart';
import 'package:crumbs/features/settings/widgets/developer_settings_section.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _appUnderTest(bool showDev) {
    return ProviderScope(
      overrides: [developerVisibilityProvider.overrideWithValue(showDev)],
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const SettingsPage(),
      ),
    );
  }

  testWidgets('default dev flag true → 2 section render', (tester) async {
    await tester.pumpWidget(_appUnderTest(true));
    await tester.pumpAndSettle();

    expect(find.byType(AudioSettingsSection), findsOneWidget);
    expect(find.byType(DeveloperSettingsSection), findsOneWidget);
  });

  testWidgets('dev flag false → only Audio section (Developer hidden)',
      (tester) async {
    await tester.pumpWidget(_appUnderTest(false));
    await tester.pumpAndSettle();

    expect(find.byType(AudioSettingsSection), findsOneWidget);
    expect(find.byType(DeveloperSettingsSection), findsNothing);
  });
}
```

- [ ] **Step 3: Run (T12 sonrası)**

Run: `flutter test test/features/settings/settings_page_test.dart`
Expected: PASS (2 test, l10n T12'de ready).

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_page.dart \
        test/features/settings/settings_page_test.dart
git commit -m "sprint-b4(T11): SettingsPage rewrite — 2-section + developerVisibilityProvider watch"
```

---

## Task 12 (C): tr.arb — 13 yeni key + codegen

**Amaç:** Settings ekranı section/dev item/dialog string'leri için `tr.arb`'a 13 yeni key ekle, AppStrings codegen tetikle. **T9, T10, T11 task'larının compile bağımlılığı — bu task onlardan ÖNCE yapılır (plan order fix).**

**Files:**
- Modify: `lib/l10n/tr.arb`

- [ ] **Step 1: Append keys to tr.arb**

`lib/l10n/tr.arb` sonundaki kapanış `}`'den ÖNCE ekle (son existing key'den virgül kontrolü):

```json
  "settingsAudioSection": "Ses ve Müzik",
  "settingsAudioMusicToggle": "Müzik",
  "settingsAudioSfxToggle": "Efektler",
  "settingsAudioStubHint": "Yakında aktif olacak",
  "settingsDevSection": "Geliştirici",
  "settingsDevTestCrash": "Test Crash Gönder",
  "settingsDevTestCrashHint": "Crashlytics doğrulama — cihaz yeniden açıldığında rapor gönderilir",
  "settingsDevTestCrashNotInit": "Firebase başlatılmadı — crash rapor edilmez",
  "settingsDevTutorialReplay": "Tutorial'i Tekrar Oyna",
  "settingsDevTutorialReplayHint": "3 adımlı girişi yeniden başlatır",
  "settingsDevTutorialReplayDialogTitle": "Tutorial yeniden oynatılsın mı?",
  "settingsDevTutorialReplayDialogBody": "İlerlemen (binalar, upgrade'ler, Crumbs) kaybolmaz. Yalnız tutorial adımları yeniden gösterilir.",
  "settingsDevTutorialReplayCancel": "Vazgeç",
  "settingsDevTutorialReplayConfirm": "Evet, yeniden oyna"
```

Toplam 14 key (not: spec'te 13 dedi; `settingsDevTestCrashNotInit` dahil 14 oldu — Fix #2 sonucu).

- [ ] **Step 2: Codegen**

```bash
flutter pub get
```

Expected: `flutter pub get` otomatik `gen-l10n` tetikler; `lib/l10n/app_strings.dart` + `app_strings_tr.dart` regenerate edilir.

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze`
Expected: 0 issue (T9/T10/T11 widget dosyaları compile ediyor çünkü string key'ler hazır).

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/tr.arb lib/l10n/app_strings.dart lib/l10n/app_strings_tr.dart
git commit -m "sprint-b4(T12): tr.arb 14 Settings/Developer/Dialog strings + codegen"
```

---

**NOT on task ordering:** Plan'ın gerçek execution order'ı: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → **T12 (l10n before widgets)** → T9 → T10 → T11 → T13 → T14. DAG'da T12 → T9/T10/T11 compile dep zaten belirtilmişti. Subagent dispatch sırasında bu sıra korunur.

---

## Task 13 (S) ★: Integration test — 3 cold start senaryosu + isReplay invariant

**Amaç:** `integration_test/tutorial_telemetry_integration_test.dart` 3 senaryo × AppInstall emission count assertion + `isReplay` invariant [I18]/[I20].

**Files:**
- Modify: `integration_test/tutorial_telemetry_integration_test.dart`

- [ ] **Step 1: Inspect current integration test**

`integration_test/tutorial_telemetry_integration_test.dart` mevcut testler (B2 + B3'ten):
- Test 1: cold start emits AppInstall + SessionStart + TutorialStarted
- Test 2: second cold start → no TutorialStarted
- Test 3: onPause emits SessionEnd

B4 update: **her senaryo fresh ProviderContainer + fresh setMockInitialValues** ile state isolation.

- [ ] **Step 2: Update Test 1 — Fresh B4 install + isReplay=false**

Test 1'e invariant [I18] + isReplay=false assertion ekle:

```dart
    testWidgets('fresh B4 install: AppInstall + TutorialStarted(isReplay=false)',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // ... existing setup

      // Mevcut assertions korunur
      expect(logger.events.whereType<AppInstall>(), hasLength(1));

      // B4 YENİ — TutorialStarted isReplay=false
      final tutorialEvents = logger.events.whereType<TutorialStarted>();
      expect(tutorialEvents, hasLength(1));
      expect(tutorialEvents.single.isReplay, false,
          reason: 'fresh install — not replay');

      // [I15] korunur
      // [I18] implicit — tutorialState disjoint from firstBoot (fresh path)
    });
```

- [ ] **Step 3: Add Test 4 — Pre-B4 migration**

Yeni test ekle (Test 3'ten sonra):

```dart
    testWidgets('pre-B4 migration: install_id mevcut → 0 AppInstall [I18]',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'pre-b4-install-uuid',
        'crumbs.install_created_at': DateTime.now().toIso8601String(),
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot sim — FirstBootNotifier pre-B4 user detect → observed=false
      await c.read(installIdProvider.notifier).ensureLoaded();
      final isFirstLaunch =
          await c.read(firstBootProvider.notifier).ensureObserved();
      expect(isFirstLaunch, false, reason: 'pre-B4 backfill');

      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: isFirstLaunch);

      // [I18]: AppInstall emit edilmemeli
      expect(logger.events.whereType<AppInstall>(), isEmpty,
          reason: 'pre-B4 migration — AppInstall suppressed [I18]');

      // SessionStart yine emit edilir (her launch'ta)
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
    });
```

- [ ] **Step 4: Add Test 5 — Post-reset replay isReplay=true**

```dart
    testWidgets('post-reset replay: TutorialStarted isReplay=true [I20]',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_id': 'test-id',
        'crumbs.install_created_at': DateTime.now().toIso8601String(),
        'crumbs.first_launch_observed': true,
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot sim — second launch (AppInstall edilmez)
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(firstBootProvider.notifier).ensureObserved();
      await c.read(gameStateNotifierProvider.future);
      await c.read(tutorialNotifierProvider.future);
      c
          .read(sessionControllerProvider)
          .onLaunch(isFirstLaunch: false);

      logger.events.clear(); // pre-reset noise

      // Reset → sonraki start isReplay=true
      await c.read(tutorialNotifierProvider.notifier).reset();
      final isReplay = c
          .read(tutorialNotifierProvider.notifier)
          .consumeReplayFlag();
      // Simulate TutorialScaffold emission
      if (isReplay) {
        logger.log(TutorialStarted(
          installId: resolveInstallIdForTelemetry(
            c.read(installIdProvider),
          ),
          isReplay: true,
        ));
      }

      // [I18]: reset AppInstall re-emit ETMEZ
      expect(logger.events.whereType<AppInstall>(), isEmpty,
          reason: 'tutorial reset — no AppInstall [I18]');

      // [I20]: TutorialStarted isReplay=true
      final tutorialEvents = logger.events.whereType<TutorialStarted>();
      expect(tutorialEvents, hasLength(1));
      expect(tutorialEvents.single.isReplay, true,
          reason: 'reset flow — isReplay=true [I20]');
    });
```

- [ ] **Step 5: Analyze + run**

Run: `flutter analyze integration_test/tutorial_telemetry_integration_test.dart`
Expected: 0 issue.

(Integration test device runner Firebase olmadan fail eder — B3 pattern. Compile OK yeterli B4 scope için.)

- [ ] **Step 6: Commit**

```bash
git add integration_test/tutorial_telemetry_integration_test.dart
git commit -m "sprint-b4(T13): integration test — 3 cold start senaryosu + [I18]/[I20] invariants"
```

---

## Task 14 (C): Docs — telemetry.md + CLAUDE.md §12 + backlog cleanup + lessons.md

**Amaç:** B4 completion dokümantasyonu — telemetry schemas + invariants + gotcha'lar + backlog done marker + B3 review takeaway'leri.

**Files:**
- Modify: `docs/telemetry.md`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/backlog/sprint-b3-backlog.md`
- Create or Modify: `_dev/tasks/lessons.md`

- [ ] **Step 1: telemetry.md — 2 yeni event + TutorialStarted update + invariants**

`docs/telemetry.md` "Events (Sprint B2)" bölümünün sonuna ekle:

```markdown
### purchase_made (B4)
Fired on successful `GameStateNotifier.buyBuilding` — failed/rejected path'lerde emit YOK ([I19]).

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null rule |
| building_id | String | Bina ID (`crumb_collector`, `oven`, `bakery_line`) |
| cost | int | Crumbs cost at time of purchase (economy §5 baseCost × growth^owned) |
| owned_after | int | Bina count after this purchase |

### upgrade_purchased (B4)
Fired on successful `GameStateNotifier.buyUpgrade` — already owned / insufficient crumbs / unknown id path'lerinde emit YOK ([I19]).

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null rule |
| upgrade_id | String | Upgrade ID (`golden_recipe_i`, ...) |
| cost | int | Crumbs cost |
```

TutorialStarted update:

```markdown
### tutorial_started (updated B4)
Fired once when `TutorialScaffold` postFrame callback transitions to `tapCupcake`. `isReplay` B4'te required field.

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule |
| is_replay | bool (→ int coerced in Firebase: 1/0) | `reset()` sonrası start → true; fresh install → false. Cohort analytics: `WHERE is_replay=0` → genuine funnel denominator [I20] |
```

Invariants bölümüne ekle:

```markdown
- **[I18]** `TutorialNotifier.reset()` AppInstall re-emit ETMEZ — FirstBootNotifier ve TutorialNotifier prefs disjoint
- **[I19]** PurchaseMade + UpgradePurchased yalnız successful purchase path'ten emit — failed/rejected'de no event
- **[I20]** TutorialStarted.isReplay single-use flag — reset sonrası ilk start true, sonraki false (consumeReplayFlag pattern)
```

- [ ] **Step 2: CLAUDE.md §12 — FirstBootNotifier gotcha**

`CLAUDE.md` §12 son bullet'tan sonra ekle:

```markdown
- **FirstBootNotifier disjoint pattern (B4):** `lib/core/launch/first_boot_notifier.dart` — AppInstall trigger source olarak `crumbs.first_launch_observed` bool pref kullanır. `tutorialState.firstLaunchMarked` B3/earlier'da trigger'dı, B4'te sadece tutorial semantic korur. TutorialNotifier.reset() bu provider'a dokunmaz — tutorial replay AppInstall re-emit etmez (invariant [I18]). Migration proxy: `install_id` varlığı B1+ user sinyali — pre-B4 install'larda backfill observed=true (AppInstall suppressed). Pattern'ı yeni launch-gated event'lerde reuse et: separate pref, separate Notifier, disjoint from other state providers.
- **consumeReplayFlag single-use pattern (B4):** `TutorialNotifier.consumeReplayFlag()` in-memory bool `_replayTriggered` single-use reader — `reset()` true'ya flip'ler, ilk caller false'a sıfırlar. `TutorialStarted.isReplay` payload'ında kullanılır (invariant [I20]). Pattern: future telemetry event'lerinde "was this triggered by X vs default flow" sinyali için reuse edilebilir.
```

- [ ] **Step 3: Backlog cleanup — B3 §1/4-5 done**

`docs/superpowers/backlog/sprint-b3-backlog.md` §1 içinde:

```markdown
- ✅ **Settings → "Tutorial'i tekrar oyna" toggle** — Sprint B4 T6 + T10 (TutorialNotifier.reset + Settings Developer dialog)
- ✅ **Purchase / Upgrade event'leri** — Sprint B4 T3 + T5 (PurchaseMade + UpgradePurchased, [I19] emission gate)
- [ ] **ResearchComplete event** — Sprint C (research impl'yle birlikte, emit call site gelince)
- [ ] **GameState hydration side-effect telemetry** — B5 backlog
- [ ] **Step 2 granularity split** — B5 backlog (tutorial funnel analytics gerekirse)
```

- [ ] **Step 4: lessons.md — B3 review takeaway'leri**

Create or append `_dev/tasks/lessons.md`:

```markdown
# Lessons Learned

## Sprint B3 → B4 transition insights

### FirebaseBootstrap static state — test coverage limitation
**Issue:** `FirebaseBootstrap._initialized` static + private. Widget test'te `isInitialized=true` simulate edilemez — Crashlytics test button full path manual QA gerekir.

**Root cause:** Static state sharing across tests + private field access pattern. Provider wrapper B5 followup — `FirebaseBootstrap state` Provider<bool> ile exposable.

**Prevention rule:** Production state provider wrapper first, static state only for pre-provider init ownership.

### Firebase compliance regex invariant — scaling pattern
**Issue:** TelemetryEvent eklendiğinde regex invariant test events list manuel güncellenir. Unutulursa new event Firebase Analytics kurallarına uymayabilir.

**Root cause:** Parameterized test events list hard-coded; no introspection.

**Prevention rule:** New TelemetryEvent eklenince T4-equivalent invariant test güncellemesi DoD checklist'inde olsun. Future: sealed class registry (`TelemetryEvent.allSubtypes`) derive edilebilirse otomatik.

### CI secret decode fork-safety
**Issue:** B3 ilk deploy CI'da `firebase_options.dart` eksik → analyze fail. Fork PR'larda secret erişimi yok.

**Root cause:** Decode step `env != ''` guard ilk deploy'da eksikti.

**Prevention rule:** Secret-dependent decode step her zaman fork-safe fallback'e sahip olmalı — template copy (`cp template.dart → target.dart`). Fork PR'larda template default path.
```

- [ ] **Step 5: Commit**

```bash
git add docs/telemetry.md CLAUDE.md \
        docs/superpowers/backlog/sprint-b3-backlog.md \
        _dev/tasks/lessons.md
git commit -m "sprint-b4(T14): docs — telemetry.md events + CLAUDE.md §12 gotchas + backlog done + lessons.md"
```

---

## Final Verification (post-T14)

```bash
# Lint + typecheck
flutter analyze
# Expected: No issues found!

# Full test suite
flutter test -j 1
# Expected: ~240 tests passing (baseline 219 + B4 yenileri ~20)

# Integration test (syntactically valid, Firebase device fail OK)
flutter test integration_test/tutorial_telemetry_integration_test.dart 2>&1 | tail -5
# Expected: Firebase Analytics plugin build fail (flutterfire configure eksik — B3 stub)

# Git log — commit grain
git log --oneline main..HEAD | head -20
# Expected: ~15-17 commit (sprint-b4(T1) → sprint-b4(T14))

# PR hazırlığı
git push -u origin sprint/b4-settings-dev-experience
gh pr create --title "Sprint B4 — Settings + Developer Experience + Telemetry Events" \
  --body "$(head -60 docs/superpowers/specs/2026-04-18-sprint-b4-settings-dev-experience-design.md)"
```

**DoD checklist (spec §6.2):**
- [ ] flutter analyze clean
- [ ] flutter test -j 1 100% pass (hedef ~240)
- [ ] Fork PR CI yeşil (B3 pattern korunur)
- [ ] Invariants [I18]-[I20] regression test'te assert edilir
- [ ] docs/telemetry.md 3 event update (PurchaseMade + UpgradePurchased + TutorialStarted.is_replay) + [I18]-[I20] invariants
- [ ] CLAUDE.md §12 FirstBootNotifier + consumeReplayFlag pattern gotcha'ları
- [ ] B3 backlog §1/4-5 done marker
- [ ] _dev/tasks/lessons.md — B3 review takeaway'leri
- [ ] Manual smoke: Settings → Developer → Tutorial Replay dialog → confirm → tutorial Step 1 yeniden görünür
- [ ] Manual smoke: Settings → Developer section production build'de gizli

---

## Post-plan self-review

**Spec coverage:**
- §1.1 FirstBootNotifier + migration proxy → T1 ✓
- §1.1 AppInstall trigger refactor → T2 ✓
- §1.1 PurchaseMade event → T3 + T5 ✓
- §1.1 UpgradePurchased event → T3 + T5 ✓
- §1.1 TutorialStarted.isReplay → T3 + T6 + T7 ✓
- §1.1 Settings 2-section → T8 + T9 + T11 ✓
- §1.1 Developer subsection → T10 ✓
- §1.1 Tutorial replay → T6 + T10 ✓
- §1.1 Crashlytics isInitialized guard → T10 ✓
- §1.1 Docs update → T14 ✓
- §3 FirstBootNotifier detail → T1 ✓
- §4.1 PurchaseMade shape → T3 ✓
- §4.2 UpgradePurchased shape → T3 ✓
- §4.3 TutorialStarted isReplay → T3 ✓
- §4.4 Firebase compliance → T4 ✓
- §4.5 GameStateNotifier emission → T5 ✓
- §4.6 TutorialNotifier.reset + consumeReplayFlag → T6 ✓
- §5 Settings + Dev + Dialog → T8 + T9 + T10 + T11 + T12 ✓
- §6 Invariants [I18]-[I20] → T1/T5/T6/T13 assertions ✓
- §7 Testing strategy → T1-T7/T9-T13 mirror ✓
- §8 14 task → one-to-one ✓
- §9 DAG → plan başı ✓
- §10 Risks → plan commit notları + task warning'leri ✓
- §11 Rollback → spec referansı ✓
- §12 B5 Followups → lessons.md + spec referansı ✓

**Placeholder scan:** "TBD", "TODO", "implement later", "fill in details" — **yok**.

**Type consistency:**
- `FirstBootNotifier.ensureObserved() → Future<bool>` (T1)
- `PurchaseMade(installId, buildingId, cost, ownedAfter)` (T3, T5)
- `UpgradePurchased(installId, upgradeId, cost)` (T3, T5)
- `TutorialStarted(installId, isReplay)` (T3, T7)
- `consumeReplayFlag() → bool` (T6, T7)
- `reset() → Future<void>` (T6, T10 callsite)
- `developerVisibilityProvider = Provider<bool>` (T8, T10, T11)
- `resolveInstallIdForTelemetry(String?)` (T5 — B3 signature korunur)

Tüm task'larda tutarlı.
