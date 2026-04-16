# CLAUDE.md — Project Crumbs

Bu dosya Claude Code için operasyonel rehberdir. Ayrıntılı ürün kapsamı için `cookie_clicker_derivative_prd.md` tek gerçek kaynaktır (single source of truth). Bu dosya ile PRD çelişirse PRD kazanır; çelişkiyi fark ettiğinde bu dosyayı güncelle.

## 1. Proje amacı
**Project Crumbs** — mobil öncelikli (iOS + Android), offline-first, tek oyunculu incremental oyun. Cookie Clicker'dan ilham alır fakat klonu değildir.

Ürün vaadi: **"30 saniyede öğren, 30 gün boyunca geri dön."**

MVP çekirdeği: tap loop → 8 bina → 30-40 upgrade → 12 research node → 3 random event → prestige → session recap. Detay için PRD §13.

## 2. Teknoloji stack
**Flutter** (Dart) — iOS + Android tek codebase (2026-04-16 karar).

Gerekçe: Idle oyun için yeterli performans, düşük öğrenme eğrisi, native bridge karmaşıklığı yok. Unity overkill, React Native'in game tick performans riski var.

Hâlâ karar bekleyen alt bileşenler (first PR'larda seçilecek):
- State management: Riverpod / BLoC / signals — ilk tercih: **Riverpod** (kolay test edilebilir, family/provider yapısı unlock ağacına uyar).
- Save persist: `path_provider` + JSON dosyası MVP için yeterli; büyürse Hive/Isar değerlendirilir.
- Test: `flutter_test` (unit + widget) + `integration_test`.
- Analytics / Ads / IAP: `firebase_analytics`, `google_mobile_ads`, `in_app_purchase`.

Stack değişimi PRD §16.8 kapsamında **riskli değişiklik** — tek task'ta yapılmaz.

## 3. Komutlar
Flutter stack'i için standart komutlar. Scaffold PR'ında `pubspec.yaml` ve `analysis_options.yaml` eklendikten sonra tümü çalışır hale gelir.

```bash
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

# Statik analiz (lint + typecheck — Dart tek geçişte yapar)
flutter analyze

# Production build
flutter build ios --release
flutter build apk --release
```

> CI platformu TBD — scaffold PR merge edildiğinde `docs/test-plan.md §10.1` ile senkron güncellenir.

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

**Ek operasyonel dokümanlar** (post-docs derinleştirme, scaffold öncesi):
- `docs/research-tree.md` ✓ — 12 MVP research node'u tam katalog
- `docs/upgrade-catalog.md` ✓ — 36 MVP upgrade listesi (6 etki tipi)
- `docs/scaffold-plan.md` ✓ — Flutter scaffold blueprint (pubspec, lib/ iskelet, stub içerikleri)
- `docs/ci-plan.md` ✓ — GitHub Actions workflow şablonları
- `docs/visual-design.md` ✓ — görsel kimlik brief'i (hex YOK, tasarımcı kesinleştirir)

Yeni zorunlu doc eklenirse bu liste ve PRD §16.1 birlikte güncellenir.

## 5. Dizin yapısı
PRD §16.5 "önerilen yapı"yı Flutter convention'ıyla eşleştiriyoruz: PRD'nin abstract `src/` kökü Flutter'da **`lib/`**'tir. `flutter run` otomatik `lib/main.dart` bekler; ayrı bir `src/` kullanmak her import'u `package:crumbs/src/...` yapar — temizlik kaybı. `lib/src/` pattern'i paket yayınlayıcılar (public API izolasyonu) içindir; tek başına uygulama için anlamsız.

```text
lib/
  main.dart         # Flutter entry point
  core/
    economy/        # tüm formül ve hesaplamalar
    progression/    # unlock ve prerequisite mantığı
    save/           # serialize / deserialize / migration
    events/         # event spawn, timer, buff hesabı
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
  app/
    routing/
    boot/
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
