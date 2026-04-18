# CLAUDE.md — Project Crumbs

Bu dosya Claude Code için operasyonel rehberdir. Ayrıntılı ürün kapsamı için `cookie_clicker_derivative_prd.md` tek gerçek kaynaktır (single source of truth). Bu dosya ile PRD çelişirse PRD kazanır; çelişkiyi fark ettiğinde bu dosyayı güncelle.

## 1. Proje amacı
**Project Crumbs** — mobil öncelikli (iOS + Android), offline-first, tek oyunculu incremental oyun. Cookie Clicker'dan ilham alır fakat klonu değildir.

Ürün vaadi: **"30 saniyede öğren, 30 gün boyunca geri dön."**

MVP çekirdeği: tap loop → 8 bina → 30-40 upgrade → 12 research node → 3 random event → prestige → session recap. Detay için PRD §13.

## 2. Teknoloji stack
**Flutter** (Dart) — iOS + Android tek codebase (2026-04-16 karar).

Gerekçe: Idle oyun için yeterli performans, düşük öğrenme eğrisi, native bridge karmaşıklığı yok. Unity overkill, React Native'in game tick performans riski var.

Sabitlenen alt bileşenler (scaffold PR sonrası `pubspec.yaml` tek gerçek kaynaktır):
- **State management:** Riverpod 3.1 (+ `riverpod_annotation` 4.0, `riverpod_generator` 4.0, `riverpod_lint` 3.1).
- **Save persist:** `path_provider` + JSON dosyası; `crypto` paketiyle SaveEnvelope SHA-256 checksum.
- **Routing:** `go_router` 17.2.
- **Immutable state:** `freezed` + `json_serializable` (build_runner ile üretilir).
- **Test:** `flutter_test` (unit + widget) + `integration_test` + `mocktail`.
- **Analytics / Ads / IAP:** `firebase_analytics`, `google_mobile_ads`, `in_app_purchase` — paket eklendi; `flutterfire configure` ayrı runbook.
- **Lint:** `very_good_analysis` 7.0 + `custom_lint` plugin.

Stack değişimi PRD §16.8 kapsamında **riskli değişiklik** — tek task'ta yapılmaz.

## 3. Komutlar
Flutter stack'i için standart komutlar. Scaffold PR'ında `pubspec.yaml` ve `analysis_options.yaml` eklendikten sonra tümü çalışır hale gelir.

```bash
# FVM (Flutter Version Manager) — pinned 3.41.5 .fvm/fvm_config.json
# Local Flutter pin'den farklıysa build_runner uyumsuzluk verir.
fvm install 3.41.5
fvm use 3.41.5

# Kurulum
flutter pub get

# Geliştirme (bağlı cihaz / simülatör)
flutter run

# Unit + widget testleri
flutter test

# Belirli modül
flutter test test/core/economy/

# Coverage (genhtml: macOS → brew install lcov)
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration testler (cihaz gerekli)
flutter test integration_test/

# Golden snapshot güncelleme
flutter test --update-goldens

# Kod üretimi — freezed, json_serializable, riverpod_generator
# ÖNEMLİ: analyze/test'ten ÖNCE çalışır; part 'X.g.dart' direktifleri
# bu adım çalışmadan resolve olmaz.
dart run build_runner build --delete-conflicting-outputs

# L10n codegen (flutter pub get otomatik tetikler; manuel gerektiğinde):
# flutter gen-l10n
# Kullanım: AppStrings.of(context).tapHint
# Import:   package:crumbs/l10n/app_strings.dart

# Statik analiz (lint + typecheck — Dart tek geçişte yapar)
flutter analyze

# Production build
flutter build ios --release
flutter build apk --release
```

> **CI:** GitHub Actions — şablonlar `.github/workflows/{ci,nightly,release}.yml`; spec `docs/ci-plan.md`. `docs/test-plan.md §10.1` coverage gate ile senkron.

## 4. Repo sözleşmesi

**PRD §16.1 zorunlu dosyalar** (hepsi mevcut):
- `CLAUDE.md` ✓
- `README.md` ✓
- `docs/prd.md` ✓ (root `cookie_clicker_derivative_prd.md`'ye stub referans)
- `docs/economy.md` ✓
- `docs/ux-flows.md` ✓
- `docs/test-plan.md` ✓
- `docs/telemetry.md` ✓
- `docs/save-format.md` ✓

**Ek operasyonel dokümanlar** (scaffold PR girdileri — scaffold tamamlandı):
- `docs/research-tree.md` ✓ — 12 MVP research node'u tam katalog
- `docs/upgrade-catalog.md` ✓ — 36 MVP upgrade listesi (6 etki tipi)
- `docs/scaffold-plan.md` ✓ — Flutter scaffold blueprint (pubspec, lib/ iskelet, stub içerikleri)
- `docs/ci-plan.md` ✓ — GitHub Actions workflow şablonları
- `docs/visual-design.md` ✓ — görsel kimlik brief'i (hex YOK, tasarımcı kesinleştirir)

**Sprint dokümanları** (brainstorming + writing-plans workflow):
- `docs/superpowers/specs/` — brainstorming çıktısı design doc'ları (YYYY-MM-DD-<feature>-design.md)
- `docs/superpowers/plans/` — implementation plan'ları (subagent-driven akış için)

Yeni zorunlu doc eklenirse bu liste ve PRD §16.1 birlikte güncellenir.

## 5. Dizin yapısı
PRD §16.5 "önerilen yapı"yı Flutter convention'ıyla eşleştiriyoruz: PRD'nin abstract `src/` kökü Flutter'da **`lib/`**'tir. `flutter run` otomatik `lib/main.dart` bekler; ayrı bir `src/` kullanmak her import'u `package:crumbs/src/...` yapar — temizlik kaybı. `lib/src/` pattern'i paket yayınlayıcılar (public API izolasyonu) içindir; tek başına uygulama için anlamsız.

```text
lib/
  main.dart         # Flutter entry point
  core/
    economy/        # tüm formül ve hesaplamalar
    progression/    # unlock ve prerequisite mantığı
    save/           # serialize / deserialize / migration + checksum
    events/         # event spawn, timer, buff hesabı
    state/          # GameStateNotifier + derived providers (cross-feature)
    preferences/    # SharedPreferences-backed Notifier'lar (onboarding vb.)
    feedback/       # UI sinyal modelleri (OfflineReport, SaveRecoveryReason)
  features/
    home/
    shop/
    upgrades/
    research/
    prestige/
    achievements/
  ui/
    components/
    theme/
    format/         # TR locale fmt() + short scale
  app/
    routing/
    boot/
    error/          # B1 T18 ErrorScreen — global error boundary
    lifecycle/      # AppLifecycleGate (pause/resume/autosave)
    nav/            # Sprint A T17 AppNavigationBar
  l10n/             # tr.arb + gen-l10n çıktısı (AppStrings)
test/               # flutter_test, mirror of lib/ structure
integration_test/   # end-to-end flows
```

**Not:** PRD §16.5'teki `src/` referansları kodda `lib/` olarak okunur. İleride bu mapping değiştirilirse PRD §16.8 "dizin yapısı / modül sınırlarının değişmesi" kapsamındadır — plan mode zorunlu.

## 6. Mimari kuralları
Aşağıdaki kurallara **istisnasız** uyulur. İhlal gerekiyorsa önce plan yap.

1. **Ekonomi hesapları UI dosyalarında bulunmaz.** Tüm formüller `lib/core/economy/` altında yaşar.
2. **Progression / unlock mantığı tek modüldedir** (`lib/core/progression/`). Feature dosyaları unlock durumunu okur, yazmaz.
3. **Save serialize/deserialize tek yerdedir** (`lib/core/save/`). Başka yerde JSON.stringify(gameState) yazılmaz.
4. **Temporary buff hesapları event modülünde** (`lib/core/events/`) kalır. Feature dosyaları buff listesini okur.
5. **UI state ≠ ekonomik state.** Görsel animasyon state'i, oyun ekonomisini etkileyemez.
6. **Çarpanlar tek yerde toplanır** (PRD §8.6). Dağınık multiplier yasaktır.

## 7. State management kuralları
PRD §7.9:
- State **deterministic** olmalı.
- Ekonomiyi etkileyen tüm hesaplamalar **saf fonksiyonlarda** tutulur.
- Görsel state ekonomik state'ten **fiziksel olarak ayrılır** (ayrı dosya / ayrı store).
- Offline hesap deterministic replay değil, **timestamp delta** ile çözülür.
- Feature flag yaklaşımı unlock ağacı ile **uyumlu** tutulur.

Top-level state şekli `GameState` → PRD §7.1'e tam uyar: `meta`, `run`, `inventory`, `buildings`, `upgrades`, `research`, `events`, `achievements`, `collections`, `settings`, `telemetry`, `save`.

## 8. Save migration kuralları
PRD §7.8:
- Save **envelope**'ı `{ version, lastSavedAt, gameState, checksum }`.
- Her save sürümü için migration fonksiyonu `lib/core/save/migrations/` altında yaşar.
- Migration **idempotent** olmalı; aynı save'e iki kez uygulandığında bozulmamalı.
- Checksum her yazmada yeniden hesaplanır; okumada doğrulanır.
- Checksum başarısız → son güvenli save'e düş (NFR-2).
- Save format değişikliği **tek task'ta yapılmaz** (§16.8).

Yeni alan ekleme:
1. `GameState` tipini genişlet
2. `version` bump et
3. Eski sürümden yeni sürüme migration yaz
4. Migration'a unit test yaz
5. Dokümanı (`docs/save-format.md`) güncelle

## 9. Test zorunlulukları
PRD §16.7 — ilk günden test edilecek kritik alanlar:
- economy formülleri
- prestige gain formülü
- offline progress hesaplaması
- upgrade prerequisite çözümleme
- save migration
- daily reset mantığı
- event spawn kuralları

Bir task bu alanlardan birine dokunuyorsa test olmadan "bitti" değildir.

"Bitti" tanımı (PRD §16.6):
- Kod derleniyor
- İlgili testler geçiyor
- Acceptance criteria karşılanıyor
- Gerekiyorsa dokümantasyon güncellendi

## 10. Plan mode gerektiren değişiklikler
PRD §16.8 — aşağıdaki değişikliklerden birine dokunmadan önce **plan çıkar, onay al**:
- Save format değişikliği
- Economy rebalance + UI refactor aynı anda
- Prestige reset mantığı değişikliği
- Event engine rewrite
- Dizin yapısı / modül sınırlarının değişmesi
- Tech stack değişimi

Bu task'lar tek oturumda bitirilmez; etki analizi ve dilimlenmiş teslimat zorunludur.

## 11. Görev sözleşmesi
Claude Code'a verilen her görev küçük ve doğrulanabilir olmalı (PRD §16.4).

İyi görev şablonu (PRD §16.3):
1. Problem
2. Scope
3. Affected files
4. Constraints
5. Verification
6. Output expected

Yasak görev biçimleri: "oyunu bitir", "ekonomiyi düzelt", "UI'ı daha iyi yap".

## 12. Gotcha'lar ve tasarım korumaları
Yanlış uygulanması kolay olan noktalar:

- **Offline kazanç pasif oyunu öldürmez, aktif oyunu anlamsızlaştırmaz** (§8.3/5-6). Balans değişikliklerinde iki uçtan birine kaymamaya dikkat.
- **Streak kaybı YOK, ceza tabanlı geri dönüş YOK** (§10.3). "Kaçırırsan kaybedersin" mekaniği önerisi reddedilir.
- **Her 2-3 dakikada anlamlı karar** (§8.3/3). Salt sayı akışı kötü tasarım sinyalidir.
- **Session recap MVP kapsamındadır** (§6.9). Post-MVP'ye atılamaz.
- **Ekranda aynı anda en fazla 3 aktif öneri** (§6.1). UI kalabalığı yasak.
- **Premium bina, sert paywall, progression'ı bozan IAP YOK** (§8.9).
- **Codegen sırası sabittir:** `pub get` → `dart run build_runner build` → `flutter analyze` → `flutter test`. Fresh clone'da codegen öncesi `flutter analyze` `uri_does_not_exist` verir — panik yok, build_runner'ı çalıştır.
- **FVM pin uyarısı:** `.fvm/fvm_config.json` 3.41.5 pinli (Dart 3.11 bundle). Pubspec `sdk: ^3.8.0` istediği için daha eski Flutter (3.27 vs) reddedilir. FVM ile pin'e geç: `fvm use 3.41.5`.
- **Riverpod 3.x breaking:** `StateProvider<T?>` deprecate oldu — `legacy.dart`'a taşındı. Yerine `NotifierProvider<TSignal, T?>` + `Notifier<T?>` subclass kullan (read API aynı; write: `ref.read(p.notifier).state = x`). `AsyncValue.valueOrNull` → `AsyncValue.value` rename'lendi.
- **Lifecycle observer tercihi:** Flutter 3.13+ `AppLifecycleListener` (sadece ihtiyaç callback'leri — `onPause`/`onResume`/`onDetach`), `WidgetsBindingObserver.didChangeAppLifecycleState` switch'i YERİNE. `lib/app/lifecycle/app_lifecycle_gate.dart` bu pattern üzerine kurulu; paused→resumed direkt geçişi assert hatası verir (canonical `inactive → hidden → paused` zinciri gerekli — test yazarken dikkat).
- **Save race lock:** `SaveRepository.save` içinde `Future<void>? _pending` while-loop ile serialize — 30s autosave timer + purchase sync + lifecycle pause çakışmalarını .bak rotation race'siz tutar. `dart:io` atomic rename (tmp→main) aynı filesystem'de garanti.
- **Canonical JSON checksum niyet:** `lib/core/save/checksum.dart` `SplayTreeMap` key-sort (recursive, nested Map'ler dahil) + `sha256` hex. Amaç yalnız **corruption detection** (NFR-2); tamper resistance kapsam dışı (single-player offline). Anti-cheat gelirse HMAC + server secret'a geçilir, `Checksum.of` API surface korunur.
- **OfflineReport push kuralı:** Cold start (`GameStateNotifier.build()` hydration) YALNIZCA — `applyResumeDelta` (hot resume) sessiz çalışır, `offlineReportProvider` / `saveRecoveryProvider` ikisini de push ETMEZ. Hot resume'da snackbar gösterilmez (ürpertici). Kural invariant-test ile korunur.
- **MultiplierChain 3-site injection:** Upgrade satın alındıktan sonra yeni multiplier'ın etkili olması için chain **üç noktada** yeniden uygulanır: `tick()` (idle loop), `hydrate()` (cold start) ve `applyResumeDelta()` (hot resume). Bir site atlanırsa buy→tick arası stale-multiplier race oluşur. Invariant test: `test/core/economy/multiplier_chain_sites_test.dart`. Yeni bir "state'i ilerleten" metod eklerken chain uygulamayı unutma.
- **SaveMigrator raw-first imza:** `SaveMigrator.migrate(Map<String, dynamic> rawEnvelope, int fromVersion)` — typed `SaveEnvelope` değil **ham JSON** alır. Gerekçe: v1 (untyped) → v2 (typed) geçişinde field rename/type değişimi typed model'e mapping'den ÖNCE çalışmalı; aksi halde `SaveEnvelope.fromJson` v1 payload'ı reddeder ve migration hiç çalışmaz. B1 T14 post-review düzeltmesi. Yeni migration step eklerken ham Map üzerinde çalıştığından emin ol.
- **Fire-and-forget persist (`_persistSafe`):** `GameStateNotifier` içinde purchase/upgrade sonrası persist `_persistSafe(updated, 'context')` ile sarılır: `unawaited(_persist(g).catchError((e, st) => debugPrint(...)))`. UI latency'yi önlemek için **await edilmez**; silent fail 30s autosave timer ile telafi edilir. Error logging zorunlu (context string debug'da hangi kaynağın fail ettiğini gösterir). Yeni mutator eklerken doğrudan `_persist` çağırma — her zaman `_persistSafe` kullan.
- **Tutorial AsyncNotifier pattern:** `TutorialNotifier extends AsyncNotifier<TutorialState>` (build() async SharedPreferences hydrate). Sync `Notifier + manual hydrate()` pattern'i flicker race üretir (UI completed=false default mount → hydrate sonrası completed=true flip). `tutorialActiveProvider` loading/error state'te false döner — UI overlay mount hydrate tamamlanana kadar gizli. Invariant [I11].
- **Tutorial scaffold mount kontratı:** `TutorialScaffold` MUTLAKA `MaterialApp.router(builder: (ctx, child) => TutorialScaffold(child: child ?? SizedBox.shrink()))` üzerinden mount edilir. `MaterialApp` yukarısında veya router config olmadan mount edilirse `GoRouterState.of(context)` (route-aware Step 2) fail eder. Invariant [I12].
- **InstallId GameState-wins reconciliation:** `installIdProvider` (SharedPreferences-backed) ve `GameState.meta.installId` boot sonrası senkron. Boot sırası: `ensureLoaded()` → `gameState hydrate` → `adoptFromGameState(gs.meta.installId)` — GameState authoritative; disk farklıysa disk overwrite edilir (save dosyası cross-device tek kaynak olduğu için). Telemetry payload'lar `resolveInstallIdForTelemetry(ref.read(installIdProvider))` üzerinden okunur — null ise `<not-loaded>` sentinel döner (invariant [I1], integration test bu sentinel'ı production emission'da reddeder).
- **onPause sıra (session ordering):** `AppLifecycleGate._onPause` → `await persistNow()` ÖNCE, `sessionController.onPause()` SONRA. Gerekçe: pause sırasında süreç öldürülürse persist garanti edilmiş olmalı; telemetry SessionEnd kayıp kabul edilebilir. Invariant [I6]. `_autoSaveTimer` 30s → yalnız persist (telemetry tetiklemez).

## 13. Açık sorulara alınan kararlar (PRD §19)
Tüm sorular 2026-04-16 tarihinde karara bağlandı. Sayısal değerler playtest sonrası ayarlanabilir; `docs/economy.md §11` tek parametre kaynağıdır.

1. **Tema:** Bakery empire, premium execution. Prestige scale arcı — artisan → endüstriyel → galaktik fırın imparatorluğu.
2. **Kaynaklar:** MVP'de tek ana kaynak (R1 = Crumbs). R2 (Research Shards) 15-30 dk unlock penceresinde açılır; R3 (Prestige Essence) ilk prestige sonrası.
3. **Rewarded ad cooldown:** 4 saat (playtest-ayarlanır).
4. **İlk prestige zamanı:** ~45 dakika hedef; PRD §8.3 "30-60 dk" aralığının ortası.
5. **Research node sayısı (MVP):** 12. Phase 2'de ikinci research kolu eklenir (§14 roadmap).
6. **No-ads IAP + rewarded ad buff kartı:** No-ads satın alındığında rewarded ad buff kartı Home'dan tamamen gizlenir — bedava buff verilmez. Gerekçe: rewarded ad değer önerisi korunur; paralı kullanıcıya ek avantaj sunulmaz.
7. **Aktif research iptali:** İptal edilen araştırmanın R2 maliyeti **iade edilmez**. Gerekçe: tek slot kuyruk sistemi zaten bir ekonomik frictionken iade bunu sulandırır; iptal dikkatli planlama teşvik eder.

Yeni açık soru çıkarsa bu bölümü PRD'deki karşılığıyla birlikte güncelle.

## 14. Referans
- Ürün kararları, ekonomi ilkeleri, unlock ağacı, sprint planı → `cookie_clicker_derivative_prd.md`
- Bu dosya değişirse: PRD ile tutarlı olduğunu doğrula.
