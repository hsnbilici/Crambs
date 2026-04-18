# Sprint B4 — Settings + Developer Experience + Telemetry Event Catalog Design

**Hedef:** Settings ekranı gerçek implementation (placeholder → 2-section real), Developer subsection (flag-gated test crash + tutorial replay), TutorialNotifier.reset() + TutorialStarted.isReplay cohort analytics integrity, PurchaseMade + UpgradePurchased telemetry events, AppInstall trigger canonical form (FirstBootNotifier disjoint from tutorial state).

**Sonraki:** Sprint B5 (audio layer — Settings > Ses & Müzik aktif + music/sfx engine). Sprint C (R2 Research Shards + 3 bina daha + Research Lab + ResearchComplete event).

**Tarih:** 2026-04-18
**Referans:** `cookie_clicker_derivative_prd.md §6.10 (Settings), §11 (telemetry)`, `docs/telemetry.md`, `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md`, `CLAUDE.md §2/§12`

---

## 1. Kapsam

### 1.1 In Scope (B4)

- **FirstBootNotifier + AppInstall trigger refactor:**
  - `lib/core/launch/first_boot_notifier.dart` — `Notifier<bool?>` + `ensureObserved()` method
  - Pref key: `crumbs.first_launch_observed` (yeni B4 key)
  - **Migration proxy:** `install_id` varlığı (B1'den itibaren evrensel) pre-B4 user sinyali — backfill observed=true, AppInstall emit edilmez
  - AppBootstrap step b' rewire — `isFirstLaunch` artık `firstBootProvider.ensureObserved()` döndüsünden okunur (tutorial state disjoint)
- **Telemetry event catalog expansion:**
  - `PurchaseMade(installId, buildingId, cost, ownedAfter)` — `GameStateNotifier.buyBuilding` successful path'ten emit
  - `UpgradePurchased(installId, upgradeId, cost)` — `GameStateNotifier.buyUpgrade` successful path'ten emit
  - `TutorialStarted.isReplay: bool` yeni required field — reset sonrası start → true (cohort analytics integrity)
  - Firebase regex invariant test events list 6'ya genişler
- **Settings ekranı gerçek implementation:**
  - `lib/features/settings/settings_page.dart` rewrite — 2 section (Audio stub + Developer flag-gated)
  - `lib/features/settings/providers.dart` — `developerVisibilityProvider` (kDebugMode || dart-define gate, test override-able)
  - `AudioSettingsSection` — Music + SFX switch'ler `onChanged: null` stub (B5 hook)
  - `DeveloperSettingsSection` — Test Crash button + Tutorial Replay button (her ikisi de dev-visible)
- **Tutorial replay:**
  - `TutorialNotifier.reset()` — prefs clear (firstLaunchMarked + tutorialCompleted) + AsyncData fresh state
  - `consumeReplayFlag()` single-use flag — reset sonrası start → isReplay=true emit
  - `TutorialReplayDialog` confirmation — "İlerlemen kaybolmaz" reassurance copy
- **Crashlytics test button isInitialized guard** — snackbar fallback (Firebase init fail'de net UX)
- **docs updates:** telemetry.md 2 yeni event + TutorialStarted.is_replay; CLAUDE.md §12 FirstBootNotifier gotcha + migration proxy pattern

### 1.2 Out of Scope (B5+)

- `ResearchComplete` event — research tree Sprint C'de eklenecek, emit call site olmadan shape tanımı YAGNI
- Audio implementation (Settings > Ses & Müzik stub → B5'te active impl + audio layer)
- Language selector / i18n expansion (TR-only MVP)
- Privacy policy link, terms of service (legal B6)
- Developer — telemetry event viewer, live logger tail, analytics dashboard link (post-MVP debug tooling)
- `AppLaunchCountNotifier` (int counter) — B4'te sadece boolean FirstBootNotifier; counter + SessionStart payload extension B5 backlog
- `FirebaseBootstrap` state provider wrapper (Crashlytics test button widget test zorluğu) — B5 followup
- Purchase telemetry ordering swap (emit-then-persist) — crash window %0.01 kabul; B5 analysis
- `FirebaseCrashlytics.log(breadcrumb)` paralel yazım
- Settings persistence beyond tutorial prefs (audio prefs etc — B5)

### 1.3 Design assumptions

- B3 PR #5 merge edilmiş olmalı (main'de). B4 branch `main`'den çıkar: `sprint/b4-settings-dev-experience`
- B3'ten korunan state: `install_id`, `install_created_at` (device-local), `first_launch_marked`, `tutorial_completed` prefs mevcut
- `InstallIdNotifier`, `SessionController`, `TelemetryLogger` interface, `TutorialNotifier` (AsyncNotifier) değişmez mimarı altyapı
- B2'den `TutorialScaffold` + `TutorialStarted`/`TutorialCompleted` emission pattern
- Firebase Analytics bool→int coercion B3'ten aktif — `is_replay: bool` otomatik int convert
- TelemetryEvent sealed hierarchy korunur (B1 [I1] pattern)

---

## 2. Architecture

### 2.1 Yeni modüller

```
lib/core/launch/                         [YENİ dizin]
└── first_boot_notifier.dart             [YENİ]
      └── class FirstBootNotifier extends Notifier<bool?>
          ├── static const _prefKey = 'crumbs.first_launch_observed'
          ├── build() → null (pre-ensureObserved state)
          └── ensureObserved() → Future<bool>
              ├── Pre-B4 migration: install_id pref varsa observed=true backfill
              └── Fresh B4 install: observed=true write + state=true

lib/features/settings/
├── providers.dart                       [YENİ]
│     └── developerVisibilityProvider (Provider<bool>)
│         └── kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST')
├── widgets/
│   ├── audio_settings_section.dart      [YENİ]
│   │     └── AudioSettingsSection — Music + SFX SwitchListTile onChanged:null stub
│   ├── developer_settings_section.dart  [YENİ]
│   │     └── DeveloperSettingsSection (ConsumerWidget)
│   │         ├── Test Crash ListTile — isInitialized guard + snackbar fallback
│   │         └── Tutorial Replay ListTile → dialog
│   └── tutorial_replay_dialog.dart      [YENİ]
│         └── TutorialReplayDialog — Confirm / Cancel

lib/core/telemetry/
└── telemetry_event.dart                 [MODIFIED]
      ├── PurchaseMade (YENİ)
      ├── UpgradePurchased (YENİ)
      └── TutorialStarted (MODIFIED) — +isReplay required field

lib/core/tutorial/
└── tutorial_notifier.dart               [MODIFIED]
      ├── bool _replayTriggered private state
      ├── bool consumeReplayFlag() — single-use
      └── reset() — prefs clear + flip flag + AsyncData fresh
```

### 2.2 Değişen modüller

```
lib/app/boot/
└── app_bootstrap.dart                   [MODIFIED]
      └── step b' (B4 YENİ):
          final isFirstLaunch = await firstBootProvider.ensureObserved();
          ...
          step f: sessionController.onLaunch(isFirstLaunch: isFirstLaunch)
          (B3 pattern'den değişim: tutorialState.firstLaunchMarked yerine
           firstBootProvider)

lib/core/state/
└── game_state_notifier.dart             [MODIFIED]
      ├── buyBuilding success sonrası → PurchaseMade emit
      │   (_persistSafe sonrası, sync; crash window %0.01 kabul — B5 analysis)
      └── buyUpgrade success sonrası → UpgradePurchased emit

lib/features/settings/
└── settings_page.dart                   [REWRITE]
      ├── Placeholder → ListView(children: [Audio, Developer (gated)])
      └── ConsumerWidget — developerVisibilityProvider watch

lib/features/tutorial/
└── tutorial_scaffold.dart               [MODIFIED]
      └── TutorialStarted emission:
          final isReplay = notifier.consumeReplayFlag();
          logger.log(TutorialStarted(installId: ..., isReplay: isReplay))

lib/l10n/tr.arb                          [MODIFIED]
      └── 13 yeni key (Settings sections, dev items, dialog strings,
                       Crashlytics not-init snackbar)

CLAUDE.md                                [MODIFIED]
      └── §12 FirstBootNotifier disjoint pattern + migration proxy gotcha

docs/telemetry.md                        [MODIFIED]
      ├── PurchaseMade schema
      ├── UpgradePurchased schema
      ├── TutorialStarted update — is_replay field
      └── Invariants [I18]-[I20]

docs/superpowers/backlog/
└── sprint-b3-backlog.md                 [MODIFIED]
      └── §1/4 (Settings tutorial replay), §1/5 (purchase events) ✅ done marker
```

### 2.3 Test yapısı

```
test/core/launch/
└── first_boot_notifier_test.dart        [YENİ]
      ├── fresh B4 install (no prefs) → ensureObserved true + pref write
      ├── pre-B4 migration (install_id mevcut, observed yok) → false + backfill
      ├── second boot (observed=true pref) → false idempotent
      └── B4 fresh install after first boot → idempotent (observed stays)

test/core/telemetry/
├── telemetry_event_test.dart            [MODIFIED — +5 test]
│     ├── PurchaseMade eventName + payload shape (4 field)
│     ├── UpgradePurchased eventName + payload shape (3 field)
│     └── TutorialStarted.isReplay field + payload update
├── firebase_analytics_logger_test.dart  [MODIFIED — +4 test]
│     ├── PurchaseMade log() → logEvent shape
│     ├── UpgradePurchased log() → logEvent shape
│     ├── TutorialStarted.isReplay=true → 1 coercion in payload
│     └── Regex events list genişler (6 event → 12 compliance test)
└── session_controller_test.dart         [no change — SessionStart korunur]

test/core/state/
└── game_state_notifier_telemetry_test.dart  [YENİ]
      ├── buyBuilding success → PurchaseMade emit (mock logger verify)
      ├── buyBuilding insufficient crumbs → no emission [I19]
      ├── buyBuilding unknown id → no emission [I19]
      ├── buyUpgrade success → UpgradePurchased emit
      └── buyUpgrade already owned → no emission [I19]

test/core/tutorial/
└── tutorial_notifier_test.dart          [MODIFIED — +4 test]
      ├── reset() → prefs both removed
      ├── reset() → state=fresh AsyncData defaults
      ├── reset then start → consumeReplayFlag returns true
      └── consumeReplayFlag single-use (second call → false)

test/features/settings/
├── settings_page_test.dart              [YENİ]
│     ├── default (dev flag true) → 2 section render
│     └── overrideWithValue(false) → only Audio section (Developer hidden)
├── developer_settings_section_test.dart [YENİ]
│     ├── Test Crash button isInitialized=false → snackbar shown, no crash
│     ├── Tutorial Replay button → dialog opens
│     └── smoke — widget structure
└── tutorial_replay_dialog_test.dart     [YENİ]
      ├── Confirm button → Navigator.pop(true)
      ├── Cancel button → Navigator.pop(false)
      └── Dialog copy — "İlerlemen kaybolmaz" rendered

integration_test/
└── tutorial_telemetry_integration_test.dart  [MODIFIED]
      ├── TutorialStarted.isReplay=false in fresh install test
      ├── Reset flow — replay emission isReplay=true assertion
      └── Pre-B4 migration cold start — no AppInstall emit [I18]
```

---

## 3. FirstBootNotifier + AppInstall trigger refactor

### 3.1 FirstBootNotifier

```dart
// lib/core/launch/first_boot_notifier.dart
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

### 3.2 AppBootstrap refactor

**B3 current (drop):**
```dart
final isFirstLaunch = !tutorialState.firstLaunchMarked;
```

**B4 target:**
```dart
// step b' (after installIdProvider.ensureLoaded, before gameState hydrate)
final isFirstLaunch = await container
    .read(firstBootProvider.notifier)
    .ensureObserved();

// step f — unchanged usage:
container
    .read(sessionControllerProvider)
    .onLaunch(isFirstLaunch: isFirstLaunch);
```

**Rationale:** Tutorial state (`firstLaunchMarked`) "tutorial gösterildi" sinyali; B4 öncesi AppInstall trigger için ikinci amaç (device first boot) için re-purpose ediliyordu. Semantic drift B4 backlog'da flag'lenmişti. Ayrı pref + Notifier ile disjoint — tutorial replay AppInstall re-emit etmez.

### 3.3 Migration backfill semantics

| State at B4 boot | `first_launch_observed` | `install_id` | `ensureObserved` returns | AppInstall emit? |
|---|---|---|---|---|
| Fresh B4+ install | null | null | **true** | **Yes** |
| Pre-B4 user (B1-B3) | null | set | **false** (backfill) | No |
| B4+ second boot | true | set | false | No |

**Edge:** B2-only user (B3 deploy'u atladı, B4'e direkt upgrade). B3 `install_created_at` yok ama `install_id` B1'den beri var. Migration proxy `install_id` → backfill çalışır.

---

## 4. Telemetry event catalog expansion

### 4.1 PurchaseMade event

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
```

**cost int overflow note:** Dart `int` 64-bit signed, Firebase Analytics int params ≤ 2^63-1. Current economy.md §5: `baseCostFor × growth^owned`.toInt(). Realistic cap: owned ~= 200-500, growth ~= 1.12-1.15 → cost < 10^25. Double precision safe int limit 2^53 ≈ 9×10^15. C sprint prestige çarpan explosion'ında revisit. Şu an int + compile-time safe.

### 4.2 UpgradePurchased event

```dart
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

### 4.3 TutorialStarted shape update

```dart
class TutorialStarted extends TelemetryEvent {
  const TutorialStarted({
    required this.installId,
    required this.isReplay,  // B4 YENİ — required
  });

  final String installId;
  final bool isReplay;

  @override
  String get eventName => 'tutorial_started';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'is_replay': isReplay,  // bool → int FirebaseAnalyticsLogger'da coerce
      };
}
```

**Analytics value:**
- Dashboard `tutorial_started WHERE is_replay=0` → genuine funnel denominator (fresh install retention)
- `is_replay=1` subset → replay usage metric (feature discoverability)
- Denominator integrity korunur — B3 funnel bozulmaz

### 4.4 Firebase compliance

| eventName | Length | Compliant |
|---|---|---|
| purchase_made | 13 | ✓ |
| upgrade_purchased | 17 | ✓ |
| tutorial_started (existing) | 16 | ✓ (no change) |

T4 regex invariant test events list 6'ya çıkar (existing 4 + PurchaseMade + UpgradePurchased). 12 compliance test (6 events × 2 checks).

### 4.5 GameStateNotifier emission

```dart
// lib/core/state/game_state_notifier.dart [MODIFIED]

Future<bool> buyBuilding(String id) async {
  // ... existing validation
  if (!canAfford) return false;

  final updated = g.copyWith(...);
  _persistSafe(updated, 'buyBuilding');

  // B4 YENİ — emission (successful path only; _persistSafe fire-and-forget
  // sonrası sync emit. Crash window risk %0.01 — B5 analysis)
  final ownedAfter = updated.buildings.owned[id] ?? 0;
  ref.read(telemetryLoggerProvider).log(PurchaseMade(
    installId: resolveInstallIdForTelemetry(ref.read(installIdProvider)),
    buildingId: id,
    cost: cost,
    ownedAfter: ownedAfter,
  ));
  return true;
}

Future<bool> buyUpgrade(String id) async {
  // ... existing validation
  if (alreadyOwned) return false;
  if (!canAfford) return false;

  final updated = g.copyWith(...);
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

**Emission invariant [I19]:** Yalnız **successful purchase path** — canAfford=false / alreadyOwned / unknown id path'lerinde emission YOK. Integration test [I19] bu'yu regression'a karşı korur.

### 4.6 TutorialNotifier.reset() + consumeReplayFlag

```dart
class TutorialNotifier extends AsyncNotifier<TutorialState> {
  bool _replayTriggered = false;

  /// Bir sonraki `start()` emit'inde `isReplay` ne olacak — `reset()` sonrası
  /// true döner, ilk okuyucu false'a sıfırlar (single-use). Invariant [I20].
  bool consumeReplayFlag() {
    final value = _replayTriggered;
    _replayTriggered = false;
    return value;
  }

  /// Tutorial state'i tamamen sıfırlar. Concurrent call'lar
  /// `SharedPreferences` internal lock ile serialize edilir — idempotent.
  /// [FirstBootNotifier]'a dokunulmaz (invariant [I18]).
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

**TutorialScaffold emission site update:**

```dart
// lib/features/tutorial/tutorial_scaffold.dart [MODIFIED]
if (postState?.currentStep == TutorialStep.tapCupcake) {
  _startedAt = DateTime.now();
  final isReplay = ref
      .read(tutorialNotifierProvider.notifier)
      .consumeReplayFlag();
  ref.read(telemetryLoggerProvider).log(
    TutorialStarted(
      installId: resolveInstallIdForTelemetry(
        ref.read(installIdProvider),
      ),
      isReplay: isReplay,
    ),
  );
}
```

---

## 5. Settings page + Developer subsection

### 5.1 SettingsPage rewrite

```dart
// lib/features/settings/settings_page.dart [REWRITE]
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

### 5.2 developerVisibilityProvider

```dart
// lib/features/settings/providers.dart [YENİ]
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
final developerVisibilityProvider = Provider<bool>((ref) {
  return kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST');
});
```

### 5.3 AudioSettingsSection (stub)

```dart
// lib/features/settings/widgets/audio_settings_section.dart [YENİ]
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';

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
          onChanged: null, // B5'e kadar disabled — audio layer gelecek
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

**B5 hook:** `onChanged: null` → switch disabled. B5'te `audioSettingsProvider` geldikten sonra `onChanged: (v) => ref.read(audioSettingsProvider.notifier).setMusic(v)`.

### 5.4 DeveloperSettingsSection + TutorialReplayDialog

```dart
// lib/features/settings/widgets/developer_settings_section.dart [YENİ]
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

```dart
// lib/features/settings/widgets/tutorial_replay_dialog.dart [YENİ]
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

### 5.5 l10n strings (tr.arb — 13 yeni key)

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

---

## 6. Invariants & DoD

### 6.1 Yeni invariants [I18]-[I20]

B3'ten [I1]-[I17] korunur + 3 yeni:

- **[I18]** `TutorialNotifier.reset()` AppInstall re-emit ETMEZ — `FirstBootNotifier` ve `TutorialNotifier` prefs disjoint. Reset yalnız tutorial pref'lerini clear eder (`crumbs.first_launch_marked` + `crumbs.tutorial_completed`); `crumbs.first_launch_observed` dokunulmaz
- **[I19]** `PurchaseMade` ve `UpgradePurchased` yalnız **successful purchase path**'ten emit — canAfford=false, alreadyOwned, unknown id path'lerinde emission YOK (integration test regression guard)
- **[I20]** `TutorialStarted.isReplay` monotonik single-use flag ile belirlenir — `consumeReplayFlag()` ilk okuyucuda true döner, sonraki çağrılarda false. `reset()` flag'i true'ya flip'ler; ikinci `start()` false döner (doğal path)

### 6.2 Definition of Done

- [ ] `flutter analyze` clean (0 issue)
- [ ] `flutter test -j 1` 100% pass (hedef: +20 yeni test, ~235-240 toplam)
- [ ] Fork PR CI yeşil (B3 pattern korunur)
- [ ] Invariants [I18]-[I20] regression test'te assert edilir
- [ ] `docs/telemetry.md` 3 event update (PurchaseMade, UpgradePurchased, TutorialStarted.is_replay) + [I18]-[I20] invariants
- [ ] `CLAUDE.md §12` FirstBootNotifier disjoint pattern + migration proxy gotcha
- [ ] Backlog cleanup — B3 §1 remaining items ✅ işaretlendi
- [ ] Manual smoke: Settings → Developer → Tutorial Replay dialog → confirm → tutorial Step 1 yeniden görünür
- [ ] Manual smoke: Settings → Developer section production build'de gizli (`flutter build apk --release` CRASHLYTICS_TEST flag'siz)
- [ ] Manual verify: Pre-B4 user migration — B3 tag checkout → B4 tag boot → no AppInstall in logger

---

## 7. Testing strategy

### 7.1 Unit

**FirstBootNotifier** (4 test):
- Fresh B4 install (no prefs) → state=true + pref write
- Pre-B4 migration (install_id mevcut, first_launch_observed yok) → state=false + backfill write
- Second boot (first_launch_observed=true) → state=false idempotent
- B4 fresh install after first boot → state stable (pref preserved)

**TelemetryEvent** (+5 test via telemetry_event_test.dart modify):
- PurchaseMade eventName + payload (4 field)
- UpgradePurchased eventName + payload (3 field)
- TutorialStarted.isReplay=true payload has is_replay:true
- TutorialStarted.isReplay=false payload has is_replay:false

**FirebaseAnalyticsLogger** (+4 test):
- PurchaseMade log() → logEvent shape
- UpgradePurchased log() → logEvent shape
- TutorialStarted.isReplay=true → coerced to is_replay:1
- Regex events list 6'ya çıkar (12 compliance test, existing 8 + new 4)

**GameStateNotifier telemetry** (new test file — 5 test):
- buyBuilding success → PurchaseMade emit (mock verify)
- buyBuilding insufficient crumbs → no emit [I19]
- buyBuilding unknown id → no emit [I19]
- buyUpgrade success → UpgradePurchased emit
- buyUpgrade already owned → no emit [I19]

**TutorialNotifier.reset()** (+4 test):
- reset → both prefs removed
- reset → state=fresh TutorialState defaults
- reset then start → consumeReplayFlag returns true (isReplay signal)
- consumeReplayFlag single-use (second call false) [I20]

### 7.2 Widget

**SettingsPage** (2 test):
- default dev flag true → 2 section render
- overrideWithValue(false) → only AudioSettingsSection, Developer hidden

**DeveloperSettingsSection** (3 test):
- Test Crash isInitialized=false → snackbar shown (no crash call)
- Tutorial Replay tap → dialog opens
- widget structure smoke

**TutorialReplayDialog** (3 test):
- Confirm → Navigator.pop(true)
- Cancel → Navigator.pop(false)
- Body copy rendered ("kaybolmaz" reassurance)

### 7.3 Integration

`tutorial_telemetry_integration_test.dart` güncelleme — 3 cold start senaryosu:

1. **Fresh B4 install** (no prefs) — AppInstall emit + TutorialStarted(isReplay: false) emit
2. **Pre-B4 migration** (install_id mevcut, first_launch_observed yok) — no AppInstall emit [I18], TutorialStarted behavior unchanged (tutorial state fresh or prior)
3. **Post-reset replay flow** — reset → start → TutorialStarted(isReplay: true) emit

**T13 explicit DoD:** 3 senaryo × AppInstall emission count assertion (0, 0, 0 respectively for re-test scenarios).

### 7.4 Manual QA

- Settings > Developer section görünürlüğü:
  - Debug build → visible
  - Release build (no flag) → hidden
  - Release + `--dart-define=CRASHLYTICS_TEST=true` → visible
- Tutorial replay flow (manual smoke):
  - Fresh install → tutorial tamamla
  - Settings > Developer > Tutorial'i Tekrar Oyna → confirm dialog
  - Tutorial Step 1 yeniden görünür + Firebase dashboard `tutorial_started WHERE is_replay=1`
- Test Crash flow (runbook §5 unchanged from B3):
  - Release build
  - Settings > Developer > Test Crash
  - App hard crash → re-launch → Firebase Crashlytics dashboard entry (~5 dk)

---

## 8. Task decomposition (14 task)

Etiketler: **(S)** subagent-driven TDD strict, **(C)** controller-direct, **★** critical.

| # | Task | Mode | Critical |
|---|---|---|---|
| T1 | `FirstBootNotifier` + tests (fresh + migration + idempotent + stable) | S | ★ |
| T2 | `AppBootstrap` step b' — firstBootProvider.ensureObserved + isFirstLaunch rewire + test | S | ★ |
| T3 | `TelemetryEvent` — PurchaseMade + UpgradePurchased + TutorialStarted.isReplay field + event test updates | S | ★ |
| T4 | `FirebaseAnalyticsLogger` regex invariant events list 6'ya genişler + log() tests 2 yeni event + isReplay coercion (T3 ile aynı commit'te gidebilir — atomic concern separation) | C | |
| T5 | `GameStateNotifier` buyBuilding + buyUpgrade telemetry emission (_persistSafe sonrası sync; crash window %0.01 kabul — B5 analysis) + `game_state_notifier_telemetry_test.dart` | S | ★ |
| T6 | `TutorialNotifier.reset()` + consumeReplayFlag single-use + idempotency test | S | |
| T7 | `TutorialScaffold` isReplay emission wiring (consumeReplayFlag read sonrası TutorialStarted constructor) + test | C | |
| T8 | `lib/features/settings/providers.dart` developerVisibilityProvider | C | |
| T9 | `AudioSettingsSection` stub widget + smoke test | C | |
| T10 | `DeveloperSettingsSection` + `TutorialReplayDialog` + tests (isInitialized snackbar, confirm/cancel, dialog copy) | S | |
| T11 | `SettingsPage` rewrite — ConsumerWidget + developerVisibilityProvider watch + 2-section render | C | |
| T12 | `tr.arb` 13 yeni key + AppStrings codegen | C | |
| T13 | Integration test `tutorial_telemetry_integration_test.dart` — 3 cold start senaryosu × AppInstall assertion (fresh / migration / replay) + isReplay invariant | S | ★ |
| T14 | Docs — `docs/telemetry.md` 3 event update + [I18]-[I20] invariants; `CLAUDE.md §12` FirstBootNotifier pattern; `_dev/tasks/lessons.md` B3 defer item'ları; backlog cleanup (§1/4-5 done) | C | |

**Dağılım:**
- Subagent-driven (7): T1, T2, T3, T5, T6, T10, T13
- Controller-direct (7): T4, T7, T8, T9, T11, T12, T14
- Critical ★ (5): T1, T2, T3, T5, T13 — invariant-breaking path'ler (AppInstall trigger, event shapes, emission gate [I19], migration regression)
- Non-★ subagent (2): T6, T10 — TDD strict ama invariant breakable değil (unit coverage yeterli)

---

## 9. Dependency DAG

```
T3 (event shapes) ──► T4 (regex list) ──► T7 (isReplay emission)
                                           ▲
T1 (FirstBootNotifier) ──► T2 (AppBootstrap wire) ──► T13 (integration)
                                                      ▲
T5 (GameState emit) ──────────────────────────────────┤
                                                      │
T6 (TutorialNotifier.reset) ──► T7                    │
                                                      │
T8 (dev provider) ──► T9, T10, T11 sıralı ──► T13 ──► T14 (docs)
T12 (l10n) ──► T10, T11 (compile dependency)
```

**Kritik sıra:**
- **T1 → T2 atomic**: provider + bootstrap wiring aynı commit'te (tutorialState.firstLaunchMarked usage'ı AppBootstrap'tan kaldırılır)
- **T3 → T4 atomic adı aynı commit mümkün**: shape change + regex list; ama iki ayrı task görünürlük için
- **T6 → T7**: replay flag producer → consumer
- **T5 → T13**: GameState emit coverage integration'a dayanır
- **T12 (l10n) T10+T11 öncesi zorunlu** — widget compile'da string key'ler
- **T14 son**: tüm implementation tamamlandıktan sonra docs

---

## 10. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Pre-B4 migration proxy `install_id` bazlı — edge case false-positive | AppInstall re-emit edilen pre-B4 user | Migration test 2 senaryo (fresh + backfill); manual B3→B4 upgrade doğrulama release notes |
| `FirebaseBootstrap.isInitialized` static — Crashlytics test button widget test coverage zayıf | Accidental shipped crash button | Test: isInitialized=false → snackbar; full path manual QA. B5 followup: provider wrapper |
| Dev section production'a sızması | Real user'a hard crash erişimi | `kDebugMode` compile-time sabit — widget tree'de yok. Override test + release build manual verify |
| Purchase telemetry emit-then-persist crash window | Dashboard ~0.01% double-count | Accepted risk; B5 analysis followup. Fire-and-forget B3 pattern tutarlı |
| `consumeReplayFlag` TutorialScaffold lifecycle race | isReplay=false false-negative | Single-use notifier-internal; TutorialScaffold postFrame initState'te okunur, widget unmount/remount'da flag in-memory kalır (reset restart'ı tetiklerse yeniden set olur) |
| Tutorial reset concurrent tap | State corruption | SharedPreferences internal lock + reset idempotent; doc comment |
| Migration test flake — DateTime.now() comparisons | CI intermittent fail | Fresh install test age assertion `< 5000ms` range (B3 pattern) |
| `cost` int overflow Sprint C prestige era | Analytics NaN/wrong values | C sprint prestige çarpan explosion'ında revisit — spec § 4.1 note |

---

## 11. Rollback plan

B4 PR merge sonrası kritik regresyon (örn. AppInstall flood, UI crash):

1. `git revert <merge-commit>` tek komut
2. `pubspec.yaml` değişikliği yok — dependency drift yok
3. `FirstBootNotifier` + `first_launch_observed` pref silindiğinde B3 davranışına döner (tutorialState.firstLaunchMarked trigger)
4. **Data kaybı riski:** `first_launch_observed` pref disk'te kalabilir — next B4 relaunch'ta existing user'lar için continuity sağlar (fresh migration yapılmaz, doğrudan `observed=true` okur)
5. `PurchaseMade` + `UpgradePurchased` event'leri dashboard'da bir süre görünür ama emitter kodu silindiği için drying up eder
6. Settings page B3'teki placeholder'a döner
7. TutorialNotifier.reset() method silinir — Settings Developer button çağırması compile fail → Developer section rewrite kaldırılır

**Not:** Analytics data B4 window'unda toplanan dashboard'da kalır (Firebase silmez). `is_replay` field null'a düşer (eski AppInstall payload shape) — dashboard schema'da null-tolerant olduğu sürece sorun değil.

---

## 12. Followups (B5 backlog)

- **ResearchComplete event** — Sprint C research impl'yle birlikte (research_completed eventName, node_id + unlock_time payload)
- **Audio settings implementation** — Settings > Ses & Müzik aktif + audio layer engine (music/sfx playback, prefs persistence)
- **`FirebaseBootstrap` state provider wrapper** — static flag → Provider<bool> (widget test ergonomics)
- **Purchase telemetry ordering analysis** — emit-then-persist vs persist-then-emit crash window measurement + decision
- **`AppLaunchCountNotifier`** — int counter + `launch_count` SessionStart payload extension (cohort analytics güçlendirme)
- **Language selector** — TR-only → multi-locale preparation
- **`FirebaseCrashlytics.log(breadcrumb)`** — TelemetryEvent paralel yazım
- **Legal privacy policy draft** + privacy policy link in Settings
- **Settings page category system** — Audio + Developer + Future (Gameplay, Notifications, About) — extensible layout
- **Dev section extension** — telemetry event viewer, live logger tail, analytics dashboard quick link

---

## 13. Referans

- `cookie_clicker_derivative_prd.md §6.10 (Settings), §11 (telemetry)`
- `docs/telemetry.md`
- `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md` (B3 spec — FirebaseBootstrap, InstallIdNotifier, telemetry pipeline foundation)
- `docs/superpowers/backlog/sprint-b3-backlog.md §1/4-5` (tutorial replay + purchase events carry-over)
- `CLAUDE.md §2 (tech stack), §12 (gotcha'lar)`
