# Sprint B3 — Backlog

**Tarih:** 2026-04-18
**Kaynak:** Sprint B2 review döngüsü (per-task spec/quality reviewer + final branch review + ultrareview)
**Durum:** Backlog — B3 spec brainstorming'inde önceliklendirilecek

---

## 1. B2 Spec'ten planlanmış B3 işleri (spec §13)

- [ ] **Firebase Analytics provider wiring** — `TelemetryLogger` interface korunur; `FirebaseAnalyticsLogger implements TelemetryLogger` yazılır ve `telemetryLoggerProvider` override edilir (tek dosya swap). Ön-koşul: `flutterfire configure` runbook
- [ ] **Crashlytics integration** — `FlutterError.onError` + `PlatformDispatcher.instance.onError` → `FirebaseCrashlytics.recordFlutterError` / `recordError`
- [ ] **`install_id_age_ms` payload property** — install creation timestamp SharedPreferences'a yazılır (`crumbs.install_created_at`); `AppInstall.installIdAgeMs` = now - createdAt
- [ ] **Settings → "Tutorial'i tekrar oyna" toggle** — `TutorialNotifier.reset()` eklenir (tutorialCompleted=false + currentStep=null + prefs clear); Settings ekranında switch
- [ ] **Purchase / Upgrade / ResearchComplete event'leri** — telemetry event kataloğu genişlemesi (payload: id, cost, timestamp)
- [ ] **GameState hydration side-effect telemetry** — offline_progress + save_recovery event'leri. B2'de `gameStateNotifierProvider.build()` telemetry emit ETMEZ; B3'te provider listen pattern eklenir (SessionStart → hydration events ordering deterministik)
- [ ] **Step 2 granularity split** — `openShop` → `openShop` + `buyFirstBuilding` ayrımı (tutorial funnel drop-off analytics için gerekirse)

## 2. Sprint B2 per-task review bulguları

### T1 — TelemetryEvent
- [ ] `final class` modifier on 5 subclasses — "5-event universe" invariant'ı sıkılaştır (bkz T1 review Minor #1). Yeni `TelemetryEvent` subclass external add'lenmesin

### T3 — InstallIdNotifier
- [ ] Spec §3.3 + plan Task 3 Step 3 hâlâ eski `Ref ref` imzasını gösteriyor — actual impl `String? rawValue` kabul ediyor (commit `ff83610`). Docs drift düzelt: spec/plan'da tüm `resolveInstallIdForTelemetry(ref)` / `(container)` çağrılarını `resolveInstallIdForTelemetry(ref.read(installIdProvider))` paternine güncelle
- [ ] `ensureLoaded` invariant note: "caller guarantees serial invocation during boot" — class doc'a ekle

### T4 — SessionController
- [ ] **onResume-double-open defensive contract (spec §6.4 item 4):** onResume aktif session üzerine gelirse mevcut unclosed session için SessionEnd emit edilmeli. Şu an `_startNewSession` doğrudan üzerine yazıyor → prior session kayıp. Ya impl'i spec'e uydur ya spec'i impl'e uydur
- [ ] Parallel test flake'i için integration test: onPause sıra assertion'ı (persistTs < sessionEndTs)

### T7 — TutorialNotifier
- [ ] Plan'da "13 test" yazıyor ama gerçekte 14 test var — plan doc drift fix

### T9 — CoachMarkOverlay
- [ ] `flutter_animate` dependency retention kararı: PulseHalo `AnimationController` kullanıyor (test timer leak sebebiyle). Başka consumer yoksa `pubspec.yaml`'dan kaldır, veya retention gerekçesi `_dev/tasks/lessons.md`'ye yaz
- [ ] `_dev/tasks/lessons.md` entry: "flutter_animate repeat() Flutter test env'da Future.delayed timer leak ediyor → AnimationController + SingleTickerProviderStateMixin kullan"
- [ ] Plan Step 1 `find.byType(ModalBarrier), findsNothing` yanlış — MaterialApp Navigator baseline 1 ModalBarrier. Plan'ı `baselineCount + 1` idiomuna güncelle
- [ ] Test 4 null-target coverage restore: `CoachMarkOverlay(targetKey: null, ...)` path test edilmiyor; ya 6. test ekle ya `targetKey`'i non-nullable yap
- [ ] `MessageCallout` `120` magic number → `const _kMessageCalloutEstimatedHeight = 120.0`

### T13 — TutorialScaffold
- [ ] **I-1 test harness weakness:** "loading guard test" `kTutorialCupcakeKey` tree'de olmadığı için `CoachMarkOverlay` SizedBox.shrink döner — test yanlış sebeple geçiyor. Proper override ile `tutorialNotifierProvider`'ı never-resolving future'a bağla ve `step == null` assert et
- [ ] **I-2 post-remount durationMs=0:** Tutorial mid-flow widget remount olursa `_startedAt=null` → `TutorialCompleted.durationMs=0`. Ya `TutorialState`'e `startedAt` ekle (I2 invariant'ı genişlet) ya `-1` sentinel kullan. `docs/telemetry.md` tutorial_completed notunda already documented
- [ ] Advance trigger unit tests eksik: Step 1 tap → Step 2 + Step 2 purchase → Step 3 `ref.listen` path'leri `tutorial_scaffold_test.dart`'ta direkt test edilmiyor; T17 integration test kapsar ama unit-level gap var
- [ ] `_buildStep2Overlay` `matchedLocation == '/shop'` raw string compare — nested path (`/shop/details`) miss eder. `location.startsWith('/shop')` veya route-name constant öneri

### T14 — GlobalKey injection
- [ ] **I12 negative test:** `TutorialScaffold`'u `MaterialApp.router(builder:)` dışında mount edip `GoRouterState.of` hatasını yakalayan contract test yok

### T15 — AppBootstrap + AppLifecycleGate
- [ ] **Pre-existing flake** `test/app/lifecycle/app_lifecycle_gate_test.dart:62` parallel-mode (~15-50%). `Future.delayed(50ms)` yetersiz. Fix: `until saveFile.existsSync()` poll (deterministic) veya CI'da `-j 1` zorunlu
- [ ] `app_lifecycle_gate_session_test.dart` aslında `SessionController` unit test — `AppLifecycleGate` mount etmiyor. Ya test'i widget seviyesine çıkar (handleAppLifecycleStateChanged + spying SaveRepository) ya dosyayı `test/core/telemetry/session_controller_pause_integration_test.dart`'a taşı
- [ ] `containerFactory` test hook'una `@visibleForTesting` anotasyonu ekle (production abuse önler)
- [ ] `_dev/tasks/lessons.md` entry: "ProviderContainer in `flutter test` cannot use real `path_provider` — test-side `saveRepositoryProvider` override + temp-dir pattern gerekli"
- [ ] `BootstrapResult` → `final class` (Dart 3 modifier) subclassing'i engelle

### T16 — A11y
- [ ] Manual a11y audit PR description'a eklenmesi gerekirdi (8 widget spot check) — B2 DoD item'ı (`docs/superpowers/specs/... §7.2`)
- [ ] A11y screen reader contract audit (semantic labels) — Sprint D

### T17 — Integration test + docs
- [ ] `integration_test/tutorial_telemetry_integration_test.dart` Firebase Analytics plugin build error ile device runner'da fail ediyor (flutterfire configure gerekli). B3 Firebase wiring'de çözülecek
- [ ] `ios/Runner.xcodeproj/project.pbxproj` + `contents.xcworkspacedata` stray Xcode churn — `.gitignore` review veya temiz commit

## 3. Sprint B2 final review bulguları (branch seviyesi)

### Dil / i18n
- [ ] `MessageCallout` `tutorialSkipButton` fallback `'Geç'` var (B2 T17-fix) — B3'te i18n ingilizce destek eklenince fallback strategy gözden geçir

### Generated outputs
- [ ] `lib/l10n/app_strings*.dart` artık tracked (T17-fix). CI'da "no dirty tree after pub get" gate kontrolü düşünülmeli. Alternatif: `.gitignore`'a al + pre-test hook (`flutter pub get`)

## 4. B2 DoD'dan eksik kalanlar (spec §7.2)

- [ ] Coverage gate: yeni modüller ≥85% — ölçülmedi. B3'te `flutter test --coverage` + genhtml kontrol
- [ ] Manuel a11y audit 8 widget spot check PR description — eksik (yukarıda T16 altında)

## 5. Ultrareview bulguları (2026-04-18)

> **Not:** 5 bug da B2 PR öncesi FIX edildi (commit'ler: `757804c` bug_002, `bf6544a` bug_003, `cfa6c3b` bug_017, `7e8c372` bug_011, `dd1e0c5` bug_009). Bu bölüm historical reference olarak kalır; B3 scope dışı.

### 🔴 bug_009 — `kTutorialShopNavKey` duplicate GlobalKey → navigation crash (normal, PR-blocker)

**Dosya:** `lib/app/nav/app_navigation_bar.dart:86-88`

**Sorun:** `AppNavigationBar` hoisted değil — her sayfanın `Scaffold.bottomNavigationBar`'ında ayrı instance olarak mount ediliyor (home/shop/upgrades/settings = 4 call site). go_router `MaterialPageRoute` default transition'ında outgoing + incoming page aynı anda element tree'de → 2 `AppNavigationBar` → 2 `Icon(Icons.store, key: kTutorialShopNavKey)` → Flutter `BuildOwner._debugVerifyGlobalKeyReservation` assertion: "Multiple widgets used the same GlobalKey". **Her nav tap'te fire eder, tutorial state'ten bağımsız.**

**Neden CI yakalamadı:** Tutorial testleri stub router kullanıyor (AppNavigationBar mount etmiyor); integration test sadece ProviderContainer lifecycle — MaterialApp.router hiç mount edilmiyor.

**Plan doc'ta bile not düşülmüş:** `docs/superpowers/plans/... line ~2372` "AppNavigationBar MaterialApp içinde bir kez mount → OK" — hoisted Shell pattern varsayımı, implementation deviated.

**Fix opsiyonları:**
1. **`StatefulShellRoute.indexedStack`** — tek `AppNavigationBar` instance `Navigator` üstünde, GlobalKey bir kez register olur (plan intent)
2. Top-level GlobalKey pattern'i bırak — route-scoped key lookup (InheritedWidget registry veya `BottomNavCallout` aktif sayfa context'inden resolve eder)

**Öncelik:** 🔴 **KRİTİK** — B2 PR merge öncesi hotfix veya erken B3 task (kullanıcı cihazında gerçek crash üretir).

### 🔴 bug_003 — onResume orphans previous SessionStart (normal, spec §6.4 invariant 4 ihlali)

**Dosya:** `lib/core/telemetry/session_controller.dart:41-45`

**Sorun:** `onResume()` koşulsuz `_startNewSession` çağırıyor — mevcut `_currentSessionId` için SessionEnd emit EDİLMİYOR. `onPause` simetrik değil (null-guard var). iOS Control Center swipe, notification shade peek, app-switcher peek: `resumed → inactive → resumed` (pause hiç tetiklenmiyor) → her peek'te orphan SessionStart. `count(SessionStart) == count(SessionEnd)` invariant'ı kırılır.

**Spec §6.4:** "onResume iki kez çağrılırsa ikinci çağrı yeni session_id başlatır, **mevcut unclosed session'ı kapatır** (defansif kontrat)".

**Test gap:** `test/core/telemetry/session_controller_test.dart:108-126` sadece `secondSessionId != firstSessionId` ve `beginCount == 2` assert ediyor; `endCount` veya orphan SessionEnd kontrolü yok.

**Fix:** `onResume` başında `_currentSessionId != null` guard'ı + SessionEnd emission + endSession() — tıpkı onPause gibi. Test'e `endCount == 2` assertion ekle.

**Öncelik:** 🔴 **KRİTİK** — production'da telemetry veri bütünlüğünü bozar, dashboard duration_ms aggregation'ı güvenilmez olur. (Zaten per-task review'da T4 altında flag'lenmişti, şimdi ultrareview konfirme ediyor.)

### 🔴 bug_002 — CoachMarkOverlay clamp crash when target exceeds safe area (normal)

**Dosya:** `lib/features/tutorial/widgets/coach_mark_overlay.dart:74-80`

**Sorun:** `topLeft.dx.clamp(safeRect.left, safeRect.right - size.width)` — `num.clamp` precondition `lower <= upper`. Target safe area'dan genişse (`size.width > safeRect.width`) `upper < lower` → AssertionError / RangeError crash mid-tutorial.

**Repro:** Step 2 `/shop` route, landscape notched iPhone (media.padding.horizontal ≈ 88px), `kTutorialShopFirstRowKey` full-width `BuildingRow` (`constraints.maxWidth`). `safeRect.right - size.width < safeRect.left` → crash.

**Fix:**
```dart
final maxLeft = math.max(safeRect.left, safeRect.right - size.width);
final maxTop  = math.max(safeRect.top,  safeRect.bottom - size.height);
final clampedLeft = topLeft.dx.clamp(safeRect.left, maxLeft);
final clampedTop  = topLeft.dy.clamp(safeRect.top,  maxTop);
```
Ya da target safe area'dan genişse `SizedBox.shrink()` fallback. Regression test: non-zero `MediaQuery.padding` + target > safe area.

**Öncelik:** 🔴 **YÜKSEK** — landscape notched device'ta tutorial tamamlanamaz. Portrait fresh install'da düşük ihtimal ama crash garantili.

### 🟡 bug_011 — docs/ux-flows.md §6 Session Recap silindi, Tutorial ile replace edildi (normal, docs regression)

**Dosya:** `docs/ux-flows.md:546-573`

**Sorun:** T17 benim docs update'imde `§6 Session Recap Modal` 49 satırlık bölümü wholesale REPLACE edildi `§6 Tutorial (FR-3)` ile. 3 cross-reference (line 82, 509, 528) hâlâ `§6`'ya işaret ediyor ama Session Recap yerine Tutorial content'e dead-link.

**Kaybolan içerik:**
- §6.1 Trigger (lastActiveAt > 60s, Home-post-load timing, one-shot invariant)
- §6.2 8-step flow + telemetry (session_recap_shown/_action_taken/_dismissed), 3-CTA kontratı, ≤1.5s animation budget
- §6.3 A11y (focus-management, reduced-motion, ≥44×44 tap)

**Session Recap PRD §6.9 "Kritik MVP"** — kaybolan spec `git log -- docs/ux-flows.md` ile recover edilebilir ama kimse B2'de merge ettiğinde fark etmeyebilir.

**Fix opsiyonları:**
1. **(Tercih)** `git show main:docs/ux-flows.md`'den Session Recap §6'yı restore et, Tutorial'ı `§8` olarak (var olan §7 Rewarded Ad sonrasına) yeniden numara ver. 3 cross-reference'ı dokunulmadan korur
2. `§6` Tutorial kalır, 3 cross-ref'i Session Recap'in yeni yerine update et (ama önce Session Recap'i file'a geri getir)

**Öncelik:** 🟡 **ORTA** — B3 Session Recap implementation spec'siz kalır ama immediate bug değil. PR merge öncesi düzeltilmesi önerilir (benim T17 docs update'imin regression'ı).

### ⚪ bug_017 — InstallIdNotifier docstring mislabel "Disk-wins" → "GameState-wins" (nit, pre_existing)

**Dosyalar:** `lib/core/telemetry/install_id_notifier.dart:5,24`, `CLAUDE.md §12`, `lib/app/boot/app_bootstrap.dart §6.1.d`

**Sorun:** Docstring "Disk-wins" diyor ama kod `existing != savedInstallId` olduğunda disk'i savedInstallId ile overwrite ediyor — bu **GameState-wins / save-wins** semantiği. Line 24 self-contradictory: "Disk-wins: GameState.meta.installId her zaman authoritative".

**Functional impact:** YOK — davranış tutarlı ve intended. Sadece cognitive yük: cross-device install_id debug'da future contributor yanlış mental model kurabilir.

**Fix:** 4 lokasyonda "disk-wins" → "GameState-wins" veya "save-wins" rename. Veya line 24 docstring'i clarify et.

**Öncelik:** ⚪ **DÜŞÜK** — nit severity, next docs revision'da fix.

### Ultrareview özeti

| Severity | Bug | Impact | PR-blocker? |
|---|---|---|---|
| 🔴 Normal | bug_009 | Navigation crash every tap | **EVET** (hotfix önerisi) |
| 🔴 Normal | bug_003 | Telemetry data integrity | Hayır ama kritik B3 |
| 🔴 Normal | bug_002 | Tutorial crash on landscape+notch | Hayır ama yüksek öncelik |
| 🟡 Normal | bug_011 | Spec docs regression | Hayır ama PR öncesi fix iyi |
| ⚪ Nit | bug_017 | Cognitive nit | Hayır |

---

## Önceliklendirme rehberi (B3 brainstorming için)

**✅ Ultrareview bulguları B2 PR öncesi hepsi fix edildi** (§5 bkz).

**Kritik (B3 içinde):**
- Firebase Analytics wiring (§1)
- Spec/plan docs drift (§2 T3 — eski imza)
- I12 negative contract test (§2 T14)

**Yüksek (Sprint B3-C):**
- Settings tutorial replay toggle
- Purchase/Upgrade telemetry events
- GameState hydration telemetry ordering

**Orta (Sprint C-D):**
- Lesson entries (flutter_animate, path_provider)
- Test harness weakness fixes (T13, T15)
- Screen reader a11y audit

**Düşük (post-MVP):**
- `final class` modifiers
- magic number cleanups
- CI gate strengthening (coverage, dirty tree)
