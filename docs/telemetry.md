# Telemetri — Analitik Event Kataloğu ve Ölçüm Spesifikasyonu

**Proje:** Project Crumbs
**Kapsam:** MVP analitik event kataloğu
**Kaynak:** PRD §12 NFR-4, §15, §13
**Güncelleme:** 2026-04-16

> Bu doküman CLAUDE.md §4 ve PRD §12'nin operasyonel detayıdır. Çelişki varsa PRD kazanır.
> Dashboard sorguları, dbt/SQL ve marketing attribution kurulum rehberi bu dokümana dahil değildir.
> Dart kaynak kodu ayrı bir task'ta üretilir — bu dokümanda kod yoktur.

---

## 1. Doküman Amacı ve Kapsam

### 1.1 Bu doküman nedir

Bu doküman, MVP sürümünde hangi analitik event'lerinin toplanacağını, bu event'lerin hangi başarı ve sorun metriklerini beslediğini, ortak alan şemasını ve PII/consent sınırlarını tanımlar.

SDK tercihi: `firebase_analytics` (PRD + CLAUDE.md §2). Bu doküman mümkün olan yerde **SDK-tarafsız** tutulmuştur; event isimleri ve property şemaları Firebase'e bağımlı değildir.

### 1.2 MVP'de ölçülen

- Tutorial tamamlanma oranı
- D1 / D7 retention
- İlk prestige zamanı
- Ortalama seans süresi
- Reklam opt-in oranı
- Feature unlock funnel'ı
- Session recap görüntüleme ve aksiyona dönüşüm

### 1.3 MVP'de ölçülmeyen

| Konu                              | Neden dışarıda              |
|-----------------------------------|-----------------------------|
| A/B test metrikleri               | MVP dışı — PRD §13          |
| Cohort derinlemesine segmentasyon | Dashboard katmanı (ayrı repo)|
| Qualitative / user research       | Bu dokümanın kapsamı değil  |
| Marketing attribution kurulumu    | Ayrı runbook                |
| PvP / leaderboard event'leri      | Post-MVP — PRD §14          |
| Cloud save senkronizasyon olayları| Post-MVP — PRD §14          |

---

## 2. Tasarım İlkeleri

| İlke                  | Kural                                                                                                     |
|-----------------------|-----------------------------------------------------------------------------------------------------------|
| **Sıfır PII**         | Ad, e-posta, telefon, hassas konum, ham cihaz seri numarası toplanmaz. Ayrıntı §7'de.                   |
| **Offline-friendly**  | Event'ler yerel kuyrukta birikir; bağlantı dönünce toplu gönderilir. Ayrıntı §8'de.                     |
| **İsimlendirme**      | `event_name` ve tüm property'ler `snake_case`. Her event `schema_version` alanı taşır.                  |
| **Versiyonlama**      | Event adı değişmez — yeni event eklenir, eski `deprecated` olarak işaretlenir, 2 sürüm sonra kaldırılır. |
| **Ad ID'leri opt-in** | IDFA (iOS) / GAID (Android) yalnızca kullanıcı rızasıyla toplanır; rıza yoksa alan boş bırakılır.       |

---

## 3. Ortak Alan Şeması

Her event aşağıdaki alanları zorunlu olarak taşır.

| Alan                  | Tip              | Açıklama                                                              |
|-----------------------|------------------|-----------------------------------------------------------------------|
| `schema_version`      | `int`            | Bu event şemasının versiyonu. İlk sürüm: `1`.                        |
| `client_timestamp_ms` | `int`            | UTC epoch milisaniye. Cihaz saati drift'ine karşı server-side normalize edilir. |
| `session_id`          | `string` (UUID v4)| Her `session_start` event'inde üretilir; session kapanana dek sabit. |
| `app_version`         | `string`         | Semver (ör. `"1.0.0"`).                                              |
| `platform`            | `"ios"` \| `"android"` | Çalışma zamanı platformu.                                      |
| `install_id`          | `string`         | SDK tarafından üretilen anonim kurulum kimliği. Ham cihaz ID değil.  |
| `locale`              | `string`         | BCP 47 locale kodu (ör. `"tr-TR"`, `"en-US"`).                      |

---

## 4. MVP Event Kataloğu

Tablolar PRD §12 NFR-4 ve §15 metriklerini tam karşılayacak biçimde tasarlanmıştır.

### 4.1 Kurulum ve Seans Event'leri

| `event_name`        | Trigger                                           | Properties (ad · tip · açıklama)                                                                            | Hangi metriği besler                     |
|---------------------|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------|------------------------------------------|
| `app_install`       | Uygulamanın ilk kez başlatılması                  | — (sadece ortak alanlar)                                                                                    | D1/D7 retention payda, prestige conversion payda |
| `session_start`     | Uygulama ön plana her geldiğinde                  | `is_first_session` · bool · İlk session mı<br>`install_id_age_ms` · int · Kurulum zamanından geçen süre    | D1/D7 retention, avg session length     |
| `session_end`       | Uygulama arka plana geçtiğinde (15 dk timeout)    | `duration_ms` · int · Session süresi ms<br>`is_first_session` · bool<br>`resource_earned` · int · Session'da kazanılan ana kaynak | Avg session length, first session length |

#### D1 / D7 Retention Tanımı

- **D1:** `app_install` tarihinden 1 gün sonra (±2 saat pencere) en az bir `session_start` gelen kullanıcı oranı.
- **D7:** Aynı mantık, 7. gün için.
- `install_id` ve `client_timestamp_ms` birlikte kullanılarak backend'de cohort'a göre hesaplanır. Client bu hesabı yapmaz; raw event'leri gönderir.

---

### 4.2 Tutorial Event'leri

| `event_name`            | Trigger                                              | Properties                                                                                              | Hangi metriği besler          |
|-------------------------|------------------------------------------------------|---------------------------------------------------------------------------------------------------------|-------------------------------|
| `tutorial_started`      | Tutorial ilk adımı gösterildiğinde                   | `step_index` · int · `0`                                                                                | Tutorial complete rate payda  |
| `tutorial_step_complete`| Kullanıcı her tutorial adımını tamamladığında        | `step_index` · int · Tamamlanan adım (0-bazlı)<br>`step_name` · string · Adım tanımlayıcısı<br>`time_on_step_ms` · int · Bu adımda harcanan süre (adım gösteriminden tamamlanmasına kadar) | —                             |
| `tutorial_complete`     | Son tutorial adımı tamamlandığında                   | `total_duration_ms` · int · Tutorial başından beri geçen süre<br>`steps_completed` · int               | Tutorial complete rate payı (pay) |
| `tutorial_skipped`      | Kullanıcı tutorial'ı atlayan bir yol seçerse         | `at_step_index` · int                                                                                   | Abandon analizi               |

---

### 4.3 Feature Unlock Funnel Event'leri

| `event_name`               | Trigger                                                    | Properties                                                                                                          | Hangi metriği besler             |
|----------------------------|------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|----------------------------------|
| `first_shop_open`          | Shop ekranı ilk kez açıldığında                            | `time_since_install_ms` · int                                                                                       | Feature unlock funnel            |
| `first_upgrade_purchased`  | İlk upgrade satın alındığında                              | `upgrade_id` · string<br>`time_since_install_ms` · int                                                             | Feature unlock funnel            |
| `first_research_started`   | Research Lab'da ilk araştırma başlatıldığında              | `node_id` · string<br>`time_since_install_ms` · int                                                                | Feature unlock funnel, problem metriği |
| `feature_unlocked`         | Herhangi bir feature/sistem ilk kez açıldığında            | `unlock_id` · string · Unlock tanımlayıcısı<br>`unlock_category` · string · `"building"` / `"system"` / `"research"` / `"prestige"`<br>`time_since_install_ms` · int | Feature unlock funnel            |

---

### 4.4 Prestige Event'leri

| `event_name`     | Trigger                            | Properties                                                                                                                                   | Hangi metriği besler                     |
|------------------|------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| `first_prestige` | Oyuncunun ilk prestige yaptığı an  | `time_since_install_ms` · int · Kurulumdan prestige'e kadar geçen süre<br>`prestige_currency_earned` · int<br>`buildings_owned_at_reset` · int<br>`run_number` · int · Her zaman `1` | First prestige time, prestige conversion |
| `prestige`       | Her prestige reset'inde            | `prestige_number` · int · Kaçıncı prestige<br>`time_since_last_prestige_ms` · int<br>`prestige_currency_earned` · int                   | Prestige rhythm (post-MVP analizi)       |

---

### 4.5 Shop ve Abandon Event'leri

| `event_name`    | Trigger                             | Properties                                                                                                         | Hangi metriği besler   |
|-----------------|-------------------------------------|--------------------------------------------------------------------------------------------------------------------|------------------------|
| `shop_opened`   | Shop ekranı her açıldığında         | `time_since_install_ms` · int<br>`source` · string · `"tab_bar"` / `"suggestion_card"` / `"other"`               | Shop abandon analizi   |
| `shop_closed`   | Shop ekranından çıkıldığında        | `items_purchased_in_session` · int · Bu açılışta yapılan satın alma sayısı<br>`time_spent_ms` · int               | Shop abandon analizi   |

---

### 4.6 Reklam ve Consent Event'leri

| `event_name`              | Trigger                                                        | Properties                                                              | Hangi metriği besler          |
|---------------------------|----------------------------------------------------------------|-------------------------------------------------------------------------|-------------------------------|
| `ad_consent_prompt_shown` | Reklam izin diyaloğu kullanıcıya gösterildiğinde              | `prompt_context` · string · Hangi ekranda gösterildi                   | Ad opt-in rate payda          |
| `ad_consent_granted`      | Kullanıcı reklam iznini onayladığında                          | `prompt_context` · string                                               | Ad opt-in rate pay            |
| `ad_consent_denied`       | Kullanıcı reklam iznini reddettiğinde                          | `prompt_context` · string                                               | Ad opt-in rate analizi        |
| `rewarded_ad_viewed`      | Ödüllü reklam başlatıldığında (izleme başladı)                 | `ad_unit_id` · string · Anonim placement ID<br>`trigger_context` · string · Nereden tetiklendi | Ad opt-in rate, ad engagement |
| `rewarded_ad_completed`   | Ödüllü reklam eksiksiz izlendiğinde                            | `ad_unit_id` · string<br>`reward_type` · string · Verilen buff tipi<br>`reward_value` · int | Ad engagement                 |

---

### 4.7 Session Recap Event'leri

| `event_name`                  | Trigger                                                       | Properties                                                                                   | Hangi metriği besler                        |
|-------------------------------|---------------------------------------------------------------|----------------------------------------------------------------------------------------------|---------------------------------------------|
| `session_recap_shown`         | Session recap modalı kullanıcıya gösterildiğinde             | `offline_duration_ms` · int<br>`resource_earned_offline` · int                               | Session recap view-to-action rate payda     |
| `session_recap_action_taken`  | Kullanıcı recap üzerinde bir aksiyon seçtiğinde ("Topla" dahil) | `action_type` · string · `"collect"` / `"buy_building"` / `"buy_upgrade"` / `"open_shop"` / `"other"` | Session recap view-to-action rate pay       |
| `session_recap_dismissed`     | Kullanıcı recap'i aksiyon almadan kapattığında                | —                                                                                            | Abandon analizi                             |

---

## 5. Başarı Metrik Tanımları

PRD §15 hedefleri aşağıdaki event'lerle ölçülür. Hedef değerleri değiştirilmez — kaynak PRD §15'tir.

| Metrik                      | Hedef (PRD §15) | Formül                                                                                       | Kaynak event(ler)                                  |
|-----------------------------|-----------------|----------------------------------------------------------------------------------------------|----------------------------------------------------|
| Tutorial complete rate      | > %80           | `count(tutorial_complete) / count(tutorial_started)`                                         | `tutorial_started`, `tutorial_complete`            |
| First session length        | 8–15 dk         | `median(session_end.duration_ms where is_first_session = true)`                              | `session_end`                                      |
| D1 retention                | %35+            | `count(distinct install_id where session_start on day+1) / count(app_install on day0)` — ±2 saat cohort penceresi | `session_start`, `app_install`                     |
| D7 retention                | Trend metriği¹  | `count(distinct install_id where session_start on day+7) / count(app_install on day0)`       | `session_start`, `app_install`                     |
| First prestige conversion   | > %45           | `count(first_prestige) / count(app_install)`                                                 | `first_prestige`, `app_install`                    |
| Rewarded ad opt-in          | > %20           | `count(ad_consent_granted) / count(ad_consent_prompt_shown)`                                 | `ad_consent_prompt_shown`, `ad_consent_granted`    |
| Session recap view-to-action| > %50           | `count(session_recap_action_taken) / count(session_recap_shown)`                             | `session_recap_shown`, `session_recap_action_taken`|

¹ PRD §15 D7 için sabit hedef vermemiştir; D1 ile birlikte trend metriği olarak izlenir.

---

## 6. Sorun Metrik Tanımları

PRD §15 "İzlenecek sorun metrikleri" aşağıdaki event kombinasyonlarıyla türetilir.

| Sorun metriği                         | Türetme yöntemi                                                                                                              | İlgili event'ler                                     |
|---------------------------------------|------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------|
| 10. dakikadan önce churn              | `app_install` sonrası `session_end` event'lerinin toplamı < 10 dk olan kullanıcı oranı. Threshold: yükleme gününde hiçbir session ≥ 10 dk değil. | `app_install`, `session_end` (`duration_ms`)         |
| Research unlock'a ulaşamayan          | `first_research_started` event'i **hiç göndermeyen** kullanıcı oranı (7 gün threshold).                                     | `app_install`, `first_research_started`              |
| İlk prestige'i hiç görmeyen           | `first_prestige` event'i **hiç göndermeyen** kullanıcı oranı (7 gün threshold).                                             | `app_install`, `first_prestige`                      |
| Shop ekranında yüksek abandon         | `shop_closed` event'lerinde `items_purchased_in_session = 0` olan oran. `shop_opened` ile pivot.                            | `shop_opened`, `shop_closed`                         |

> **Not:** Churn risk flag event'i kullanılmaz. Yukarıdaki metrikler ham funnel event'lerden türetilir; client-side sınıflandırma yapılmaz.

---

## 7. PII ve Consent Sınırları

### 7.1 Asla toplanmaz

- Ad, e-posta adresi, telefon numarası
- Kullanıcı tarafından girilen herhangi bir metin
- Hassas veya kesin konum (GPS koordinatı)
- IDFA / GAID (kullanıcı opt-in vermemişse)
- Ham cihaz seri numarası veya IMEI
- IP adresi (SDK'ya ham olarak gönderilmez; Firebase server-side işler)

### 7.2 Toplanır (anonim)

| Alan            | Değer örneği          | Gerekçe                                              |
|-----------------|-----------------------|------------------------------------------------------|
| `install_id`    | SDK üretimi UUID      | Session eşleştirme; cihaz kimliği değil             |
| `platform`      | `"ios"` / `"android"`| Platforma göre hata ayıklama                        |
| `locale`        | `"tr-TR"`             | Yerelleştirme kararları                             |
| `app_version`   | `"1.0.0"`             | Versiyon bazlı hata analizi                         |
| Cihaz modeli¹   | `"iPhone 15 / Pixel 8"`| Performans profili — marka + model, seri numarası yok |

¹ Cihaz modeli Firebase SDK tarafından otomatik olarak ortak alan dışında doldurulur; §3'teki manuel payload'a eklemeye gerek yoktur.

### 7.3 Opt-in ile toplanır

| Alan            | Kullanım amacı                        | Koşul                                          |
|-----------------|---------------------------------------|------------------------------------------------|
| IDFA (iOS)      | Reklam attribution                    | App Tracking Transparency (ATT) onayı zorunlu  |
| GAID (Android)  | Reklam attribution                    | Kullanıcı reklam kişiselleştirmesini kabul etmeli |

### 7.4 iOS ATT akışı

- ATT prompt, reklam içerikli herhangi bir event gönderilmeden **önce** gösterilir.
- Onay yoksa reklam SDK'sına hiçbir ID iletilmez; `ad_unit_id` alanı `"anonymous"` placeholder taşır.
- ATT durumu `ad_consent_granted` / `ad_consent_denied` event'leriyle `prompt_context = "att"` property'si ile kaydedilir. Uygulama içi reklam consent dialog'u aynı event'leri `prompt_context = "in_app_dialog"` ile kullanır; dashboard bu property ile ATT ve in-app consent'i ayırır.

---

## 8. Event Queue ve Offline Davranışı

| Parametre                  | Değer / Kural                                                                                 |
|----------------------------|-----------------------------------------------------------------------------------------------|
| Queue deposu               | SDK varsayılan yerel depolama (Firebase: SQLite tabanlı). Alternatif: `flutter_secure_storage`. |
| Maksimum queue kapasitesi  | 500 event (MVP). Dolunca **FIFO drop** — en eski event atılır.                               |
| Flush tetikleyicisi        | Network bağlantısı döndüğünde otomatik; ayrıca `session_end`'de force-flush.                 |
| Batch boyutu               | SDK varsayılanı (Firebase: 20 event/batch, 1 saatte bir veya bağlantıda).                    |
| Session tanımı             | `session_start` → `session_end` arası. 15 dakika arka planda kalınırsa yeni session açılır.  |
| Session ID geçerliliği     | Tüm event'ler aynı `session_id`'yi taşır; yeni session = yeni UUID v4.                       |

---

## 9. Dokümantasyon Disiplini

### 9.1 Yeni event eklerken

1. §4'teki ilgili alt tabloya satır ekle.
2. Formül değişiyorsa §5 veya §6'yı güncelle.
3. Yeni alan **mevcut şemayı kıran** bir değişiklikse `schema_version` artır.
4. Eski app sürümleri yeni event'i göndermez — dashboard sorguları `schema_version` filtresiyle buna dayanıklı yazılmalıdır (not: dashboard sorguları bu dokümanda değildir).

### 9.2 Event adı değişikliği politikası

| Adım | Kural                                                                                     |
|------|-------------------------------------------------------------------------------------------|
| 1    | Mevcut event adı **değiştirilemez**.                                                      |
| 2    | Yeni event adı eklenir; §4'e "replaces: `eski_event_name`" notu eklenir.                 |
| 3    | Eski event `deprecated` olarak işaretlenir (tabloya `[DEPRECATED vX.X]` etiketi).        |
| 4    | Eski event 2 uygulama sürümü sonra tablodan kaldırılır.                                   |

### 9.3 Migration senaryosu

Eski sürümler yeni event'leri göndermez; bu beklenen bir durumdur. Dashboard katmanı:
- `app_version` filtresiyle koherent pencere oluşturur.
- Eksik event'i hata değil, veri boşluğu olarak işler.
- `schema_version` değişimini event-level granülarıyla takip eder.

---

## 10. Bu Doküman Ne Değildir

| Konu                                          | Nerede bulunur                                 |
|-----------------------------------------------|------------------------------------------------|
| PRD §15 başarı metrikleri ve hedef listesi    | `cookie_clicker_derivative_prd.md` §15         |
| Marketing attribution SDK kurulum rehberi     | Ayrı runbook (hazırlanıyor)                    |
| Dashboard sorguları / dbt / SQL               | Ayrı repo                                      |
| Qualitative / user research telemetrisi       | Bu dokümanın kapsamı dışında                   |
| Dart kaynak kodu (event dispatch, queue impl.)| `lib/core/` (ayrı task)                        |
| UX akışları (consent prompt tasarımı)         | `docs/ux-flows.md`              |
| Ekonomi formülleri                            | `docs/economy.md`               |
| Test senaryoları (event doğrulama)            | `docs/test-plan.md`             |

---

## Events (Sprint B2 — stub pipeline)

All events emitted via `TelemetryLogger` interface. Default binding: `DebugLogger` (`debugPrint('[TELEMETRY] {name} {payload}')`). Firebase Analytics provider swap deferred to Sprint B3 (single-file replace at `telemetry_providers.dart`).

### app_install
Fired once on first cold launch (`firstLaunchMarked` was `false` before this session).

| Field | Type | Description |
|---|---|---|
| install_id | String | UUID from `GameState.meta.installId` (Sprint A) |
| platform | String | `ios` or `android` (from `Platform.operatingSystem`) |

### session_start
Fired on every cold launch AND every `onResume` lifecycle event.

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null — `<not-loaded>` sentinel if provider unresolved (invariant I1 — integration test fails on this value in production) |
| session_id | String | UUID v4, unique per session |

### session_end
Fired on `onPause` / `onDetach`, AFTER `persistNow` completes (ordering invariant I6).

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule as session_start |
| session_id | String | Paired with corresponding session_start |
| duration_ms | int | Milliseconds since matching session_start |

### tutorial_started
Fired once when `TutorialScaffold` postFrame callback triggers `TutorialNotifier.start()` and transitions to `tapCupcake`. No-op on subsequent launches (guarded by `firstLaunchMarked` pref).

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule |

### tutorial_completed
Fired when user completes Step 3 (`InfoCardOverlay` "Anladım" CTA) OR taps Skip (`CoachMarkOverlay` "Geç" — Step 1 only).

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule |
| skipped | bool | `true` if user pressed Skip |
| duration_ms | int | Time from `tutorial_started` to completion. **Note:** `0` when widget mid-tutorial remount occurs — downstream analytics may filter these edge cases |

### Invariants
- **[I1]** `install_id` never null in payload; sentinel `<not-loaded>` reserved for unresolved provider state (integration test rejects this value in production emission)
- **[I6]** `onPause` ordering: `persistNow` ÖNCE, `SessionEnd` SONRA (process-kill during pause guarantees disk save; telemetry loss acceptable)
