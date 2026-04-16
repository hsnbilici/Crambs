# Upgrade Kataloğu — MVP Tam Listesi

**Proje:** Project Crumbs
**Versiyon:** 0.1 | **Tarih:** 2026-04-16
**Kapsam:** MVP'nin 36 upgrade'inin tam kataloğu — kimlik, etki, maliyet, ön koşul ve kategori
**Kaynak:** PRD §6.3, §8.5, §8.6, §9.1, §13; `economy.md §6`, §4, §A.3, §11; `research-tree.md`; `ux-flows.md §5.3`; `telemetry.md §4.3`
**Güncelleme:** 2026-04-16

> Bu doküman PRD §6.3'ün uygulanabilir genişlemesidir. Çelişki varsa PRD kazanır.
> Etki değerleri ilk-cut; `economy.md §11` balans parametreleriyle uyumlu; playtest sonrası ayarlanır.
> Dart kaynak kodu bu dokümana dahil değildir — bkz. `lib/core/progression/`.

---

## 1. Doküman Amacı

Bu doküman Project Crumbs MVP'sinin Upgrades ekranında yer alan **tam 36 upgrade'i** tanımlar: her upgrade'in kimliği, insan-okunabilir adı, etki tipi, somut etki değeri, R1 maliyeti, ön koşulu ve kategori filtre etiketini.

**Bu doküman şunlar değildir:**

- Synergy unlock listesi değil — synergy unlock'lar ücretsiz, otomatik ve `economy.md §A.3`'te tanımlıdır.
- Research node listesi değil — research node'ları R2 ile satın alınır, Research Lab'da yer alır; `research-tree.md`'de tanımlıdır.
- Achievement kataloğu değil — ayrı task.
- Upgrade ikon / görsel spesifikasyonu değil.
- Dart kodu değil.

---

## 2. Tasarım İlkeleri

1. **Çarpan katman bütünlüğü.** Her upgrade `economy.md §6`'daki yedi çarpan katmanından birini besler; katmanın dışına çıkamaz. Upgrade etkisi `UpgradeState.effectType` ve `effectValue` alanlarına doğrudan yazılır.

2. **Altı etki tipinin tamamı kapsanır.** PRD §6.3'te listelenen `global_multiplier`, `building_specific_multiplier`, `tap_power`, `crit_chance / combo`, `offline_bonus`, `event_spawn_modifier` tiplerinden her biri en az 3 upgrade ile temsil edilir.

3. **Onboarding sonrası hızlı erişim.** İlk upgrade ilk 5 dakika içinde görünür olmalıdır (PRD §9.1, FR-7). İlk 5-7 upgrade ön koşulsuz tasarlanmıştır; bu upgrade'ler kısa oturum açısından da mantıklı karar noktaları sunar.

4. **Karar üretme zorunluluğu.** Aynı etki tipinde rekabet eden seçenekler kasıtlıdır. Oyuncu her zaman "önce hangisi?" sorusuyla karşılaşır — bu soru oynanış süresiyle doğru orantılı biçimde derinleşir.

5. **Döngüsüz prerequisite ağacı.** Tüm bağımlılık ilişkileri ileri yönlü kenarlardan oluşur. Hiçbir upgrade kendi öncülüne geri bağlanmaz.

6. **Prestige'de sıfırlanır.** Upgrade satın alımı `RunState`'e aittir; prestige reset'inde `UpgradeState.purchased = false` olur (`economy.md §9.3`).

---

## 3. Etki Tipi Dağılımı

| Etki Tipi | Kategori Filtre Etiketi | `economy.md §6` Katmanı | Hedef Upgrade Sayısı |
|---|---|---|---|
| Global multiplier | `global` | `global_multiplier` | 6 |
| Bina-bazlı multiplier | `building` | `building_specific_multiplier` | 8 |
| Tap power | `tap` | tap_income chain | 6 |
| Crit chance / combo modifier | `crit` | `crit_chance` + combo | 6 |
| Offline bonus | `offline` | `offline_bonus` | 5 |
| Event spawn modifier | `event` | `event_spawn_rate_modifier` | 5 |

**Toplam: 36**

`ux-flows.md §5.3`'teki kategori filtresi bu altı etiketi kullanır. Satın alınan upgrade'ler görünür-kilitli duruma geçer; filtreleme sıfırlanmadan çalışır.

---

## 4. Upgrade Kataloğu

Maliyet eğrisi kuralı:
- Tier I: 100–500 R1 bandında başlar; ön koşulsuz.
- Tier II: Tier I'in ~×10 katı maliyet; Tier I ön koşul.
- Tier III: Tier II'nin ~×10 katı; Tier II ön koşul.
- Bina-bazlı upgrade'ler bina unlock sırası ve owned eşiğiyle ölçeklenir.
- Son tier upgrade'leri (×10^3–×10^4 bandı) ilk prestige öncesinde erişilemez — aspiration hedefi.

Ön koşul sütununda `—` = ön koşulsuz; `bina_owned ≥ N` = o bina N adede ulaşmış olmalı; `upgrade_id` = o upgrade satın alınmış olmalı.

---

### 4.1 Global Multiplier Upgrade'leri (6 adet)

Tüm binaların pasif üretimini etkileyen katmana beslenir (`global_multiplier`). Çarpımsal yığılır.

| # | `id` | Ad | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|-----|------------|--------------|----------|----------|
| 1 | `golden_recipe_i` | Altın Tarif I | global_multiplier ×1.5 | 200 | — | `global` |
| 2 | `golden_recipe_ii` | Altın Tarif II | global_multiplier ×2.0 | 2,500 | `golden_recipe_i` | `global` |
| 3 | `golden_recipe_iii` | Altın Tarif III | global_multiplier ×2.5 | 40,000 | `golden_recipe_ii` | `global` |
| 4 | `secret_blend_i` | Gizli Harmanlama I | global_multiplier ×1.3 | 500 | — | `global` |
| 5 | `secret_blend_ii` | Gizli Harmanlama II | global_multiplier ×1.8 | 6,000 | `secret_blend_i` | `global` |
| 6 | `imperial_formula` | İmparatorluk Formülü | global_multiplier ×3.0 | 500,000 | `golden_recipe_iii` | `global` |

**Tasarım notu:** `golden_recipe` ve `secret_blend` zincirleri erken oyunda rakip yatırım seçeneği oluşturur. Oyuncu önce hangisini alacağını seçmek zorundadır; toplam maliyet eşdeğer ama çarpan zamanlaması farklıdır. `imperial_formula` tek büyük geç-oyun global upgrade'dir; ilk prestige öncesinde çoğu oyuncunun erişemeyeceği bir aspirasyon noktası.

---

### 4.2 Bina-Bazlı Multiplier Upgrade'leri (8 adet)

`building_specific_multiplier` katmanına beslenir; synergy unlock'larla çarpımsal yığılır (`economy.md §A.3`). Portal Kitchen upgrade kapsam dışındadır (endgame, MVP'de upgrade'siz tutuldu).

| # | `id` | Ad | Hedef Bina | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|----|-----------|------------|--------------|----------|----------|
| 7 | `crumb_mastery_i` | Ekmek Kırığı Ustalığı I | Crumb Collector | bina_multiplier ×2.0 | 150 | crumb_collector_owned ≥ 5 | `building` |
| 8 | `crumb_mastery_ii` | Ekmek Kırığı Ustalığı II | Crumb Collector | bina_multiplier ×3.0 | 3,000 | `crumb_mastery_i` | `building` |
| 9 | `artisan_oven` | Zanaatkar Fırın | Oven | bina_multiplier ×2.5 | 800 | oven_owned ≥ 5 | `building` |
| 10 | `conveyor_sync` | Bant Senkronizasyonu | Bakery Line | bina_multiplier ×2.0 | 8,000 | bakery_line_owned ≥ 5 | `building` |
| 11 | `express_route` | Ekspres Hat | Delivery Van | bina_multiplier ×2.0 | 50,000 | delivery_van_owned ≥ 5 | `building` |
| 12 | `franchise_blueprint` | Franchise Şablonu | Franchise Booth | bina_multiplier ×2.5 | 400,000 | franchise_booth_owned ≥ 5 | `building` |
| 13 | `precision_floor` | Hassas Döşeme | Factory Floor | bina_multiplier ×2.0 | 5,000,000 | factory_floor_owned ≥ 5 | `building` |
| 14 | `swarm_protocol` | Sürü Protokolü | Drone Fleet | bina_multiplier ×3.0 | 60,000,000 | drone_fleet_owned ≥ 5 | `building` |

**Tasarım notu:** Her bina için `owned ≥ 5` ön koşulu, oyuncunun o binaya gerçekten yatırım yapmış olmasını garantiler. Bu hem maliyet eğrisinin tutarlı kalmasını sağlar hem de erken açılmayı engeller. Portal Kitchen intentionally upgrade'siz — galaktik dönem aspirasyon ekonomisi prestige loop'una bırakılır. 7 bina kapsanmış, tablo tam.

---

### 4.3 Tap Power Upgrade'leri (6 adet)

`tap_income` zincirine beslenir; `tapPower` değerini artırır (`economy.md §7.1`). Combo ve crit upgradeleriyle ayrışmış tutulmak için bu tip yalnızca `tapPower` temel değerini etkiler.

| # | `id` | Ad | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|----|------------|--------------|----------|----------|
| 15 | `rolling_pin_i` | Oklava Ustalığı I | tapPower +5 | 100 | — | `tap` |
| 16 | `rolling_pin_ii` | Oklava Ustalığı II | tapPower +15 | 1,200 | `rolling_pin_i` | `tap` |
| 17 | `rolling_pin_iii` | Oklava Ustalığı III | tapPower +50 | 18,000 | `rolling_pin_ii` | `tap` |
| 18 | `butter_formula_i` | Tereyağı Formülü I | tapPower +8 | 300 | — | `tap` |
| 19 | `butter_formula_ii` | Tereyağı Formülü II | tapPower +25 | 3,500 | `butter_formula_i` | `tap` |
| 20 | `galactic_knead` | Galaktik Hamur İşi | tapPower +200 | 250,000 | `rolling_pin_iii` | `tap` |

**Tasarım notu:** `rolling_pin` ve `butter_formula` paralel zincirler olarak erken oyunda iki ayrı tap yatırım yolu sunar. `galactic_knead` geç oyun tap power zirve noktasıdır; tema açısından galaktik dönemi yansıtır. tapPower toplamalı artış modeliyle çalışır (`economy.md §7.1`'deki formülle uyumlu).

---

### 4.4 Crit Chance / Combo Modifier Upgrade'leri (6 adet)

`crit_chance` ve combo parametrelerine beslenir (`economy.md §7.2`, `§7.3`). Crit multiplier değiştirilmez — `economy.md §11`'de sabit; yalnızca olasılık ve combo eşiği etkilenir.

| # | `id` | Ad | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|----|------------|--------------|----------|----------|
| 21 | `golden_touch_i` | Altın Dokunuş I | critChance +%3 | 250 | — | `crit` |
| 22 | `golden_touch_ii` | Altın Dokunuş II | critChance +%5 | 3,000 | `golden_touch_i` | `crit` |
| 23 | `golden_touch_iii` | Altın Dokunuş III | critChance +%8 | 45,000 | `golden_touch_ii` | `crit` |
| 24 | `sugar_rush_i` | Şeker Patlaması I | comboMultiplier ×2.5 (base ×2 → ×2.5) | 400 | — | `crit` |
| 25 | `sugar_rush_ii` | Şeker Patlaması II | comboMultiplier ×2.5 → ×3.0 (`sugar_rush_i`'i değiştirir, stack değil) | 5,000 | `sugar_rush_i` | `crit` |
| 26 | `sweet_spot` | Tatlı Nokta | combo_tap_threshold -3 (10 → 7 tap/pencere) | 1,500 | `sugar_rush_i` | `crit` |

**Tasarım notu:** `golden_touch` zincirleri crit olasılığını kümülatif artırır; `economy.md §11`'deki `crit_chance_base = %1` başlangıcından başlayarak tier III sonrası toplam %17'ye ulaşır. `sweet_spot` combo eşiğini düşürür — aktif oynayan oyuncuya combo tetiklemesini kolaylaştırır fakat comboMultiplier'ı değil eşiği etkiler; bozucu olmayan bir QoL-aktif hibrit.

---

### 4.5 Offline Bonus Upgrade'leri (5 adet)

`offline_bonus` çarpanına beslenir (`economy.md §8.1`, `§8.4`). `offline_bonus_base = 1.0` başlangıç değerini artırır; prestige node'larıyla kümülatif yığılır. `economy.md §8.4`'teki %60 aktif-pasif oranı sınırına tabidir.

| # | `id` | Ad | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|----|------------|--------------|----------|----------|
| 27 | `slow_bake_i` | Yavaş Pişirme I | offline_bonus +%10 | 350 | — | `offline` |
| 28 | `slow_bake_ii` | Yavaş Pişirme II | offline_bonus +%15 | 4,500 | `slow_bake_i` | `offline` |
| 29 | `overnight_proof` | Gece Fermantasyonu | offline_cap +2 saat (8 → 10 saat) | 2,000 | `slow_bake_i` | `offline` |
| 30 | `resting_dough` | Dinlenen Hamur | offline_bonus +%20 | 30,000 | `slow_bake_ii` | `offline` |
| 31 | `dream_bakery` | Rüya Fırını | offline_cap +4 saat (10 → 14 saat) | 150,000 | `overnight_proof` | `offline` |

**Tasarım notu:** Offline bonus hem `offline_bonus` çarpanını hem de `offline_cap` süresini artıran iki ayrı alt zincire ayrılır (`slow_bake` ve `overnight_proof → dream_bakery`). Bu ayrım oyuncuya "daha verimli pasif" mi "daha uzun pasif" mi sorusunu sorar — meaningful karar alanı. `dream_bakery` 14 saatlik cap ile gün-içi geri dönüşü pekiştiren bir retention ödülüdür.

---

### 4.6 Event Spawn Modifier Upgrade'leri (5 adet)

`event_spawn_rate_modifier` ve ilgili event parametrelerine beslenir (`economy.md §7.4`; PRD §10.1). Event'lerin tetiklenme sıklığını, süresini veya drop miktarını artırır.

| # | `id` | Ad | Etki Değeri | Maliyet (R1) | Ön Koşul | Kategori |
|---|------|----|------------|--------------|----------|----------|
| 32 | `golden_spark_lure_i` | Altın Kıvılcım Cazibesi I | Golden Spark spawn_rate +%20 | 450 | — | `event` |
| 33 | `golden_spark_lure_ii` | Altın Kıvılcım Cazibesi II | Golden Spark spawn_rate +%30 (kümülatif +%50) | 6,000 | `golden_spark_lure_i` | `event` |
| 34 | `rush_hour_extend` | Yoğun Saat Uzatma | Rush Hour süresi +10 sn (30 → 40 sn) | 1,800 | — | `event` |
| 35 | `crit_storm_prep` | Kriz Fırtınası Hazırlığı | Crit Storm süresi +5 sn (15 → 20 sn) | 900 | — | `event` |
| 36 | `event_amplifier` | Etkinlik Yükselticisi | tüm event spawn_rate +%10 | 80,000 | `golden_spark_lure_ii` | `event` |

**Tasarım notu:** Event modifier upgrade'leri üç farklı event'e (Golden Spark, Rush Hour, Crit Storm) bölünmüştür; oyuncu tercih ettiği aktif oynayış stiline göre yatırım yapar. `event_amplifier` geç erişimli genel bir spawn yoğunlaştırıcıdır — tüm event tiplerinden eşit yararlanan aktif oyuncu için aspirasyon upgrade'i.

---

## 5. Etki Değeri ve Maliyet Eğrisi

### 5.1 Tier Mantığı

| Tier | Global Mult. Örneği | Tap Power Örneği | Maliyet Bandı | Ön Koşul |
|------|--------------------|--------------------|---------------|----------|
| I | ×1.3–×1.5 | +5–+8 | 100–500 R1 | — (ön koşulsuz) |
| II | ×1.8–×2.5 | +15–+25 | 1,200–8,000 R1 | Tier I |
| III | ×2.5–×3.0 | +50–+200 | 18,000–500,000 R1 | Tier II |

Bina-bazlı upgrade'ler bina unlock sırasıyla ölçeklenir: Crumb Collector upgrade'i 150 R1, Drone Fleet upgrade'i 60,000,000 R1 — bu fark bina base cost eğrisini yansıtır.

### 5.2 PRD §8.5 ile Uyumluluk

Her upgrade maliyeti, o upgrade'e erişilebilir olduğu zamandaki beklenen oyuncu kaynağının %10-50'si bandındadır. Örnek kalibrasyonlar:

- `rolling_pin_i` (100 R1): İlk Crumb Collector alındıktan ~30 saniye sonra erişilebilir; oyuncunun o anda birikmiş kaynağıyla %10-30 bandında.
- `golden_recipe_iii` (40,000 R1): ~20-25. dakika; Oven ve Bakery Line'ı olan bir oyuncunun üretim hızına göre ~%20-40 bandı.
- `imperial_formula` (500,000 R1): ~45-55. dakika; ilk prestige eşiği yaklaşırken; %10-20 bandında.

Tüm değerler ilk-cut; `economy.md §12.3` kalibrasyon süreci playtest sonrası ince ayarı yönetir.

---

## 6. Prerequisite Grafiği

Oklarla bağımlılık yönü gösterilmiştir. İlk 5-7 upgrade ön koşulsuz (onboarding tetiklenebilir).

```
[ÖN KOŞULSUZ — İlk 5 dk içinde görünür]
  rolling_pin_i ──► rolling_pin_ii ──► rolling_pin_iii ──► galactic_knead
  butter_formula_i ──► butter_formula_ii
  golden_recipe_i ──► golden_recipe_ii ──► golden_recipe_iii ──► imperial_formula
  secret_blend_i ──► secret_blend_ii
  golden_touch_i ──► golden_touch_ii ──► golden_touch_iii
  sugar_rush_i ──► sugar_rush_ii
  sugar_rush_i ──► sweet_spot
  slow_bake_i ──► slow_bake_ii ──► resting_dough
  slow_bake_i ──► overnight_proof ──► dream_bakery
  golden_spark_lure_i ──► golden_spark_lure_ii ──► event_amplifier
  rush_hour_extend   [bağımsız — ön koşulsuz]
  crit_storm_prep    [bağımsız — ön koşulsuz]

[BINA EŞIĞI ÖN KOŞULLU — Bina N≥5 satın alındıktan sonra görünür]
  crumb_collector_owned≥5 ──► crumb_mastery_i ──► crumb_mastery_ii
  oven_owned≥5            ──► artisan_oven
  bakery_line_owned≥5     ──► conveyor_sync
  delivery_van_owned≥5    ──► express_route
  franchise_booth_owned≥5 ──► franchise_blueprint
  factory_floor_owned≥5   ──► precision_floor
  drone_fleet_owned≥5     ──► swarm_protocol
```

**Döngüsüz doğrulaması:**
- Her kenar `A → B` için `B`'nin `id`'si `A`'yı referans etmez.
- En uzun zincir derinliği: `golden_recipe_i → ii → iii → imperial_formula` (derinlik 4).
- Bina-bazlı upgrade'ler bina owned durumuna bağlı; döngü oluşturmak mümkün değil.
- `sugar_rush_i` hem `ii`'ye hem `sweet_spot`'a bağlıdır (branching, döngü değil).

**İlk 5 dk'da görünür olan ön koşulsuz upgrade'ler (8 adet):**
`rolling_pin_i`, `butter_formula_i`, `golden_recipe_i`, `secret_blend_i`, `golden_touch_i`, `sugar_rush_i`, `slow_bake_i`, `golden_spark_lure_i`

Bu sayı PRD §1 ilke 2 ("ilk 5 dakikada ≥10 anlamlı unlock") hedefiyle uyumludur; bina satın alımlarıyla birlikte 10+ eşiği karşılanır.

---

## 7. Unlock Zamanlaması

Her upgrade'in oyuncunun beklenen oturum zamanına göre erişim penceresi:

| Zaman Dilimi | Görünür Olan Upgrade'ler | Gerekçe |
|---|---|---|
| 0–5 dk | 8 ön koşulsuz upgrade | Onboarding biter bitmez anında karar alanı |
| 5–15 dk | İlk tier II upgrade'ler + bina eşiği upgrade'leri (Crumb/Oven) | Tier I'ler alındıkça Tier II'ler kilit açar |
| 15–30 dk | Tier III global/tap + orta bina upgrade'leri (Bakery Line, Delivery Van) | Ekonomi hızlanır; yatırım kararları ağırlaşır |
| 30–60 dk | `imperial_formula`, `galactic_knead`, `dream_bakery`, `event_amplifier` + geç bina upgrade'leri | Prestige eşiği yaklaşırken son büyük kararlar |
| 60–120 dk | `swarm_protocol`, `resting_dough`, `golden_touch_iii` | İkinci ve üçüncü prestige koşularında tamamlanır |

PRD §8.3 ilke 3: "Her 2-3 dakikada bir anlamlı karar." Yukarıdaki tabloda 36 upgrade ~120 dakikaya yayılmaktadır; yaklaşık her 3.3 dakikada bir yeni upgrade erişilebilir ya da mevcut Tier I maliyeti karşılanabilir duruma gelir.

---

## 8. Telemetri

### 8.1 MVP Zorunlu Event

İlk upgrade satın alımında `telemetry.md §4.3` ile uyumlu event:

```
first_upgrade_purchased
  upgrade_id: "<ilk satın alınan upgrade'in id'si>"
  time_since_install_ms: <değer>
```

### 8.2 Upgrade Satın Alım — `feature_unlocked`

Her upgrade satın alımında `feature_unlocked` event'i gönderilir (`docs/telemetry.md §4.3` MVP gereksinimi). `unlock_category: "upgrade"` değeri bu katalogdaki upgrade'ler için kullanılır:

```
feature_unlocked
  unlock_id: "<upgrade_id>"
  unlock_category: "upgrade"
  time_since_install_ms: <değer>
```

Ortak alanlar (`session_id`, `schema_version`, `app_version`, `platform`, `install_id`, `locale`, `client_timestamp_ms`) her event'e eklenir — `telemetry.md §3`.

---

## 9. Balans Notları

### 9.1 Etki Tipi Dengesi

| Etki Tipi | Upgrade Sayısı | Hedef | Durum |
|---|---|---|---|
| Global multiplier | 6 | 6 | Tam |
| Bina-bazlı multiplier | 8 | 8 | Tam |
| Tap power | 6 | 6 | Tam |
| Crit chance / combo | 6 | 6 | Tam |
| Offline bonus | 5 | 5 | Tam |
| Event spawn modifier | 5 | 5 | Tam |
| **Toplam** | **36** | **36** | **Tam** |

### 9.2 Bina-Bazlı Kapsam

| Bina | Upgrade ID | Adet |
|------|-----------|------|
| Crumb Collector | `crumb_mastery_i`, `crumb_mastery_ii` | 2 |
| Oven | `artisan_oven` | 1 |
| Bakery Line | `conveyor_sync` | 1 |
| Delivery Van | `express_route` | 1 |
| Franchise Booth | `franchise_blueprint` | 1 |
| Factory Floor | `precision_floor` | 1 |
| Drone Fleet | `swarm_protocol` | 1 |
| Portal Kitchen | — (endgame, MVP upgrade'siz) | 0 |

7 bina kapsanmış; toplam 8 bina upgrade'i.

### 9.3 Prestige Öncesi Tamamlanabilirlik

Tüm 36 upgrade'in toplam ilk-cut maliyeti yaklaşık 67,000,000 R1'dir (tüm tier toplamları). `economy.md §9.1`'deki ilk prestige eşiği 1e9 R1'dir. Bu demek ki oyuncu ilk prestige'den önce toplam üretimin ~%7'sini upgrade harcamasına ayırmış olur — aspiration hedefine mantıklı yaklaşır ama asla %100 tamamlayamaz. Geç bina upgrade'leri (`swarm_protocol`, `precision_floor`) ve `imperial_formula` ikinci/üçüncü prestige koşusuna rezerve edilmiştir.

### 9.4 Synergy ile Çakışma Yoktur

`economy.md §A.3`'te tanımlanan synergy unlock'lar (bina owned eşiğinde otomatik tetiklenir, ücretsizdir) ile bu katalogdaki bina-bazlı upgrade'ler (R1 ile satın alınır, `UpgradeState`'te saklanır) birbirinden ayrıdır. Her ikisi de `building_specific_multiplier` katmanına çarpımsal katkı sağlar — stacking mekanizması `economy.md §6` ve `§A.3`'te tanımlanmıştır.

---

## 10. Bu Doküman Ne Değildir

| Konu | Nerede Bulunur |
|------|----------------|
| Synergy unlock listesi (ücretsiz otomatik eşik ödülleri) | `economy.md §A.3` |
| Research node kataloğu (R2 ile satın alınan, Research Lab'da) | `research-tree.md` |
| Achievement katalog | Ayrı task (henüz hazırlanmadı) |
| Upgrade ikon / görsel spesifikasyonu | `docs/visual-design.md` (hazırlanıyor) |
| Dart implementasyon kodu | `lib/core/progression/` (ayrı task) |
| Balans parametrelerinin tek kaynak tablosu | `economy.md §11` |
| Upgrades ekranı UI akış spesifikasyonu | `ux-flows.md §5.3` |
| Prestige tree node'ları (R3 ile satın alınan) | `economy.md §9.4–§9.5` |

---

## Revizyon Geçmişi

| Ver. | Tarih | Özet |
|------|-------|------|
| 0.1 | 2026-04-16 | İlk taslak — 36 upgrade, 6 etki tipi, prerequisite grafiği ve balans notları |
