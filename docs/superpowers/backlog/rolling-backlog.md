# Rolling Backlog

**Son güncelleme:** 2026-04-19 (Sprint B5 close)
**Kaynak:** B2/B3/B4/B5 review döngüleri + final branch review'ları + ultrareview bulguları
**Durum:** Açık item'lar; tamamlananlar bu dosyadan çıkarıldı. Per-sprint backlog dosyaları bu dosyaya konsolide edildi.

---

## 0. Merge öncesi eylem (B5 PR #7)

- [ ] **Manuel QA** — `docs/audio-plan.md §Manual QA Checklist` 9 item:
  - iOS simulator silent switch ON/OFF, Spotify mix (Ambient category)
  - Android emulator ring silent/normal
  - Rapid tap [I22] 80ms gate
  - App pause → ambient susar → resume → geri gelir
  - Engine init fail scenario (dev override)
  - `xcrun simctl log stream` audio error yok

**Zorunlu** — 297 automated test yeşil ama audio integration device-only doğrulama gerektirir.

---

## 1. Sprint C+ kapsamına ertelenmişler

### Content + feature
- **ResearchComplete telemetry event** — research impl'yle birlikte (Sprint C R2 Research tree).
- **Dönem-spesifik ambient müzik** — industrial + galactic loops (Sprint D prestige polish). B5'te tek artisan loop.
- **Cue-per-step tutorial SFX** — post-MVP backlog. B5'te tek `stepComplete` cue.
- **Cue-level volume map** (tap subtle / purchase celebratory) — post-asset mixing pass. B5'te flat `masterVolume`.
- **Error cue** — industry pattern dropped (B5), post-MVP re-evaluation.
- **Dönem-spesifik müzik ile prestige geçiş cutscene** — "Kneading Portal" konsepti (Yön B art direction). `docs/visual-design.md §14` Post-MVP Visual Backlog.

### Infrastructure
- **Platform parity CI automation** (patrol package) — manuel QA yerine automated iOS+Android audio test. B5 manuel DoD'u değiştirir.
- **`AudioPreferenceChanged` telemetry event** — music/sfx toggle rate post-launch ölçümü. `docs/audio-plan.md §Post-MVP Roadmap`.
- **Dual-format asset** (iOS .m4a + Android .ogg) — B6 polish. Mevcut `.ogg` cross-platform uyumlu ama iOS native decode optimizasyonu.

### Asset pipeline
- **Quality asset curation** — `_dev/tasks/post-b5-audio-asset-curation.md` detay. Epidemic trial veya CC0 kalite asset, post-launch 2 hafta.

---

## 2. B5 post-merge polish (final reviewer)

### Minor — post-merge
- [ ] **Bootstrap race guard** — `lib/main.dart`'ta `await audioSettingsProvider.future` ekle, `audioControllerProvider` read'i öncesi. Mevcut `<100ms` race penceresinde kullanıcı persisted `sfxEnabled: false` varken default `true` SFX çalabilir.
- [ ] **Audio asset Git LFS migration** — mevcut ~135KB inline OK; industrial+galactic ambient (~900KB each) eklenirse 3MB threshold aşılır. `git lfs track "*.ogg"` migration. `_dev/tasks/post-b5-audio-asset-curation.md` Sprint D ile senkron.

---

## 3. Docs drift + plan freshness

### B3/B4/B5 sprint docs güncellemeler
- [ ] **B3 Spec/plan drift** — `resolveInstallIdForTelemetry(ref)` / `(container)` eski imza referansları spec + plan'da; gerçek `String? rawValue` (commit `ff83610`). Tüm referansları `resolveInstallIdForTelemetry(ref.read(installIdProvider))` paternine güncelle.
- [ ] **B5 plan drift** — T8 plan snippet'inde `setMusicEnabled(v)` positional; gerçek `setMusicEnabled(enabled: v)` named (T4 lint uyumu). T12 plan snippet de aynı. Plan doc update veya `_dev/tasks/lessons.md` entry.
- [ ] **B5 plan drift** — T6 plan `const AudioContext(...)` var; gerçek non-const (audioplayers 6.6.0 nested constructor'lar). Plan snippet update.
- [ ] **B5 plan drift** — T8 `overrideWithValue` (Riverpod 3'te builder skip'ler, `ref.onDispose` register olmaz). Gerçek testler `overrideWith((ref) { ref.onDispose(...); return fake; })`. Plan snippet güncelle.

### `ux-flows.md §6` cross-ref fix
- [ ] **Session Recap §6 kaybı** (B2 T17 regression) — `docs/ux-flows.md:82, 509, 528` hâlâ `§6`'ya işaret ediyor ama Tutorial'la replace edilmiş. Opsiyonlar:
  1. `git show main:docs/ux-flows.md`'den Session Recap §6 restore + Tutorial `§8` olarak renumber
  2. 3 cross-ref'i yeni konuma güncelle

---

## 4. Test harness improvements

### Flake + brittleness
- [ ] **Audio overrides shared test helper** — `test/_helpers/audio_overrides.dart` oluştur: `audioFakeOverrides()` helper. Şu an 3 duplicate (`audio_providers_test.dart`, `audio_controller_test.dart`, `app_lifecycle_gate_test.dart`). Yeni widget test'ler AudioPlayersEngine MissingPluginException'a düşebilir.
- [ ] **`app_lifecycle_gate_test.dart:62` parallel flake** (B2 T15) — `Future.delayed(50ms)` yetersiz. Fix: `until saveFile.existsSync()` poll veya deterministic waiter. CI `-j 1` geçici çözüm.
- [ ] **TutorialScaffold I-1 test harness** (B2 T13) — "loading guard test" `kTutorialCupcakeKey` tree'de olmadığı için yanlış sebeple geçiyor. `tutorialNotifierProvider`'ı never-resolving future'a override et + `step == null` assert et.
- [ ] **TutorialScaffold advance trigger unit tests** (B2 T13) — Step 1/2 advance path'leri unit-level test edilmiyor, sadece T17 integration test kapsar.
- [ ] **I12 negative contract test** (B2 T14) — `TutorialScaffold` `MaterialApp.router(builder:)` dışında mount → `GoRouterState.of` hatası test edilmiyor.
- [ ] **T4 onResume-double-open defensive test** (B2 T4) — `onResume` aktif session üzerine geldiğinde SessionEnd emit assertion; şu an sadece `secondSessionId != firstSessionId` kontrol ediliyor.

### Test content drift
- [ ] **T7 plan test count drift** (B2) — "13 test" yazıyor, gerçekte 14. Plan doc fix.

---

## 5. Code quality / lint polish

### Class modifiers (Dart 3)
- [ ] **TelemetryEvent 5 subclass** `final class` — "5-event universe" invariant (B2 T1). External subclass engelle.
- [ ] **BootstrapResult** `final class` — subclass engelle (B2 T15).
- [ ] **Pure-static namespace consistency** — `SfxCatalog` `abstract final class`, `Routes` `abstract class`. Birleştir (tercih: `abstract final class`) veya CLAUDE.md §5 standart not.

### Naming + magic numbers
- [ ] **MessageCallout `120`** magic number → `_kMessageCalloutEstimatedHeight = 120.0` (B2 T9).
- [ ] **T13 Step 2 openShop route check** — `matchedLocation == '/shop'` raw compare; nested paths (`/shop/details`) miss eder. `location.startsWith('/shop')` veya route-name constant.
- [ ] **`FakeAudioEngine` @visibleForTesting** — `lib/core/audio/audio_engine.dart`'ta ship ediyor. `@visibleForTesting` annotation + lint.

### API docs + invariants
- [ ] **AudioSettingsNotifier class doc** — "Setters must not be invoked before `build()` resolves (observed via `AsyncValue.data`)" contract note.
- [ ] **`tapCrumb()` domain contract vs side-channel docstring** — şu an bool return presentational signal gibi okunuyor. Sharpen: "state mutation unconditional; bool return is UI feedback side-channel".
- [ ] **`stopAmbient`/`pauseAmbient` musicEnabled gate asymmetry** — `resumeAmbient` guards; pause/stop unconditional. One-line inline comment: "pause/stop always safe no-op when loop absent".

### Pre-existing
- [ ] **bug_017 InstallIdNotifier "Disk-wins" → "GameState-wins"** (ultrareview nit) — 4 location docstring rename. Functional impact yok; cognitive nit.

---

## 6. CI gates + infrastructure

- [ ] **Coverage gate** — yeni modüller ≥85% (core/economy ≥95%). B3 backlog'dan, hâlâ CI'ya bağlanmadı. `.github/workflows/ci.yml`'ye lcov assertion ekle.
- [ ] **"No dirty tree after pub get"** — `lib/l10n/app_strings*.dart` generated ama tracked (B2 T17-fix). CI gate veya `.gitignore` + pre-test hook.
- [ ] **Platform parity CI** (patrol) — `§1 Sprint C+` altında; CI automation aspect.
- [ ] **Manual a11y audit 8-widget spot check** — B2 DoD item (`docs/superpowers/specs/... §7.2`), PR description'a eklenmemişti. Sprint D accessibility sweep'e yansıtır.
- [ ] **Screen reader a11y audit** — Sprint D.

---

## 7. `_dev/tasks/lessons.md` eklentileri

B5 polish commit `0614963` ile 7 yeni ders eklendi (asset wildcard CRITICAL + 6 diğer). Sprint A-B4 dersler mevcut. Pending:

- [ ] **flutter_animate repeat() test env timer leak** (B2 T9) — `AnimationController + SingleTickerProviderStateMixin` kullan. PulseHalo bu pattern'de. (B5 `.shake()` Timer leak dersi eklendi; repeat() variant ayrı note değeri olabilir.)
- [ ] **ProviderContainer + path_provider** (B2 T15) — test'te real path_provider fail; `saveRepositoryProvider` override + temp-dir pattern zorunlu. (Implicit in B5 lessons "GameStateNotifier hydrate pre-boot" ama explicit yazılabilir.)

---

## Önceliklendirme

**Kritik (merge öncesi, §0):** Manuel QA checklist.

**Yüksek (post-merge, B5 close veya erken Sprint C):**
- building_row widget test + upgrade_row ekle
- [I23] integration test tightening
- `_dev/tasks/lessons.md` B5 eklentileri
- Flutter asset bundling lesson yüksek öncelik (critical recurrence riski)

**Orta (Sprint C-D):**
- B3 spec/plan docs drift
- B5 plan drift (T6/T8/T12 snippet updates)
- Test harness shared helpers (audio overrides)
- Session Recap §6 cross-ref restore
- Bootstrap race guard
- Class modifier upgrades

**Düşük (post-MVP, opsiyonel):**
- Magic number cleanups
- bug_017 docstring nit
- CI gate strengthening
- API docs sharpening
- Platform parity automation

---

## Eski sprint backlog dosyaları (arşiv)

Bu dosya `sprint-b3-backlog.md` içeriğini konsolide eder:
- ✅ B2 ultrareview 5 bug → B2 PR öncesi fix edildi (historical: `757804c` bug_002, `bf6544a` bug_003, `cfa6c3b` bug_017, `7e8c372` bug_011, `dd1e0c5` bug_009)
- ✅ B3 spec §1/1-3 → Sprint B3 T3/T4/T5/T6/T7/T8/T10 landed
- ✅ B4 — Tutorial replay toggle (T6+T10), Purchase/Upgrade events (T3+T5), FirstBootNotifier (T14), Developer section real impl
- ✅ B5 — Audio layer full 14 task + T9-fix + T14-fix

Eski sprint-b3-backlog.md bu dosyayla değiştirilir; arşiv git history'de kalır.
