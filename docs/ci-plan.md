# CI/CD Planı — GitHub Actions Pipeline

**Proje:** Project Crumbs
**Kapsam:** CI/CD platform seçimi ve GitHub Actions YAML şablonları
**Kaynak:** `docs/test-plan.md §5, §10.1`; `docs/scaffold-plan.md §2, §8`; CLAUDE.md §3
**Güncelleme:** 2026-04-16

> Bu doküman `docs/test-plan.md §10.1` CI kuralları tablosunu operasyonalize eder. Test senaryoları, ekonomi formülleri veya save migrasyonu bu dokümanda yer almaz.
> Scaffold PR merge edildiğinde `docs/test-plan.md §10.1` ve `CLAUDE.md §3`'teki "CI platformu TBD" notu bu dokümanla senkronize güncellenir.

---

## 1. Doküman Amacı

Bu doküman şu üç şeyi tanımlar:

1. **Platform seçim gerekçesi** — adayların karşılaştırmalı analizi ve MVP için seçilen platform.
2. **Workflow dosya yapısı** — `.github/workflows/` altında üç dosyanın sorumluluğu ve tetikleyicileri.
3. **Tam YAML içerikleri** — kopyala-yapıştır hazır; stub değil.

**Bu doküman NE DEĞİLDİR:**

- Fastlane / Codemagic ile TestFlight veya Play Store otomasyonu değil — post-MVP runbook.
- Code signing detayı değil — `release.yml` sadece artifact üretir; imzalama ayrı task.
- Firebase Hosting / App Distribution kurulumu değil.
- Test senaryosu veya coverage analiz raporu değil — bkz. `docs/test-plan.md`.
- Slack / Discord notifier tam implementasyonu değil — webhook TODO.

---

## 2. Platform Karar Çerçevesi

| Aday | Güçlü | Zayıf | Fiyat (MVP) |
|---|---|---|---|
| **GitHub Actions** | macOS runner iOS build için hazır; free tier cömert; ekosistem geniş (`flutter-action`, `upload-artifact`, `android-emulator-runner`); repo ile entegre; secrets yönetimi yerleşik | Private repo macOS runner dakika maliyeti yüksek; paralel job kotası free tier'da sınırlı | Public repo: sınırsız free; Private: 2 000 dk/ay (Linux) + 10× macOS çarpanı |
| CircleCI | macOS runner var; Flutter orb hazır; Linux'ta geniş free tier | Free tier'da macOS dakika kotası düşük; ayrı hesap / konfigürasyon | 6 000 build dk/ay Linux free; macOS ücretli |
| Codemagic | Flutter-native; TestFlight / Play Store entegrasyonu kolay; Mac mini pool | Free tier sadece 500 build dk/ay — CI gate için yetersiz | 500 dk/ay free; sonrası paid |
| Bitrise | Mobile-first; görsel workflow editörü | Ücretli tier hızlı dolar; Flutter desteği Codemagic kadar native değil | Free tier sınırlı; kredi tabanlı |

**Öneri: GitHub Actions — MVP için.**

Codemagic, TestFlight / Play Store store otomasyonu eklendiğinde ikinci katman olarak **üstüne eklenir**; bu iterasyon post-MVP runbook'tadır.

---

## 3. Karar: GitHub Actions

**Gerekçe:**

- **Maliyet:** Public repo gerekirse tüm pipeline ücretsiz. Private repo senaryosunda bile Linux runner'da PR gate maliyeti ihmal edilebilir; macOS yalnızca nightly ve release'te kullanılır.
- **iOS build:** macOS runner gerektiren `flutter build ios --release --no-codesign` ve simulator entegrasyon testleri GitHub'ın kendi macOS pool'unda çalışır — harici servis gerekmez.
- **Ekosistem:** `subosito/flutter-action@v2`, `reactivecircus/android-emulator-runner@v2`, `actions/upload-artifact@v4` gibi aktif bakımlı action'lar Flutter projelerinde yaygın kullanımdadır.
- **Katmanlama:** Codemagic veya Fastlane ile TestFlight otomasyonu post-MVP'de mevcut workflow'ların yanına ek bir `deploy.yml` olarak eklenir; mevcut pipeline değişmez.
- **Secrets yönetimi:** GitHub Actions native secrets ile `ANDROID_KEYSTORE_BASE64`, `APPLE_CERTIFICATE_BASE64` gibi değerler repo ayarlarından yönetilir.

---

## 4. Workflow Dosyaları

Üç dosya `.github/workflows/` altında konumlanır. Her dosyanın tek bir sorumluluğu vardır:

| Dosya | Tetikleyici | Sorumluluk |
|---|---|---|
| `ci.yml` | Her PR (main'e) + main push | Hız kapısı: analyze + unit + widget + golden + coverage gate |
| `nightly.yml` | Gecelik cron (UTC 03:00) + manual dispatch | Integration testler: Android emülatör + iOS simulator |
| `release.yml` | `v*.*.*` tag push + manual dispatch | APK / AAB / iOS Runner.app artifact üretimi |

**Tasarım ilkesi:** PR gate hızlıdır (hedef < 15 dk, yalnızca Linux runner). Integration testler geceye ertelenir — macOS runner maliyetini ve bekleme süresini PR'dan ayırır. Release build yalnızca etiketlere tetiklenir; her commit'te gereksiz build yapılmaz.

---

## 5. `ci.yml` — PR Gate

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  analyze_test:
    name: Analyze + Unit + Widget + Golden + Coverage
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Kod üretimi (build_runner)
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Statik analiz
        # docs/test-plan.md §10.1 — sıfır hata, sıfır uyarı zorunlu
        run: flutter analyze

      - name: Unit + Widget + Golden testleri
        run: flutter test --coverage

      - name: lcov kurulum
        run: sudo apt-get install -y lcov

      - name: Coverage özeti
        run: lcov --summary coverage/lcov.info

      - name: Coverage gate
        # docs/test-plan.md §5 per-modül hedefleri:
        #   lib/core/economy/    → satır %95+, dal %90+
        #   lib/core/save/       → satır %95+, dal %90+
        #   lib/core/progression → satır %90+, dal %85+
        #   lib/core/events/     → satır %85+, dal %80+
        #   lib/features/*       → satır %70+
        # Detaylı per-modül kontrol scripts/check_coverage.sh'de (ayrı PR'da yazılır)
        run: bash scripts/check_coverage.sh

      - name: Coverage artifact yükle
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/
          retention-days: 14

      - name: Golden snapshot diff kontrolü
        # Golden testler --coverage çalışmasında zaten koşar.
        # Tag ile izole etmek gerekirse: flutter test --tags=golden
        run: echo "Golden testleri analyze_test adımında kapsandı"
```

**Notlar:**

- `subosito/flutter-action@v2` — Flutter resmi action; `flutter-version` pin `3.41.5` (`docs/scaffold-plan.md §2` ile senkron).
- `cache: true` — pub bağımlılıkları cache'lenir; tekrarlanan çalışmalarda `flutter pub get` süresi düşer.
- `flutter test --coverage` unit + widget + golden testlerin tamamını tek geçişte çalıştırır ve `coverage/lcov.info` üretir.
- `scripts/check_coverage.sh` scaffold PR'dan sonraki ayrı PR'da yazılır; placeholder olarak `exit 0` ile başlatılabilir, ardından gerçek threshold kontrolleri eklenir.

---

## 6. `nightly.yml` — Integration Testler

```yaml
name: Nightly Integration Tests

on:
  schedule:
    - cron: '0 3 * * *'   # UTC 03:00 = TR 06:00
  workflow_dispatch: {}     # Manuel tetikleme (debug için)

jobs:
  integration_android:
    name: Integration — Android Emülatör
    runs-on: macos-latest   # Android emülatör hardware accel için macOS tercih edilir
    timeout-minutes: 40

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Kod üretimi
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Android emülatör başlat ve integration test çalıştır
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 33
          target: google_apis
          arch: x86_64
          script: flutter test integration_test/

      - name: Hata bildirimi
        if: failure()
        # Slack webhook: SLACK_WEBHOOK_URL secret'ı ayarlandığında aktif edilir.
        # Şimdilik log'a yazar; gerçek webhook scaffold sonrası ayrı PR'da eklenir.
        run: |
          echo "::error::Nightly Android integration testleri başarısız."
          echo "Bildirim kanalı henüz yapılandırılmadı — SLACK_WEBHOOK_URL secret eklendiğinde aktif edilecek."

  integration_ios:
    name: Integration — iOS Simülatör
    runs-on: macos-latest
    timeout-minutes: 40

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Kod üretimi
        run: dart run build_runner build --delete-conflicting-outputs

      - name: iOS simülatör başlat
        run: |
          xcrun simctl list devices available
          xcrun simctl boot "iPhone 15" || true
          # Simülatörün boot tamamlaması için kısa bekleme
          sleep 10

      - name: Integration testleri çalıştır
        run: flutter test integration_test/ -d "iPhone 15"

      - name: Hata bildirimi
        if: failure()
        run: |
          echo "::error::Nightly iOS integration testleri başarısız."
          echo "Bildirim kanalı henüz yapılandırılmadı — SLACK_WEBHOOK_URL secret eklendiğinde aktif edilecek."
```

**Notlar:**

- Nightly, `docs/test-plan.md §10.1` gereği PR'da zorunlu değildir; gece başarısız olursa sabah düzeltilmeden yeni PR merge edilmez.
- `reactivecircus/android-emulator-runner@v2` — Android emülatörü macOS üzerinde çalıştırmak için en yaygın kullanılan action; hardware acceleration (HAXM) macOS runner'da desteklenir.
- `api-level: 33` — `docs/scaffold-plan.md §2` Android minimum API 21; test API 33 (Android 13) modern bir hedef sağlar.
- Her iki job bağımsızdır; paralel çalışır ve toplam süreyi kısaltır.

---

## 7. `release.yml` — Artifact Build

```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch: {}     # Manuel tetikleme (test için)

jobs:
  build_android:
    name: Android APK + AAB
    runs-on: ubuntu-latest
    timeout-minutes: 25

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Kod üretimi
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Android release APK build
        # Keystore imzalaması post-MVP'de eklenir (ANDROID_KEYSTORE_BASE64 secret ile).
        # Şimdilik debug keystore ile release build — dağıtım için yeterli değil, artifact doğrulama için yeterli.
        run: flutter build apk --release

      - name: Android release AAB build
        run: flutter build appbundle --release

      - name: Android artifact yükle
        uses: actions/upload-artifact@v4
        with:
          name: android-release-${{ github.ref_name }}
          path: |
            build/app/outputs/flutter-apk/app-release.apk
            build/app/outputs/bundle/release/app-release.aab
          retention-days: 30

  build_ios:
    name: iOS IPA (imzasız)
    runs-on: macos-latest
    timeout-minutes: 25

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Flutter kurulum
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'
          cache: true

      - name: Bağımlılıkları yükle
        run: flutter pub get

      - name: Kod üretimi
        run: dart run build_runner build --delete-conflicting-outputs

      - name: iOS release build (imzasız)
        # --no-codesign: Apple sertifikası ve provisioning profile gerekmez.
        # Gerçek TestFlight dağıtımı post-MVP'de Codemagic veya Fastlane ile eklenir.
        run: flutter build ios --release --no-codesign

      - name: iOS artifact yükle
        uses: actions/upload-artifact@v4
        with:
          name: ios-release-${{ github.ref_name }}
          path: build/ios/iphoneos/Runner.app
          retention-days: 30
```

**Notlar:**

- `release.yml` yalnızca artifact üretir. Play Store / TestFlight yükleme adımları **post-MVP runbook**'tadır.
- Android imzalaması (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` secrets) post-MVP'de `build apk --release` satırından önce keystore decode + `key.properties` yazma adımı olarak eklenir.
- iOS imzalaması (`APPLE_CERTIFICATE_BASE64`, `APPLE_PROVISIONING_PROFILE_BASE64` secrets) Fastlane `match` veya Codemagic ile post-MVP'de katmanlanır.
- `${{ github.ref_name }}` tag adını artifact ismine ekler; `v1.0.0` etiketinde artifact adı `android-release-v1.0.0` olur.
- **Uyarı:** `workflow_dispatch` ile `feat/x` gibi slash'lı branch adından manual tetiklenirse `ref_name` geçersiz karakter içerir ve `upload-artifact` hata verir. Workflow ilk yazılırken `replace` veya sanitize edilmiş input parametresi eklenmeli.
- **Slack bildirim uyarısı:** `nightly.yml`'deki `if: failure()` adımı şu an sadece `echo` yapar — webhook secret'i tanımlanınca `curl` çağrısıyla değiştirilmeli, aksi halde bildirim *gerçek değildir*.

---

## 8. Coverage Gate Implementasyonu

Coverage gate `ci.yml` içinden `scripts/check_coverage.sh` çağrılarak uygulanır. Script `exit 1` dönerse CI job başarısız olur ve PR merge edilemez.

**`scripts/check_coverage.sh` taslağı** (scaffold sonrası ayrı PR'da yazılır):

```bash
#!/bin/bash
# Coverage gate — docs/test-plan.md §5 per-modül threshold doğrulaması.
# Çalıştırma: flutter test --coverage ardından bu script.
# Gereksinim: lcov (sudo apt-get install -y lcov)
set -euo pipefail

LCOV_FILE="coverage/lcov.info"

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "HATA: $LCOV_FILE bulunamadı. Önce 'flutter test --coverage' çalıştırın."
  exit 1
fi

# docs/test-plan.md §5 threshold sabitleri (satır coverage)
ECONOMY_MIN=95
SAVE_MIN=95
PROGRESSION_MIN=90
EVENTS_MIN=85
FEATURES_MIN=70

# Per-modül lcov filtresi + threshold kontrol fonksiyonu
# Gerçek implementasyon scaffold sonrası PR'da:
#   lcov --extract "$LCOV_FILE" "*/core/economy/*" -o /tmp/economy.info
#   ACTUAL=$(lcov --summary /tmp/economy.info | grep "lines" | grep -oP '\d+\.\d+(?=%)')
#   [ "$(echo "$ACTUAL >= $ECONOMY_MIN" | bc -l)" -eq 1 ] || { echo "HATA: economy satır coverage $ACTUAL% < $ECONOMY_MIN%"; exit 1; }

echo "Coverage gate: placeholder — gerçek per-modül kontrol scaffold sonrası PR'da eklenir."
echo "Mevcut lcov özeti:"
lcov --summary "$LCOV_FILE"

# Şimdilik genel satır coverage'ını kontrol et (minimum %70 global)
GLOBAL_LINE=$(lcov --summary "$LCOV_FILE" 2>&1 | grep "lines" | grep -oP '\d+\.\d+(?=%)' | head -1)
PASS=$(echo "${GLOBAL_LINE:-0} >= 70" | bc -l)
if [[ "$PASS" -eq 0 ]]; then
  echo "HATA: Global satır coverage ${GLOBAL_LINE}% — minimum %70 altında."
  exit 1
fi

echo "Coverage gate geçti (global: ${GLOBAL_LINE}%)."
```

**Eşleşme tablosu — `test-plan.md §5` ile senkron:**

| Modül | Satır hedef | Dal hedef |
|---|---|---|
| `lib/core/economy/` | %95+ | %90+ |
| `lib/core/save/` | %95+ | %90+ |
| `lib/core/progression/` | %90+ | %85+ |
| `lib/core/events/` | %85+ | %80+ |
| `lib/features/*` | %70+ | — |
| `lib/ui/` | Smoke | — |
| `lib/app/` | Smoke | — |

> `test-plan.md §5` bu tablonun tek gerçek kaynağıdır. Threshold değişirse hem `test-plan.md` hem `check_coverage.sh` aynı commit'te güncellenir.

---

## 9. Secrets Yönetimi

Tüm secrets GitHub repo ayarlarından (`Settings → Secrets and variables → Actions`) tanımlanır. Kod içinde açık metin secret bulunmaz.

| Secret | Kullanım yeri | MVP'de gerekli mi? |
|---|---|---|
| `SLACK_WEBHOOK_URL` | `nightly.yml` hata bildirimi | Opsiyonel — tanımlı değilse step atlanır |
| `ANDROID_KEYSTORE_BASE64` | `release.yml` Android imzalama | Hayır — post-MVP |
| `ANDROID_KEYSTORE_PASSWORD` | `release.yml` Android imzalama | Hayır — post-MVP |
| `ANDROID_KEY_ALIAS` | `release.yml` Android imzalama | Hayır — post-MVP |
| `ANDROID_KEY_PASSWORD` | `release.yml` Android imzalama | Hayır — post-MVP |
| `APPLE_CERTIFICATE_BASE64` | `release.yml` iOS imzalama | Hayır — post-MVP |
| `APPLE_PROVISIONING_PROFILE_BASE64` | `release.yml` iOS imzalama | Hayır — post-MVP |
| `FIREBASE_TOKEN` | Firebase CLI (post-MVP App Distribution) | Hayır — post-MVP |

**MVP için eylem:** Yalnızca `SLACK_WEBHOOK_URL` isteğe bağlı olarak tanımlanır. Diğer secrets tanımlanmadan pipeline çalışır; imzasız artifact üretilir.

---

## 10. CI Performans Hedefleri

| Pipeline | Hedef süre | Runner | Ana maliyet kalemi |
|---|---|---|---|
| PR gate (`ci.yml`) | < 15 dakika | ubuntu-latest | pub cache ısındıktan sonra ~8-12 dk beklenir |
| Nightly integration (`nightly.yml`) | < 40 dakika / job | macos-latest | Android emülatör boot ~3-5 dk; test süresi baskın |
| Release build (`release.yml`) | < 25 dakika / job | ubuntu-latest (Android), macos-latest (iOS) | iOS build derleme süresi baskın |

**Hız iyileştirme stratejileri:**

- `cache: true` (`flutter-action`) — pub bağımlılıkları workflow çalışmaları arasında önbelleğe alınır.
- `build_runner` çıktıları (`*.g.dart`, `*.freezed.dart`) Git'e eklenmez; her CI koşusunda yeniden üretilir (bkz. `docs/scaffold-plan.md §9`).
- PR gate'te macOS runner kullanılmaz; macOS maliyeti yalnızca nightly ve release'e ayrılır.
- `timeout-minutes` her job'da tanımlıdır; takılı build'ler dakika kotasını tüketmez.

---

## 11. Scaffold Sonrası Yapılacaklar

- [ ] `.github/workflows/ci.yml` ekle.
- [ ] `.github/workflows/nightly.yml` ekle.
- [ ] `.github/workflows/release.yml` ekle.
- [ ] `scripts/check_coverage.sh` yaz ve `chmod +x` yap.
- [ ] İlk PR'da CI yeşilini doğrula; `flutter analyze` + testler geçmeli.
- [ ] `docs/test-plan.md §10.1` "CI platformu TBD" satırını "GitHub Actions — bkz. `docs/ci-plan.md`" olarak güncelle.
- [ ] `CLAUDE.md §3` "CI platformu TBD" notunu güncelle.
- [ ] `SLACK_WEBHOOK_URL` secret'ı isteğe bağlı olarak tanımla.
- [ ] Firebase / signing secrets rehberi ayrı runbook olarak yaz (post-MVP).
- [ ] Codemagic TestFlight otomasyonu: post-MVP, ayrı `deploy.yml` + runbook.

---

## 12. Bu Doküman Ne Değildir

| Konu | Nerede ele alınır |
|---|---|
| Fastlane / Codemagic TestFlight otomasyonu | Post-MVP runbook — henüz mevcut değil |
| Code signing adım adım kurulum | Post-MVP runbook — Apple Developer + keystore detayları |
| Firebase App Distribution | Post-MVP — Firebase runbook |
| Test senaryoları ve kabul kriterleri | `docs/test-plan.md` |
| Economy formülleri | `docs/economy.md` |
| Save migration | `docs/save-format.md` |
| Scaffold PR adımları | `docs/scaffold-plan.md` |
| Slack / Discord notifier tam implementasyonu | Webhook URL tanımlandığında `nightly.yml` güncellenir |
