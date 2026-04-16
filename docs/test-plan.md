# Test Planı — Strateji ve Kapsam Spesifikasyonu

**Proje:** Project Crumbs
**Kapsam:** MVP test stratejisi — birim, widget, entegrasyon, golden, manuel
**Kaynak:** PRD §16.6, §16.7, §12 NFR-1/3/5, CLAUDE.md §9
**Güncelleme:** 2026-04-16

> Bu doküman CLAUDE.md §9'un operasyonel detayıdır. Çelişki varsa PRD kazanır.
> Dart kaynak kodu bu dokümanda yoktur. Save migration fixture referansları için bkz. `docs/save-format.md`.
> Economy formülleri için bkz. `docs/economy.md`. UX akışları için bkz. `docs/ux-flows.md`.

---

## 1. Doküman Amacı

Bu doküman üç şeyi tanımlar:

1. **Hangi katmanda ne test edilir** — test piramidinin her katmanının kapsamı, araçları ve hız hedefi.
2. **Hangi alanlar zorunludur** — PRD §16.7'deki kritik alanların test matrisi; bu alanlar ilk günden test edilir, testler olmadan "bitti" sayılmaz.
3. **"Bitti" tanımı** — PRD §16.6'yı operasyonel kurallara dönüştüren kabul kriteri seti.

Bu doküman PRD'nin replikası değildir. Kodlama stil rehberi, performans profili sonuç raporu veya release kriteri / QA sign-off checklist değildir. Bu konular ayrı dokümanlarda ele alınır.

---

## 2. Test Piramidi

| Katman | Araç | Amaç | Hız hedefi |
|---|---|---|---|
| Unit / Deterministik formül | `flutter_test` + saf Dart | Economy formülleri, prestige hesabı, offline delta, migration mantığı; formül stabilitesi (§7'deki seed/saat inject kurallarına tabi) | < 5 ms/test |
| Widget | `flutter_test` + `WidgetTester` | UI bileşen davranışı, state binding, tap yanıtı, görünürlük | < 50 ms/test |
| Integration | `integration_test` | Uçtan uca akış: tutorial → ilk satın alma → session recap | < 30 s/test |
| Golden | `flutter_test` snapshot | Görsel regresyon — session recap modal, shop ROI kartı | < 100 ms/test |
| Manuel | Cihaz + §9 plan | 60 FPS, 100 ms tap yanıtı, erişilebilirlik, offline senaryo | — |

### 2.1 Katman sınırları

- **Unit / Deterministik formül**: Bağımlılık yoktur; `mocktail` ile I/O ve saat inject edilir. Rastgelelik kullanılmaz — §7'deki deterministik disipline bakınız. Economy formül testleri bu katmanın alt kümesidir; kırılması kasıtlıdır.
- **Widget**: Gerçek cihaz ya da simulatör gerektirmez; `WidgetTester` yeterlidir. State bağlamayı doğrular, ekonomi mantığı doğrulamaz.
- **Integration**: Gerçek cihaz veya emülatör gerekir. Tam oyun akışlarını kapsar; CI'da her geceye bir kez planlanır.
- **Golden**: Yalnızca bileşen görünümünü korur. Kasıtlı değişiklikten sonra `--update-goldens` ile güncellenir.
- **Manuel**: Otomatik testlerin erişemeyeceği NFR'ler için (60 FPS profili, fiziksel erişilebilirlik).

---

## 3. Kritik Test Alanları

PRD §16.7 — tüm alanlar ilk günden zorunludur. Bir task bu alanlardan birine dokunuyorsa test olmadan "bitti" değildir.

| Alan | Kaynak kod konumu | Test türü | Zorunlu senaryolar | Fixture gerekli? |
|---|---|---|---|---|
| Economy formülleri | `lib/core/economy/` | Unit + Deterministik formül | Cost curve her owned değeri için doğru maliyet döner; üretim çarpanları sırasıyla uygulanır; toplam çıktı deterministiktir | Hayır — saf fonksiyon, parametre yeter |
| Prestige gain formülü | `lib/core/economy/prestige/` | Unit + Deterministik formül | Eşik altında sıfır döner; beklenen thresholdda beklenen prestige currency hesabı doğru; prestige sonrası run state sıfırlanır, meta state korunur | Hayır |
| Offline ilerleme hesabı | `lib/core/economy/offline/` | Unit + Integration | Bilinen delta için beklenen kaynak üretilir; offline cap uygulanır; offline süresi sıfırsa sıfır delta döner; çok uzun offline süresi (> 24 saat) capped değer üretir | Evet — known-good snapshot |
| Upgrade prerequisite çözümleme | `lib/core/progression/` | Unit | Gereksinim karşılandığında upgrade kilitlenir/açılır doğru; çevrimsel bağımlılık (varsa) güvenli sonlanır; zincir bağımlılıklar doğru sıra ile çözülür | Hayır |
| Save migration | `lib/core/save/migrations/` | Unit | Her `vN → vN+1` migration'ı fixture ile round-trip geçer; idempotentlik — iki kez uygulandığında sonuç değişmez; `_archived` alanı bir sonraki versiyona taşınır ve iki versiyon sonra kalıcı olarak silinir (bkz. `docs/save-format.md §6`); versiyon zinciri (N → M, zincir en az 2 adım) ara adımları doğru sırayla çalıştırır | Evet — her versiyon için pre/post JSON fixture |
| Daily reset mantığı | `lib/core/events/` | Unit | UTC gece yarısı sınırında görevler sıfırlanır; resetin bir saniye öncesi sıfırlamamalı; saat dilimi offset'i reset zamanını kaydırmaz (UTC sabit); gün değişmeden iki reset tetiklenmez | Hayır — `Clock.fixed(...)` inject edilir |
| Event spawn kuralları | `lib/core/events/` | Unit + Integration | Seed tabanlı RNG ile beklenen event sırası üretilir; spawn cooldown kuralına uyulur; aynı event aynı anda iki kez tetiklenmez; event kapasitesi aşıldığında en eski event sürülür | Hayır — seed inject edilir |

---

## 4. "Bitti" Tanımı

PRD §16.6'dan türetilmiştir. Bir task aşağıdakilerin tümünü karşılamadan tamamlanmış sayılmaz:

| Kriter | Açıklama |
|---|---|
| Kod derleniyor | `flutter analyze` clean; sıfır hata, sıfır uyarı (analiz kuralları `analysis_options.yaml`'da tanımlanır). |
| İlgili testler geçiyor | §3'teki kritik alanlardan birine dokunan her task için ilgili unit / deterministik / widget testleri yeşil. |
| Acceptance criteria karşılanıyor | Task'ın kaynak PRD section'ındaki kabul kriterleri manuel veya otomatik olarak doğrulandı. |
| Dokümantasyon güncellendi | Davranış değişikliği varsa ilgili `docs/` dokümanı aynı commit'te güncellendi. |
| CI yeşil | `flutter analyze` + unit + widget + golden testlerin tamamı PR'da zorunlu (bkz. §10.1). Integration PR'da opsiyoneldir; gecelik scheduled koşuda kırmızı kalırsa ertesi gün yeni PR merge edilmez. |

---

## 5. Coverage Hedefleri

Coverage hedefleri modülün önem derecesine ve saf fonksiyon oranına göre belirlendi. Hedefin altında kalan bir modül CI gate'ini geçemez; PR merge edilemez.

| Modül | Satır coverage hedefi | Dal coverage hedefi | Gerekçe |
|---|---|---|---|
| `lib/core/economy/` | %95+ | %90+ | Formüller saf fonksiyon — tamamı test edilebilir; oyun balansını doğrudan etkiler. |
| `lib/core/save/` | %95+ | %90+ | Migration için fixture zorunlu; save bozulması kayıp yaratır (NFR-2). |
| `lib/core/progression/` | %90+ | %85+ | Unlock prerequisite mantığı karmaşık; yanlış çözüm oyun akışını kırar. |
| `lib/core/events/` | %85+ | %80+ | Random spawn seed tabanlı deterministik test ile kapsanır; event durumu birden fazla sistemi etkiler. |
| `lib/features/*` | %70+ | — | Widget + state binding; UI mantığı ekonomi katmanına sızmadığı sürece daha düşük hedef kabul edilebilir. |
| `lib/ui/` | Smoke (derleme + görünürlük) | — | Golden snapshot temel bileşenleri korur; ayrıntılı dal coverage UI katmanı için zorunlu değildir. |
| `lib/app/` | Smoke (boot + routing) | — | Integration test uçtan uca akışı kapsar; unit coverage ek değer üretmez. |

> Coverage hedefi `flutter test --coverage` çıktısından `lcov` aracı ile doğrulanır. CI pipeline bu kontrolü enforce eder.

---

## 6. Test İsimlendirme ve Organizasyon

### 6.1 Dosya yapısı

`test/` dizini kaynak ağacını birebir yansıtır:

```
test/
  core/
    economy/
      cost_curve_test.dart
      prestige_formula_test.dart
      offline_delta_test.dart
    progression/
      prerequisite_resolver_test.dart
    save/
      migration_v1_to_v2_test.dart
      save_repository_test.dart
      checksum_test.dart
    events/
      event_spawn_test.dart
      daily_reset_test.dart
  features/
    home/
      home_screen_test.dart
    shop/
      shop_screen_test.dart
  fixtures/
    save_v1.json
    save_v2.json
    offline_snapshot_known_good.json
  golden/
    session_recap_modal.png
    shop_roi_card.png
integration_test/
  tutorial_to_first_purchase_test.dart
  offline_progress_end_to_end_test.dart
```

### 6.2 Test adı formatı

Format: `<test edilen birim> <koşul> <beklenen>`

Örnekler:
- `cost_curve computes correct next price for owned=5`
- `prestige_formula returns zero when resource below threshold`
- `daily_reset resets goals at UTC midnight boundary`
- `save_migrator applies v1_to_v2 and v2_to_v3 in sequence`

### 6.3 Gruplama

İlgili test'ler `group(..., () {})` ile mantıksal kümelenir:

```
group('offline_delta', () {
  group('cap behavior', () { ... });
  group('zero duration', () { ... });
});
```

### 6.4 Fixture dosyaları

- `test/fixtures/` altında JSON olarak tutulur.
- Her save versiyonu için pre-migration ve post-migration ikisi birlikte bulunur: `save_v1.json`, `save_v2.json`.
- Round-trip testi: `save_vN.json` → migrate → karşılaştır `save_v{N+1}.json`.
- **Bootstrap:** `save_v{N+1}.json` ilk oluşturulurken migration çıktısı gözle incelenerek onaylanır ve commit'e eklenir; sonraki testler bu dosyayı sabit referans olarak kullanır.
- Fixture'lar **elle düzenlenmez**. Değiştirmek için migration çıktısı yeniden alınır, diff gözle incelenir ve yeni snapshot commit edilir.

### 6.5 Golden snapshot dosyaları

- `test/golden/` altında tutulur.
- Kasıtlı görsel değişiklikten sonra `flutter test --update-goldens` komutu ile güncellenir.
- PR'a golden değişikliği eklendiğinde diff gözle incelenir; otomatik onay yoktur.

---

## 7. Deterministik Test Disiplini

Bu kurallar economy ve event test'lerinin tamamında geçerlidir. İstisna kabul edilmez.

| Kural | Açıklama |
|---|---|
| **Rastgelelik yasak** | Economy ve event testleri `Random()` doğrudan kullanmaz. RNG inject edilir; seed sabittir. |
| **Saat inject edilir** | Zaman bağımlı testler `Clock.fixed(...)` veya eşdeğerini inject eder. `DateTime.now()` test kodu içinde doğrudan çağrılmaz. |
| **Offline delta fixture tabanlı** | Known-good snapshot ile beklenen çıktı karşılaştırılır; değer hesabı testin içinde yapılmaz. |
| **Formül değişikliği testi kırar — kasıtlıdır** | Deterministik test'in kırılması regresyon değil, kasıtlı değişikliğin sinyalidir. Test güncellenir, eski değer silinmez — commit mesajında formül değişikliği belirtilir. |
| **Uç değerler zorunludur** | Sıfır, negatif, maksimum cap, tip sınırı değerleri her formül testi için zorunlu senaryo sayılır. |

---

## 8. TDD Ritmi

PRD §16.6 ve CLAUDE.md §9 ile hizalıdır.

| Durum | Akış |
|---|---|
| Yeni formül veya ekonomik davranış | Önce failing test yaz (red) → implementation yaz (green) → gerekiyorsa refactor → yeşil kalsın. |
| Bug fix | Hatayı yeniden üreten failing test yaz → fix → yeşillendir. Test regresyon guard olarak kalır, silinmez. |
| Manuel testle bulunan edge case | Otomatize edilebiliyorsa unit veya widget testine dönüştür. Otomatize edilemiyorsa §9 manuel planına senaryo olarak eklenir. |
| Deterministik formül testi kırıldı | Kasıtlı mı? → Testi güncelle ve commit mesajında belirt. Kazara mı? → Formülü geri al, kök nedeni bul. |

---

## 9. Manuel Test Planı

Aşağıdaki senaryolar otomatik testlerle kapsanamayan NFR'ler için tanımlanmıştır (PRD §12 NFR-1, NFR-3, NFR-5).

| ID | Senaryo | Adımlar | Beklenen | Platform | Cihaz profili |
|---|---|---|---|---|---|
| M-01 | 60 FPS — ana ekran | Uygulamayı başlat, 30 saniye boyunca hızlı tap yap, Xcode/Android Studio frame profiler ile kayıt al. | Ana ekranda frame drop yok; 60 FPS hedefi aşılmıyor (< 16,6 ms/frame). | iOS + Android | iPhone SE 3 (orta-segment); Pixel 6a |
| M-02 | Tap yanıt süresi | Ekrana tek tap bas, görsel geri bildirimi stopwatch ile ölç (Xcode Instruments / systrace). | Tap sonrası < 100 ms içinde görsel geri bildirim görünür. | iOS + Android | iPhone SE 3; Pixel 6a |
| M-03 | Titreşim kapalıyken bildirimler | Ayarlar → titreşimi kapat. Tüm event bildirimleri ve tap geri bildirimlerini tetikle. | Tüm bildirimler görsel olarak görünür; titreşim olmadan eksiksiz bilgi iletilir. | iOS + Android | Herhangi |
| M-04 | Büyük metin ölçeği | Sistem font ölçeğini maksimuma getir (iOS: Erişilebilirlik → Daha Büyük Metin). Tüm ekranları gez. | Hiçbir metin kesilmez, satır üst üste binmez; tüm bilgi okunabilir durumda kalır. | iOS + Android | Herhangi |
| M-05 | Renk körlüğü — event işaretleri | Protanopia simülasyonu aç (iOS: Erişilebilirlik → Görüntü Ayarları). Event ekranını aç. | Event marker'ları yalnızca renge değil; şekil veya ikon farkına da dayanır; renk körü oyuncu için bilgi kaybı olmaz. | iOS | Herhangi |
| M-06 | Offline ilerleme — uçak modu | Uygulamayı kapat, uçak modunu aç, 30 dakika bekle, uygulamayı aç. | Session recap modalı açılır; üretilen kaynak timestamp delta ile doğru hesaplanmış görünür; değer sıfır değil. | iOS + Android | Herhangi |
| M-07 | Offline ilerleme — 24 saat | Uygulamayı kapat, 24 saat bekle (veya cihaz saatini ileri al), uygulamayı aç. | Session recap doğru değerleri gösterir; offline cap uygulanmışsa görünür biçimde bilgi verilir. | iOS + Android | Herhangi |
| M-08 | Save corruption kurtarma | `crumbs_save.json` dosyasını bir hex editörle boz (tek byte değiştir). Uygulamayı başlat. | Uygulama çökmez; `.bak` dosyasından kurtarma başarılı — `docs/save-format.md §4.1` akışı izlenir; kullanıcıya kurtarma uyarısı görünür. | iOS + Android | Herhangi |
| M-09 | Onboarding unlock temposu (PRD §1 ilke 2) | Yeni kurulum; tutorial'ı tamamla, 5 dk serbest oyna; elde edilen satın alma + unlock sayısını say. | Oyuncu ≥2 bina satın almış ve ≥1 upgrade görmüş; toplam ≥10 anlamlı unlock/satın alma hissi (ekonomi kalibrasyonuna bağlı — kaçırılırsa balans task'ı açılır). | iOS + Android | iPhone SE 3; Pixel 6a |

---

## 10. CI ve Local Çalıştırma

```bash
# Tüm unit + widget testler
flutter test

# Belirli bir modül
flutter test test/core/economy/

# Coverage raporu (genhtml için `lcov` paketi gerekli: macOS → `brew install lcov`)
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration testler (bağlı cihaz gerekli)
flutter test integration_test/

# Golden snapshot güncelleme (kasıtlı değişiklik sonrası)
flutter test --update-goldens

# Statik analiz
flutter analyze
```

### 10.1 CI pipeline kuralları

| Aşama | Tetikleyici | Zorunlu mu? | Geçmezse |
|---|---|---|---|
| `flutter analyze` | Her PR | Evet | PR merge edilemez |
| Unit + Widget testler | Her PR | Evet | PR merge edilemez |
| Golden snapshot testler | Her PR | Evet | PR merge edilemez |
| Coverage gate | Her PR | Evet | PR merge edilemez — §5 hedefleri altında kalırsa red |
| Integration testler | Gecelik scheduled | Hayır (PR'da opsiyonel) | Gece bildirimi; sabah düzeltilir |

> CI platformu TBD — scaffold PR merge edildiğinde bu satır ve `CLAUDE.md §3` birlikte güncellenir. Her aşama yukarıdaki kuralları zorunlu tutar.

---

## 11. Bu Doküman Ne Değildir

| Konu | Nerede bulunur |
|---|---|
| Ürün gereksinimleri ve kabul kriterleri | `cookie_clicker_derivative_prd.md` (tek gerçek kaynak) |
| Economy formüllerinin matematiksel tanımı | `docs/economy.md` |
| UX akışları ve ekran geçişleri | `docs/ux-flows.md` |
| Telemetri event'lerinin doğrulanması | `docs/telemetry.md` |
| Save migration adımları ve şema | `docs/save-format.md` |
| Kodlama stil rehberi | Gelecekte `CONTRIBUTING.md` |
| Performans profili sonuç raporu | Ayrı runbook |
| Release kriteri / QA sign-off checklist | Gelecekte `docs/release-checklist.md` |
