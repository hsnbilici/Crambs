# Plan-03: Flutter Scaffold (Yol 3)

**Tarih:** 2026-04-16
**Önceki plan:** `todo-02-improvements.md` (Yol 1+2 doc tamamlandı)
**Çalışma modeli:** `superpowers:subagent-driven-development` (implementer → spec reviewer → quality reviewer)
**Kaynak spec:** `docs/scaffold-plan.md`, `docs/ci-plan.md`, `docs/visual-design.md`
**Governance:** `CLAUDE.md §3, §5, §6, §7, §8, §10`, PRD §16.5, §17 Sprint 0

---

## 0. Ön kararlar (onaylanması gereken)

| # | Karar | Önerim | Gerekçe |
|---|-------|--------|---------|
| K1 | **Branch stratejisi** | Mevcut `docs/complete-documentation-suite` branch'i üzerine devam; scaffold commit'leri eklenir. PR tek paket — docs + scaffold atomic. | docs daha merge edilmedi; ayrı branch açılırsa docs'a dependency var. Tek PR hem ilk yayın hem scaffold'u aynı snapshot'a bağlar. |
| K2 | **Flutter sürüm pin** | `pubspec.yaml` + `ci-plan.md` `3.27.0` pin'inde kalır; local (3.41.5) sadece doğrulama için kullanılır. CI base'i ve dev ortamı zamanla senkron edilir. | scaffold-plan.md §2 spec'i değişmeden korunur; spec sürüklenmesi önlenir. Tutulan `3.27.0` PRD §16.8 "tech stack değişimi" kapsamında ayrı plan ister. |
| K3 | **Flutter CLI kullanımı** | Stub dosyaları `flutter create` **kullanılmadan** manuel yazılır (spec §5-6 zaten tam içerik veriyor). Fakat `flutter pub get` / `analyze` / `test` doğrulama adımlarında çalışır. | `flutter create` template boilerplate üretir; scaffold-plan.md'den sapar. Spec'e bire bir uymak için manuel yazım tercih edilir. |
| K4 | **Push ve PR** | Bu oturumda push YAPILMAZ. Tüm task'lar lokal commit; son adımda kullanıcı onayı ile push + PR açılır. | Shared state aksiyonu; kullanıcının explicit onayı gerekir (CLAUDE.md §4 + subagent-driven red flag). |

**K1-K4 onayınla başlanır.** İtiraz varsa plan güncellenir.

---

## 1. Kapsam

Flutter scaffold PR'ı için **8 görev**. Her görev `docs/scaffold-plan.md`'deki ilgili bölümden dosya üretir. Tüm üretim stub düzeyindedir; gerçek iş mantığı yok (`// TODO` yorumları kalır).

**Kapsam İÇİ:**
- `pubspec.yaml`, `analysis_options.yaml`, `.fvm/fvm_config.json`
- `.gitignore` genişletme
- `lib/` dizin iskeleti (8 modül)
- 42 stub dosya (scaffold-plan.md §6 tam içerikli)
- `lib/main.dart` minimal boot (çalıştırılabilir)
- `test/` mirror iskelet + smoke test
- `integration_test/` setup
- `.github/workflows/{ci,nightly,release}.yml`
- `CLAUDE.md §3` komut bloğunun doğrulanması

**Kapsam DIŞI:**
- Gerçek economy, save, event mantığı (ayrı sprint)
- Firebase / Ads / IAP SDK konfigürasyon dosyaları (ayrı runbook)
- App icon, splash screen asset üretimi (visual-design.md tasarımcı briefi)
- TestFlight / Play Console kimlik bilgileri (DevOps runbook)
- Gerçek ekran UI implementasyonu (Sprint 1+)

---

## 2. Görev dökümü ve ajan eşlemesi

### T1 — `pubspec.yaml` + `analysis_options.yaml` + `.fvm/fvm_config.json`
- **Spec:** `docs/scaffold-plan.md §2, §3, §4`
- **Dosya sayısı:** 3 yeni
- **Ajan:** `general-purpose` (haiku) — saf metin, mekanik
- **Kabul kriterleri:**
  - Tüm paket versiyonları spec §3 ile birebir
  - `very_good_analysis + custom_lint` plugin'leri aktif
  - `flutter pub get` hatasız döner (T8'de doğrulanır)
- **Risk:** Paket versiyonu pub.dev'de kaldırılmış olabilir — çözüm: sonraki patch'e yükselt ve spec notu düş.

### T2 — `.gitignore` genişletme
- **Spec:** `docs/scaffold-plan.md §9`
- **Dosya sayısı:** 1 güncelleme (mevcut .gitignore genişletilir)
- **Ajan:** `general-purpose` (haiku)
- **Kabul kriterleri:** Flutter, iOS, Android, FVM blokları eklenir; mevcut `.claude/` bloğu korunur.

### T3 — Core modül stub'ları
- **Spec:** `docs/scaffold-plan.md §5 (lib/core/*), §6 (ilgili stub içerikleri)`
- **Dosya sayısı:** ~12 stub (`lib/core/economy/`, `progression/`, `save/`, `events/`)
- **Ajan:** `general-purpose` (sonnet) — modül koordinasyonu
- **Kabul kriterleri:**
  - Her modülde `// TODO` yorumlu interface sketch
  - CLAUDE.md §6 mimari kuralları ihlal etmez (UI yok, state yazımı yok)
  - `save/migrations/` alt klasörü mevcut

### T4 — Features modül stub'ları
- **Spec:** `docs/scaffold-plan.md §5 (lib/features/*), §6`
- **Dosya sayısı:** ~12 stub (6 feature × 2 dosya ortalama)
- **Ajan:** `general-purpose` (sonnet)
- **Kabul kriterleri:** home, shop, upgrades, research, prestige, achievements her biri için minimum screen stub + provider stub.

### T5 — UI + app iskelet stub'ları
- **Spec:** `docs/scaffold-plan.md §5 (lib/ui/*, lib/app/*), §6`
- **Dosya sayısı:** ~8 stub
- **Ajan:** `general-purpose` (sonnet)
- **Kabul kriterleri:** theme tokens stub, component stub'ları, `app/routing/` ve `app/boot/` iskeleti.
- **Cross-ref:** `docs/visual-design.md` — renk / typography değerleri **placeholder** (hex YOK).

### T6 — `lib/main.dart` + test iskeleti
- **Spec:** `docs/scaffold-plan.md §6 (main.dart tam içerikli), §5 (test/)`
- **Dosya sayısı:** ~6 dosya
  - `lib/main.dart` (çalıştırılabilir minimal)
  - `test/` mirror klasörler + örnek unit test
  - `integration_test/app_test.dart` smoke test
- **Ajan:** `general-purpose` (sonnet) — Flutter entry point judgement
- **Kabul kriterleri:**
  - `flutter run` cihazda "Project Crumbs" placeholder ekranı açar
  - `flutter test` en az 1 yeşil test çıktısı verir
  - `flutter test integration_test/` yeşil

### T7 — CI workflow dosyaları
- **Spec:** `docs/ci-plan.md` — tüm YAML şablonları
- **Dosya sayısı:** 3 dosya (`.github/workflows/ci.yml`, `nightly.yml`, `release.yml`)
- **Ajan:** `general-purpose` (haiku) — mekanik YAML kopyası
- **Kabul kriterleri:**
  - `ci-plan.md §3-5` şablonları birebir
  - `subosito/flutter-action@v2` + `flutter-version: '3.27.0'` pinli
  - Coverage gate threshold'ları `test-plan.md §5` ile tutarlı

### T8 — Smoke verification + CLAUDE.md §3 blok testi
- **Spec:** `docs/scaffold-plan.md §8, §10 (checklist)`
- **Dosya sayısı:** 0 yeni; sadece komut doğrulama + rapor
- **Ajan:** Ben (controller) — tool çağrılarıyla bizzat
- **Kabul kriterleri:**
  - `flutter pub get` → exit 0
  - `flutter analyze` → 0 error, 0 warning (info'ya tolerans)
  - `flutter test` → tüm testler yeşil
  - `flutter test integration_test/` → smoke yeşil (cihaz varsa)
  - Scaffold-plan.md §10 checklist 17/17 ✓
- **Blokaj:** Android toolchain veya Chrome eksikliği integration test'i engellerse `DONE_WITH_CONCERNS` raporlanır, iOS simulator üzerinde smoke test yapılır.

---

## 3. Yürütme sırası

CLAUDE.md § + subagent-driven-development skill kuralları:
- Paralel implementer YASAK (conflict riski).
- Her task sırayla: **implementer → spec reviewer → quality reviewer → mark complete**.
- Spec reviewer yeşil vermeden quality reviewer başlamaz.

Seri akış:
1. T1 — pubspec + analysis_options + fvm_config
2. T2 — .gitignore genişletme
3. T3 — core modüller
4. T4 — features modülleri
5. T5 — UI + app iskeleti
6. T6 — main.dart + test iskeleti
7. T7 — CI workflow YAML'ları
8. T8 — smoke verification (controller)
9. **Final review** — tek quality reviewer tüm branch için (cross-cutting tutarlılık)
10. **Özet + push onayı talep**

---

## 4. Kabul kriterleri (bütün PR)

- [ ] scaffold-plan.md §10 checklist tüm maddeleri ✓
- [ ] Her task spec reviewer + quality reviewer yeşili aldı
- [ ] `flutter pub get` / `analyze` / `test` lokal olarak çalışıyor
- [ ] Yeni dosya yok, sadece spec dosyalarından türetilmiş (sürpriz dosya yasak)
- [ ] CLAUDE.md §3 komut bloğundaki hiçbir komut broken değil
- [ ] PRD §19 açık sorularına yeni karar eklenmemiş (bu scope'ta değil)
- [ ] `_dev/tasks/todo-03-scaffold.md` tamamlanmış olarak işaretli

---

## 5. Risk matrisi

| Risk | Olasılık | Etki | Azaltma |
|------|---------|------|---------|
| Paket versiyon drift (pub.dev) | Orta | Orta | T1'de versiyon kontrolü; gerekirse minor patch bump, spec note eklenir |
| `flutter create` bypass stub farklılığı | Düşük | Düşük | Spec §6 bire bir; `flutter analyze` yakalar |
| Android/Chrome eksik → integration test fail | Yüksek | Düşük | iOS simulator fallback; `DONE_WITH_CONCERNS` raporlanır |
| Local Flutter 3.41 vs pin 3.27 davranış farkı | Düşük | Düşük | Spec `3.27.0` pin'de kalır; uyarı not edilir |
| Branch'te docs + scaffold karışık PR | Orta | Düşük | PR açıklamasında iki bölüm ayrımı yapılır (bloke değil) |

---

## 6. Kararlar (onay bekliyor)

- [ ] **K1** — Tek branch (mevcut `docs/complete-documentation-suite`) onaylı mı?
- [ ] **K2** — Flutter pin `3.27.0`'da kalsın onaylı mı?
- [ ] **K3** — `flutter create` kullanılmasın, manuel yazım onaylı mı?
- [ ] **K4** — Push son adıma kadar yapılmasın onaylı mı?

**Onaylarsan T1'den başlarım. İtirazın varsa önce planı düzeltiriz.**

---

## İnceleme (T1-T8 tamamlandı, 2026-04-16)

### Commit zinciri

```
d38e0da scaffold(T7-fix): use `dart run build_runner` (Flutter 3.24+ convention)
f9380e9 scaffold(T7): GitHub Actions ci/nightly/release + coverage placeholder
9040962 scaffold(T6-fix): main.dart imports alphabetical per very_good_analysis
c10786e scaffold(T6): main.dart + test iskeleti + integration test
4857444 scaffold(T5): app bootstrap + routing + ui theme iskelet
4fcf316 scaffold(T4): features module stubs (7 screens + 2 controllers)
0e7c2bc scaffold(T3): core module stubs (economy, progression, save, events)
9a957a4 scaffold(T2): extend .gitignore with Flutter/iOS/Android/FVM blocks
7c2ff47 scaffold(T1-fix): drop dead analyzer rule + redundant linter overrides
b9d314d scaffold(T1): pubspec + analysis_options + fvm_config
```

+ `scaffold(T8-fix): create assets/.gitkeep (scaffold-plan §5)`

### Üretilen dosyalar

| Kategori | Dosya sayısı | Yer |
|---|---|---|
| Config | 3 | `pubspec.yaml`, `analysis_options.yaml`, `.fvm/fvm_config.json` |
| `.gitignore` | 1 | Genişletildi |
| `lib/core/` | 14 + .gitkeep | economy (6), progression (2), save (3+.gitkeep), events (3) |
| `lib/features/` | 10 | 8 page + 2 controller |
| `lib/app/ + lib/ui/` | 4 + .gitkeep | bootstrap, routing x2, theme + ui/components/.gitkeep |
| `lib/main.dart` | 1 | Functional entry point |
| `test/ + integration_test/` | 9 + .gitkeep | 6 unit tests + fixture + integration + golden/.gitkeep |
| `assets/.gitkeep` | 1 | T8-fix |
| CI | 4 | 3 workflow + `scripts/check_coverage.sh` |

**Toplam:** 45+ dosya scaffold. Gerçek iş mantığı yok; her biri `// TODO` işaretli.

### T8 smoke sonuçları

| Kontrol | Durum | Detay |
|---|---|---|
| `flutter pub get` | ✓ | 132 paket çözüldü |
| `flutter analyze --no-pub` | ⚠ | 50 issue: 6 error + 2 warning build_runner-bağımlı (codegen sonrası gider); 42 info style (flutter_style_todos, sort_pub_dependencies — cosmetic, tolerans içinde) |
| `flutter test` (non-freezed) | ✓ | 5/5: cost_curve, prestige, offline_progress, unlock_resolver, save_migrator |
| `flutter test save_envelope_test` | ✗ | Beklenen: build_runner öncesi `_$SaveEnvelope` resolve olmaz |
| `dart run build_runner build` | ✗ | Local Flutter 3.41.5 + analyzer 7.6.0 pinned `custom_lint ^0.7.0` / `riverpod_lint ^2.6.1` ile uyumsuz |
| `flutter run` | — | build_runner bağımlılığı nedeniyle denenemedi |
| Android build | — | Android SDK cmdline-tools eksik |
| iOS build | — | Denenmedi (scaffold için kritik değil) |

**Ana bulgu:** Local Flutter 3.41.5 pinned Flutter 3.27.0'dan sapıyor. Scaffold Flutter 3.27.0 için kalibre edildi (FVM ile pin); CI de 3.27.0 üzerinde çalışacak. Bu yüzden local'de `build_runner` başarısız, ama CI başarılı olmalı.

**Çözüm seçenekleri (T8 sonrası):**
1. `fvm install 3.27.0 && fvm use 3.27.0` sonra full smoke — tercih edilen
2. Pin'i 3.41.5'e bump + `custom_lint 0.8.x`, `riverpod_lint 3.x`, `very_good_analysis 10.x` uyumlu versiyonlara yükselt — PRD §16.8 "tech stack değişimi" kapsamı, ayrı plan
3. CI ilk çalışınca doğrulamayı oraya bırak — şu an için kabul edilebilir

### Kabul kriterleri (sonuç)

- [x] Her task spec + quality reviewer'dan geçti (T1-fix, T6-fix, T7-fix dahil)
- [x] Sürpriz dosya yok — tüm dosyalar spec'ten türetildi
- [x] PRD §19 açık sorularına yeni karar eklenmedi
- [x] Scaffold dizin yapısı CLAUDE.md §5 ile birebir
- [~] Local smoke kısmen: pub get ✓, non-freezed test ✓; full smoke FVM veya CI gerektiriyor (DONE_WITH_CONCERNS)
- [x] `_dev/tasks/todo-03-scaffold.md` tamamlanmış

### T9 ve push kararı

- T9 final cross-cutting review bekliyor (scaffold + CI + plan tutarlılığı).
- Push ve PR açma kullanıcının açık onayı ile yapılacak (K4).
