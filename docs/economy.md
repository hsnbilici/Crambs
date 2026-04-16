# Ekonomi Tasarımı — Formüller, Kaynak Akışı ve Balans Parametreleri

**Proje:** Project Crumbs
**Kapsam:** Ekonomi formülleri, kaynak akışı, bina kademeleri, çarpan katmanları, prestige ve monetization sınırları — MVP
**Kaynak:** PRD §8 (8.1–8.9), §9.1, §10, §13; CLAUDE.md §6
**Güncelleme:** 2026-04-16

> Bu doküman PRD §8'in implementasyon-hazır genişlemesidir. Çelişki varsa PRD kazanır.
> Formül parametreleri "ilk-cut" olarak işaretlenmiştir; playtest sonrası ayarlanır.
> Dart kaynak kodu bu dokümana dahil değildir — bkz. `lib/core/economy/`.

---

## 1. Doküman Amacı ve Kapsam

Bu doküman şunları tanımlar:

- Üç kaynağın (R1, R2, R3) üretim, harcama ve prestige davranışı
- Tap ve pasif üretim formülleri ile çarpan katmanları
- Sekiz binanın cost curve parametreleri ve synergy eşikleri
- Bulk satın alma hesaplama yöntemi
- Offline kazanç formülü ve cap kuralları
- Prestige threshold, kazanç formülü ve reset kapsamı
- Monetization sınırları (yasaklar ve izinler)
- Tüm ayarlanabilir parametreler için tek kaynak tablo (§11)
- Kalibrasyon süreci ve playtest tetikleyicileri (§12)

**Bu doküman şunlar değildir:**

- Visual / UX spesifikasyon (`docs/ux-flows.md`)
- Dart implementasyon kodu (`lib/core/economy/`)
- PRD §8 replikası
- Prestige tree node'larının tam içerik listesi (ayrı task, post-B5 `docs/research-tree.md` veya addendum)
- Kozmetik fiyatlandırma ve IAP SKU detayı (monetization runbook ayrı)
- Research node'larının bireysel içeriği (12 node'un bağımlılık grafiği ve etkileri ayrı task)

---

## 2. Kaynaklar

MVP'de üç kaynak tanımlıdır; yalnızca R1 oyun başından aktiftir.

| Kaynak | Kod | Amaç | MVP? | Nerede açılır | Prestige davranışı |
|--------|-----|------|------|---------------|---------------------|
| Crumbs | R1 | Ana kaynak — tap ve pasif üretim | Evet, ilk açılışta | İlk açılışta | Sıfırlanır |
| Research Shards | R2 | Research node unlock maliyeti | Evet, mid-game | 15-30 dk unlock penceresinde (PRD §9.1) | Korunur |
| Prestige Essence | R3 | Kalıcı meta ilerleme | Evet, prestige sonrası | İlk prestige reset'inde | Korunur (prestige'de kazanılır) |

### 2.1 R1 — Crumbs

**Üretim kaynakları:**
- Manuel tap: her dokunuşta `tapPower × critMultiplier` (crit yoksa `critMultiplier = 1`)
- Pasif bina tick'i: her saniye `totalTickRate` (§3.3)

**Harcama alanları:**
- Bina satın alma (`cost(n)` — bkz. §5)
- Upgrade satın alma (upgrade'e özgü sabit maliyet)

**Prestige davranışı:** Prestige reset'inde R1 tamamen sıfırlanır. Lifetime üretim toplamı (`totalLifetimeProduced` — `MetaState`) korunur; prestige formülü bunu kullanır.

### 2.2 R2 — Research Shards

**Üretim kaynakları:**
- Belirli milestone'lara (örn. bina sayısı eşiği, toplam üretim bandı) ulaşıldığında verilir
- Belirli günlük görev tamamlamalarında ek shard verilir
- Pasif üretim yoktur; aktif oynanış ve dönüm noktalarına bağlıdır

**Harcama alanları:**
- Research Lab'daki node'ları açmak için maliyet birimi

**Prestige davranışı:** R2 prestige'de **sıfırlanmaz**. Research mid-game unlock'tur ve kalıcı kabul edilmiştir (MVP karar, 2026-04-16).

### 2.3 R3 — Prestige Essence

**Üretim kaynakları:**
- Yalnızca prestige reset'inde `essence_gained` formülüyle (bkz. §9.2) hesaplanır

**Harcama alanları:**
- Prestige tree node'larını açmak ve geliştirmek için maliyet birimi

**Prestige davranışı:** R3 prestige'de **korunur** — kalıcı meta kaynaktır.

---

## 3. Üretim Akışı

### 3.1 Manuel Tap Üretimi

Her tap'te üretilen R1:

```
tap_income = tapPower × critMultiplier
```

- `tapPower`: `RunState.tapPower` alanından okunur; başlangıç değeri §11 tablosunda
- `critMultiplier`: Crit tetiklendiyse §11'deki sabit değer, tetiklenmediyse `1`
- Crit olasılığı: her tap'te `rand() < critChance` kontrolü yapılır

**Combo penceresi:** 2 saniye içinde 10 tap tamamlandığında 5 saniyelik `comboMultiplier` aktive edilir (bkz. §7.2). Combo aktifken tap_income bu çarpanla çarpılır.

### 3.2 Pasif Bina Üretimi

Her tick'te (1 saniye) üretilen R1:

```
totalTickRate = sum over all buildings of:
    base_production(b) × owned(b) × building_multiplier(b)
                       × global_multiplier
                       × event_multiplier
                       × research_bonus
                       × prestige_permanent_bonus
```

Bu toplam `RunState.currentProductionPerSecond` alanına yazılır ve Home ekranında görüntülenir.

### 3.3 Birleşik Üretim

Tap geliri ve pasif gelir aynı R1 sayacına (`RunState.currentResource`) akar. İki kaynak birbirinden bağımsız çarpan katmanları alır; birbirini iptal etmez.

Tick, game loop tarafından her saniye tetiklenir. Tick hesabı deterministik ve saf fonksiyon olmalıdır (PRD §7.9, CLAUDE.md §7).

### 3.4 Offline Üretim

```
offline_gain = passive_rate × min(delta_seconds, offline_cap_seconds) × offline_bonus
```

- `passive_rate`: offline başladığı andaki `currentProductionPerSecond` değeri
- `delta_seconds`: `now - lastActiveAt`
- `offline_cap_seconds`: §11 tablosundaki cap değeri (saniye cinsinden)
- `offline_bonus`: prestige tree'den ve research'ten gelen kümülatif çarpan

Offline kazanç aktif ortalamasının %50-60'ı düzeyinde tutulmalıdır (PRD §8.3, ilkeler 5-6). Bu oran `offline_bonus` ile `offline_cap` parametrelerinin birlikte kalibrasyonuyla sağlanır.

Hesaplama `SaveRepository` okuma akışında gerçekleşir; timestamp delta yöntemi kullanılır (deterministic replay değil — CLAUDE.md §7, PRD §7.9).

---

## 4. Bina Kademeleri

MVP'de 8 bina bulunur (PRD §8.4, §13). Aşağıdaki değerler ilk-cut olup playtest sonrası ayarlanır.

| # | Bina | Tema Dönemi | Base Production (R1/sn) | Base Cost (R1) | growthRate |
|---|------|-------------|------------------------|----------------|------------|
| 1 | Crumb Collector | Artisan | 0.1 | 15 | 1.12 |
| 2 | Oven | Artisan | 1 | 120 | 1.12 |
| 3 | Bakery Line | Artisan | 8 | 1,200 | 1.13 |
| 4 | Delivery Van | Endüstriyel | 45 | 13,000 | 1.14 |
| 5 | Franchise Booth | Endüstriyel | 260 | 140,000 | 1.14 |
| 6 | Factory Floor | Endüstriyel | 1,400 | 2,000,000 | 1.15 |
| 7 | Drone Fleet | Galaktik | 7,800 | 33,000,000 | 1.16 |
| 8 | Portal Kitchen | Galaktik | 44,000 | 510,000,000 | 1.18 |

**Kalibrasyon gerekçesi:** Her binanın üretimi bir öncekinin yaklaşık 7-10 katıdır; cost artışı ise 8-15 kattır. Bu oran, yeni bina satın alındığında hissedilir güç sıçraması sağlarken cost curve'ü prestige baskısını 30-60 dakika arasında görünür kılar (PRD §8.3, ilke 4). Tema dönemleri (Artisan → Endüstriyel → Galaktik) görsel evrimi ekonomik evrimi yansıtacak biçimde gruplandırılmıştır.

### 4.1 Synergy Upgrade Eşikleri

Her bina için belirli sahiplik sayılarında synergy multiplier unlock tetiklenir:

```
synergy_thresholds = {10, 25, 50, 100, 200}
```

Örnek: Crumb Collector sayısı 10'a ulaştığında, Crumb Collector üretimini artıran synergy multiplier otomatik olarak `building_specific_multiplier`'a uygulanır. Synergy unlock'lar ücretsiz ve otomatiktir — satın alma gerekmez. (Karar güncellendi: Addendum A.3. D3 task kapsamındaki ücretli upgrade'lerle karıştırılmamalıdır.)

---

## 5. Cost Curve

### 5.1 Tekli Satın Alma

```
cost(n) = floor(baseCost × growthRate ^ owned)
```

- `owned`: satın alma öncesi sahip olunan bina sayısı
- `baseCost` ve `growthRate`: §4 tablosundan

Örnek — Crumb Collector (baseCost=15, growthRate=1.12):

| owned | cost(n) |
|-------|---------|
| 0 | 15 |
| 1 | 16 |
| 5 | 26 |
| 10 | 46 |
| 25 | 255 |

### 5.2 Bulk Satın Alma

Shop ekranı dört satın alma modu sunar (PRD §6.2, `docs/ux-flows.md`):

| Mod | Hesaplama |
|-----|-----------|
| 1x | `cost(owned)` |
| 10x | Aşağıdaki geometric series toplamı, k=10 için |
| 25% | Mevcut R1'in %25'iyle alınabilecek maksimum k adet bina |
| max | Mevcut R1'le alınabilecek tüm binalar |

**Geometric series toplamı (k adet satın alma):**

```
bulk_cost(k) = baseCost × (growthRate^(owned+k) - growthRate^owned) / (growthRate - 1)
bulk_cost(k) = floor(bulk_cost(k))
```

**25% modu:** Mevcut R1 bakiyesinin %25'ini bütçe olarak alır; bu bütçe ile alınabilecek maksimum k değeri ikili arama (binary search) ile bulunur. Bütçeyi aşan k hesaplamaya dahil edilmez.

**max modu:** Mevcut R1 bakiyesinin tamamını bütçe olarak alır; aynı yöntemle maksimum k hesaplanır.

Tüm bulk hesaplamalar `lib/core/economy/` içinde saf fonksiyon olarak yer almalıdır (CLAUDE.md §6, kural 6).

---

## 6. Çarpan Katmanları

Tüm çarpanlar tek bir sırada uygulanır. Bu sıra değiştirilemez; farklı bir sıra farklı sayısal çıktı üretir. (PRD §8.6, CLAUDE.md §6, kural 6)

```
final_production(building) =
    base_production(building)
      × owned_count(building)
      × building_specific_multiplier(building)
      × global_multiplier
      × temporary_event_multiplier
      × research_bonus
      × prestige_permanent_bonus
```

### 6.1 Katman Kaynakları

| Katman | State Alanı | Güncelleme Zamanı |
|--------|-------------|-------------------|
| `base_production` | `BuildingState.baseProduction` | Sabit (tasarım zamanı) |
| `owned_count` | `BuildingState.owned` | Her satın almada |
| `building_specific_multiplier` | `BuildingState` — synergy + bina upgrade'lerinden hesaplanır | Upgrade satın alımında |
| `global_multiplier` | `UpgradeState` kayıtlarının toplamından türetilir | Upgrade satın alımında |
| `temporary_event_multiplier` | `EventState.activeRandomEvents[]` — aktif event buff'larının çarpımı | Event tetiklendiğinde / sona erdiğinde |
| `research_bonus` | `ResearchState.unlockedSystems[]` — üretim etkili node'ların kümülatif çarpanı | Research tamamlandığında |
| `prestige_permanent_bonus` | `MetaState.permanentMultipliers` — R3 harcamasına göre güncellenir | Prestige node satın alımında |

Hesaplama her tick'te bu sırayla taze yapılır. Çarpanlar önbelleklenmek (cache) isteniyorsa bağlı state değiştiğinde geçersizleştirilmelidir. Ondalıklı çarpanlar `double` ile taşınır; son çıktı `floor` ile tamsayıya indirilir.

---

## 7. Aktif Oyun Ekonomisi

Aktif oyuncuya pasif oyuncuya kıyasla yaklaşık 2x efektif üretim avantajı hedeflenir. Bu avantaj aşağıdaki mekaniklerle sağlanır (PRD §8.7).

### 7.1 Tap Power

- Başlangıç: §11 tablosundaki `base_tap_power` değeri
- Artış: Her upgrade aldıkça upgrade'e bağlı `effectValue` eklenir
- Upgrade detayları: `UpgradeState.effectType = "tap_power"` kayıtlarında saklanır

### 7.2 Crit Sistemi

- **Crit chance:** Her tap'te `rand() < critChance` kontrolü; başlangıç değeri §11'de
- **Crit multiplier:** Crit tetiklendiğinde `tap_income × critMultiplier`; değer §11'de
- **Upgrade etkisi:** Crit chance ve/veya crit multiplier upgrade'lerle artırılabilir

### 7.3 Combo Penceresi

```
if (tap_count_in_last_2_seconds >= combo_tap_threshold):
    activate comboMultiplier for combo_bonus_duration_seconds
```

- Combo aktifken tüm tap geliri `comboMultiplier` ile çarpılır
- Combo süresi dolunca `comboMultiplier = 1` olur; yeni combo açılabilir
- Parametre değerleri §11'de

### 7.4 Random Bonus Drop'ları

Belirli aralıklarla (RNG tabanlı, event modülü yönetir) kısa süreli bonus event'leri tetiklenir (PRD §10.1):

| Event | Efekt | Süre |
|-------|-------|------|
| Golden Spark | Tek seferlik büyük R1 patlama — anlık kazanç | Anında |
| Rush Hour | Tüm pasif üretim geçici olarak artar | ~30 sn |
| Crit Storm | Crit chance geçici olarak %100'e yükselir | ~15 sn |

Event tetikleme, spawn kuralları ve buff hesabı `lib/core/events/` modülüne aittir (CLAUDE.md §6, kural 4). Economy katmanı yalnızca `temporary_event_multiplier` değerini okur.

### 7.5 Aktif Avantaj Hedefi

Aktif 30 dakika ≈ pasif 60 dakika efektif üretim anlamına gelmelidir. Bu oran playtest'te şu şekilde ölçülür:

- Yalnızca pasif senaryo: ekrana dokunmadan 30 dk bekleme → R1 kazancı
- Aktif senaryo: combo + crit + event fırsatlarını kullanan 30 dk oynama → R1 kazancı
- Hedef oran: aktif kazanç / pasif kazanç ∈ [1.8, 2.5]

Oranın 1.8'in altına düşmesi aktif oyuncuyu anlamsızlaştırır; 2.5'in üstüne çıkması idle oyuncuyu koparır (PRD §8.3, ilkeler 5-6).

---

## 8. Offline Ekonomisi

### 8.1 Formül

```
offline_gain = passive_rate × min(delta_seconds, offline_cap_seconds) × offline_bonus
```

Uygulama her açılışta `SaveRepository` okuma akışında `lastActiveAt` ile mevcut zamanı karşılaştırır ve bu hesabı yapar. Sonuç `Session Recap` modalı aracılığıyla oyuncuya gösterilir (`docs/ux-flows.md` §6).

### 8.2 Offline Cap

| Aşama | Cap Değeri |
|-------|-----------|
| Başlangıç (MVP varsayılanı) | 8 saat |
| Research unlock sonrası | Research node etkisiyle artabilir |
| Prestige upgrade sonrası | Prestige node etkisiyle artabilir |
| MVP maksimumu | 24 saat |

Cap aşıldıktan sonra geçen süre hesaplamaya dahil edilmez. Örnek: oyuncu 30 saat sonra dönerse, 8 saatlik (veya mevcut cap değerindeki) üretim hesaba katılır.

### 8.3 Welcome Back Bonusu

Oyuncu geri döndükten sonra `welcome_back_duration_seconds` boyunca aktif üretimi §11'deki `welcome_back_multiplier` ile artırılır (PRD §10.1). Bu efekt `EventState.returnBonusAvailable` alanıyla yönetilir; multiplier `temporary_event_multiplier` katmanına dahil edilir.

### 8.4 Offline Kazanç Hedefi

Offline kazanç, o süredeki aktif kazancın %50-60'ı düzeyinde tutulmalıdır. Bu oran aşağıdaki parametrelerin kalibrasyonuyla sağlanır:

- `offline_bonus` değeri (prestige upgrade olmadan: 1.0 başlangıç değeri)
- `offline_cap` süresi

%60 üstüne çıkması aktif oyunu anlamsızlaştırır; %50'nin altına düşmesi idle oyuncuyu koparır.

---

## 9. Prestige Ekonomisi

### 9.1 Prestige Threshold

Oyuncu prestige yapabilmek için `totalLifetimeProduced >= prestige_threshold` koşulunu bir kez sağlamış olmalıdır:

```
prestige_available = (totalLifetimeProduced >= T_base)
```

- `T_base`: §11'deki değer (ilk-cut)
- `totalLifetimeProduced`: `MetaState.totalLifetimeProduced` — her run boyunca birikir, prestige'de sıfırlanmaz
- Hedef: oyuncu yaklaşık 45 dakikada T_base'e ulaşır (PRD §8.3, ilke 4; §19 karar #4)

Birden fazla prestige yapıldıkça threshold'un artması veya aynı kalması tasarım kararıdır; MVP'de sabit `T_base` yeterlidir. Oyuncu eşiği geçtikten sonra istediği zaman prestige yapabilir — erken çıkış (az essence) veya geç çıkış (fazla essence) seçimi oyuncunundur.

### 9.2 Prestige Kazancı

```
essence_gained = floor((totalLifetimeProduced / T_base) ^ prestige_formula_exponent)
```

- `prestige_formula_exponent`: §11'deki değer (ilk-cut: 0.5, yani karekök)
- Karekök eğrisi: exponential büyüme yerine azalan artış sağlar; geç prestige'te diminishing returns anlamlıdır
- Minimum essence: eşiğe tam ulaşıldığında `floor(1^0.5) = 1`

Örnek (T_base = 1e9):

| totalLifetimeProduced | essence_gained |
|----------------------|----------------|
| 1.0e9 | 1 |
| 4.0e9 | 2 |
| 9.0e9 | 3 |
| 1.0e11 | 10 |
| 1.0e13 | 100 |

### 9.3 Reset Kapsamı

Prestige reset'inde ne olur:

| State Bileşeni | Prestige'de | Gerekçe |
|----------------|-------------|---------|
| R1 (Crumbs) | Sıfırlanır | Ana kaynak yeni run'da sıfırdan başlar |
| R2 (Research Shards) | Korunur | Research kalıcı mid-game unlock — MVP karar |
| R3 (Prestige Essence) | Korunur | Meta kaynak, prestige'in amacı |
| Binalar (owned count, cost) | Sıfırlanır | |
| Upgrade'ler (purchased) | Sıfırlanır | |
| Run-bazlı combo / buff'lar | Sıfırlanır | |
| Achievements | Korunur | |
| Permanent unlocks / feature flags | Korunur | |
| Research node'ları (unlocked) | Korunur | R2 ile aynı karar |
| `totalLifetimeProduced` | Korunur | Prestige formülü için gerekli |
| `totalPrestiges` | Artar (++1) | |

`MetaState` tüm korunan alanları barındırır; `RunState` ve `BuildingState` sıfırlanır (PRD §7.2, §7.3).

### 9.4 Prestige Çıktıları (Kalıcı)

Prestige tree node'larına R3 harcanarak aşağıdaki kalıcı etkiler elde edilir:

| Çıktı | Formül / Detay |
|-------|----------------|
| Permanent production multiplier | `1 + 0.02 × R3_spent_on_prod_node` (yığılabilir) |
| Offline gain bonus | Her node +%10; maksimum +%100 (MVP cap) |
| Event rarity bonus | Rare event'lerin tetiklenme olasılığı artar |
| Research speed bonus | Research node tamamlanma süresi kısalır |
| QoL unlock | Ör. auto-collect — oyuncu onayı gerekmeden kaynakları toplar |

### 9.5 Prestige Tree (MVP)

MVP'de 6 node yeterlidir (PRD §13: "permanent nodes" dahil, §8.8 özeti). Node içerik listesi bu doküman kapsamı dışındadır; ayrı task'ta `docs/research-tree.md` veya economy.md addendum olarak üretilecektir.

Node'lar `MetaState.permanentUnlocks[]` ve `MetaState.permanentMultipliers` içinde saklanır (PRD §7.2).

---

## 10. Monetization Sınırları

### 10.1 Yasaklar

| Yasaklanan Pratik | Neden |
|-------------------|-------|
| Sert paywall | Onboarding'i ve ilk oturum kalitesini öldürür |
| Premium bina | Progression'ı çarpıtır; ödemeyen oyuncu dezavantajlı kalır |
| Progression'ı bozan IAP | Ekonomiyi çöküntüye uğratır; retention ikinci haftada düşer |
| Günlük streak kaybı cezası | Baskılı retention, PRD §10.3 ve CLAUDE.md §12 ihlali |
| Aşırı reklam zorlaması | UX kalitesini düşürür, mağaza değerlendirme puanını etkiler |

### 10.2 İzin Verilenler

| İzin Verilen | Detay |
|-------------|-------|
| Rewarded ad boost | ×2 üretim 30 dakika; cooldown 4 saat (`CLAUDE.md §13 karar #3`, `docs/ux-flows.md §7.1` ile uyumlu) |
| No-ads IAP | Kalıcı, tek seferlik; reklam gösterimini tamamen kaldırır |
| Starter convenience pack | Küçük, tek seferlik; MVP'de iki SKU — içerik ekonomiyi bozmayacak düzeyde tutulur |
| Kozmetik tema | Post-MVP; oyun ekonomisini etkilemez |

**Rewarded ad boost ekonomisi:** ×2 üretim 30 dakika, 4 saatlik cooldown. Bu oran aktif oyun avantajıyla çakışmasın diye tasarlanmıştır; toplam günlük boost süresi 24 saat içinde yaklaşık 180 dakikaya sınırlıdır. Boost `temporary_event_multiplier` katmanında yer alır; ayrı `buff_type = "rewarded_ad"` kaydıyla diğer event buff'larından ayrıştırılır.

---

## 11. Balans Parametreleri Tablosu

Bu tablo tüm ayarlanabilir parametreler için **tek kaynak** (single source of truth) noktasıdır. Değişiklik yapmak için yalnızca bu tabloyu güncelle. Tüm değerler ilk-cut olup playtest sonrası ayarlanır.

| Parametre | Değer (ilk-cut) | Kaynak / Gerekçe | Playtest'te ayarlanır mı? |
|-----------|-----------------|------------------|--------------------------|
| `base_tap_power` | 1 | Ekonomi başlangıcı | Evet |
| `crit_chance_base` | %1 | Erken oyun rare hissi | Evet |
| `crit_multiplier` | 10× | Hissedilir ama bozucu değil | Evet |
| `combo_tap_threshold` | 10 tap / 2 sn | Aktif oyun tempo hedefi | Evet |
| `combo_multiplier` | ×2 | Aktif avantaj hedefiyle uyumlu | Evet |
| `combo_bonus_duration_seconds` | 5 | Kısa ama ödüllendirici | Evet |
| `offline_cap_start_hours` | 8 | İlk run için dengeli | Evet |
| `offline_cap_max_hours` | 24 | MVP üst sınır | Evet |
| `offline_bonus_base` | 1.0 (prestige upgrade yokken) | Aktif/pasif %50-60 hedefi | Evet |
| `welcome_back_multiplier` | ×1.2 | Geri dönüş teşviki, baskısız | Evet |
| `welcome_back_duration_seconds` | 300 (5 dk) | Yeterli süre, abartısız | Evet |
| `prestige_threshold_T_base` | 1e9 R1 | ~45 dk'da ulaşılabilir hedef | Evet |
| `prestige_formula_exponent` | 0.5 (karekök) | Diminishing returns eğrisi | Evet |
| `prestige_prod_multiplier_per_node` | 0.02 (kümülatif) | Dengeli meta ilerleme | Evet |
| `prestige_offline_bonus_per_node` | %10 (max %100) | Offline cap erişim yolu | Evet |
| `rewarded_ad_multiplier` | ×2 | Fark edilir ama baskın değil | Evet |
| `rewarded_ad_duration_minutes` | 30 | Kısa oturum uzunluğuyla uyumlu | Evet |
| `rewarded_ad_cooldown_hours` | 4 | `CLAUDE.md §13 karar #3`; `ux-flows.md §7.1` ile tutarlı | Evet |
| `research_node_count_mvp` | 12 | PRD FR-10, `CLAUDE.md §13 karar #5` | Hayır (MVP scope kilidi) |
| Bina 1 baseCost | 15 | §4 tablo | Evet |
| Bina 1 growthRate | 1.12 | §4 tablo | Evet |
| Bina 8 baseCost | 510,000,000 | §4 tablo | Evet |
| Bina 8 growthRate | 1.18 | §4 tablo | Evet |
| `synergy_thresholds` | {10, 25, 50, 100, 200} | Milestone hissi | Evet |
| `synergy_multiplier_t10` | ×2 (bina bazlı) | Addendum A.3 | Evet |
| `synergy_multiplier_t25` | ×2 (kümülatif ×4) | Addendum A.3 | Evet |
| `synergy_multiplier_t50` | ×3 (kümülatif ×12) | Addendum A.3 | Evet |
| `synergy_multiplier_t100` | ×3 (kümülatif ×36) | Addendum A.3 | Evet |
| `synergy_multiplier_t200` | ×5 (kümülatif ×180) | Addendum A.3 | Evet |
| `prestige_threshold_growth_factor` | 1.5 | Addendum A.2 | Evet |
| `buff_stacking_model` | "multiplicative" | Addendum A.4 | Hayır (formül kararı) |
| `buff_cumulative_cap` | yok (MVP) | Addendum A.4 | Evet (Phase 2 değerlendirme) |
| `r2_drop_per_achievement_tier_1` | 1 R2 | Addendum A.1 | Evet |
| `r2_drop_per_achievement_tier_2` | 2 R2 | Addendum A.1 | Evet |
| `r2_drop_per_achievement_tier_3` | 3 R2 | Addendum A.1 | Evet |
| `r2_drop_per_prestige` | 5 R2 | Addendum A.1 | Evet |
| `r2_rare_event_drop_chance` | %10 | Addendum A.1 | Evet |
| `r2_rare_event_drop_amount` | 1 R2 | Addendum A.1 | Evet |
| `r2_unlock_threshold_r1` | 5e6 R1 | Addendum A.1 | Evet |

---

## 12. Kalibrasyon Süreci

### 12.1 Başlangıç Durumu

İlk implementation §11 tablosundaki değerleri kullanır. Değerler hipotetik değil; formüller çalışabilir konumdadır.

### 12.2 Hedef Milestone'lar

| Milestone | Hedef Süre | Ölçüm Yöntemi |
|-----------|-----------|---------------|
| İlk bina satın alma (Crumb Collector) | 20-40 saniye | Playtest'te tap sayısı ve bina maliyeti izlenir |
| Bina 5 (Franchise Booth) ilk satın alma | 10-15 dakika | Session kaydında timestamp |
| İlk prestige hazırlığı | 30-60 dakika (hedef ~45 dk) | `docs/telemetry.md §4.4` `first_prestige` event'i |

Bu milestone'lar PRD §8.3 ilkelerine dayanır ve `docs/telemetry.md` §4.4 ile `docs/test-plan.md` §3'te ekonomi formülleri deterministik test olarak güvence altındadır.

### 12.3 Ayar Önceliği

Milestone'lar kaçırılırsa (çok hızlı veya çok yavaş):

1. **Önce:** `growthRate` ve `baseCost` parametrelerini ayarla — en doğrudan etkiyi verir
2. **Sonra:** `offline_cap` ve `offline_bonus` — idle oyuncu akışını etkiler
3. **Son çare:** `prestige_formula_exponent` veya `T_base` — prestige döngüsünü etkiler

Her ayar tek parametre değişikliği olarak yapılmalı; birden fazla parametre aynı anda değiştirilmemelidir (confounding risk). Değişiklik `docs/test-plan.md` §3 kapsamındaki deterministik testlerden geçmeden uygulamaya alınamaz (CLAUDE.md §10).

### 12.4 Research Notları

12 research node'unun içeriği (individual effect, maliyet, bağımlılık grafı) bu doküman kapsamında değildir. Bu detay ayrı bir task'ta (post-Sprint 5, B5 sonrası) `docs/research-tree.md` veya bu dokümanın addendum'u olarak üretilecektir. Node içeriği ekonomi dengesini etkileyeceğinden o task'ta §11 tablosuna ek satır(lar) eklenecektir.

---

## Addendum A — Açık Parametre Setleri

**Versiyon:** 0.1 | **Tarih:** 2026-04-16 | **Yazar:** Economy Design
**Kapsam:** §11 tablosunda eksik kalan 4 parametre setinin kararlaştırılması ve belgelenmesi. Mevcut bölümler değiştirilmemiştir; bu bölüm ek ve tamamlayıcı niteliktedir.

---

### A.1 — R2 (Research Shards) Üretim Mekanizması

#### Bağlam

§2.2'de R2'nin "belirli milestone'lara veya günlük görev tamamlamalarına bağlı" olduğu belirtilmişti. PRD §8.1 pasif üretimi açıkça dışlar. Bu alt bölüm, Research Lab açıldıktan sonra oyuncunun ilk 60-90 dakikada ilk node'unu (5 R2) alabileceği sürdürülebilir bir R2 üretim ritmi tanımlar.

#### Research Lab Açılma Eşiği

Research Lab ilk açılma koşulu `economy.md §11` tablosuna yeni satır olarak eklendi:

```
r2_unlock_threshold_r1 = 5e6 R1 (toplam ömür boyu üretim)
```

Bu eşik PRD §9.1'deki 15-30 dakika unlock penceresiyle uyumludur ve `docs/research-tree.md §6.1`'deki "aktifleşme koşulu" boşluğunu doldurur.

#### R2 Üretim Kaynakları

| Kaynak | Koşul | R2 Miktarı | Ortalama Sıklık (dk / 1 R2) |
|--------|-------|------------|-----------------------------|
| **Bina sahiplik eşiği** | Her binanın 10/25/50/100/200 alımı (§4.1 synergy eşikleri) | 1 R2 / eşik | ~8-15 dk (eşiğe bağlı) |
| **Achievement tamamlama — Tier 1** | Düşük zorluk achievement tamamlanır | 1 R2 | ~10-20 dk |
| **Achievement tamamlama — Tier 2** | Orta zorluk achievement tamamlanır | 2 R2 | ~25-40 dk |
| **Achievement tamamlama — Tier 3** | Yüksek zorluk achievement tamamlanır | 3 R2 | ~60+ dk |
| **Prestige bonusu** | Her prestige reset'inde | 5 R2 | Prestige başına (bir kez) |
| **Rare event drop** | Golden Spark'ın nadir varyantı — olasılık: %10 | 1 R2 | ~30-60 dk (RNG bağımlı) |

**Dahil edilmeyen kaynaklar (MVP):**
- Haftalık tematik event drop'ları — Phase 2.
- Günlük görev sistemi — PRD §14 kapsamında; MVP'de bu sistemin infrastructure'ı mevcut değil.

#### Bina Eşiği — R2 Drop Mantığı

Synergy eşikleri (10/25/50/100/200) hem bina-bazlı multiplier unlock'u hem de 1 R2 drop'unu aynı anda tetikler. Bu, tek bir oyuncu eyleminin iki anlamlı ödülü birden vermesi anlamına gelir; overload yaratmaz çünkü eşikler doğası gereği seyrektir.

8 bina × 5 eşik = teorik maksimum 40 R2 bu kaynaktan. Ancak üst eşikler (100, 200) geç oyunda açılır; ilk prestige öncesi erişilebilir toplam ~16-20 R2 bina eşiklerinden gelir.

#### Günlük Cap

MVP için günlük R2 cap uygulanmaz. Gerekçe: R2 üretimi zaten doğal olarak sınırlıdır (eşikler seyrektir, rare event RNG tabanlı, achievement'lar tekrar etmez). Yapay bir cap, oyuncunun aktif oynanıştan elde ettiği ödülü keserek güven kırar. Phase 2'de veri toplanırsa bu karar gözden geçirilir.

#### İlk Node Erişim Kalibrasyonu

Hedef: `docs/research-tree.md §8.1` ile hizalı olarak **Research Lab açıldığında oyuncunun elinde zaten ~20-30 R2 biriktirilmiş olmalıdır**; böylece ilk 3 ön koşulsuz node (toplam 16 R2) Lab açılışının hemen ardından erişilebilir olur.

- Research Lab açılma eşiği ~15-25 dk'da geçilir (`r2_unlock_threshold_r1 = 5e6 R1`).
- Lab açılana kadar oyuncu: 5-7 bina eşiğini (1-2 bina için 10-eşik, 1 bina için 25-eşik, erken synergy drop'ları) + 2-3 achievement tamamlamış olur → ~20-30 R2 biriktirir.
- Lab açılır açılmaz ilk 3 node (`auto_taps_i` 5 R2, `better_return_bonus` 6 R2, `rare_event_chance` 5 R2 = 16 R2) aynı anda satın alınabilir.
- Sonraki node'lar (4-12) oyuncunun Lab açıldıktan sonra biriktireceği R2 ile kademeli kilit açar; toplam erken-orta oyun ritmi ~90-180 dakika.

Bu kalibrasyon `docs/research-tree.md §8.1`'deki "Research Lab açılırken oyuncunun zaten 20-30 R2 biriktirmiş olması beklenir" ifadesiyle birebir uyumludur.

#### Playtest Doğrulama Sorusu

"Research Lab açıldıktan kaç dakika sonra oyuncu ilk research node'unu satın aldı?" — `telemetry.md §4.3` `first_research_started` event'i zamanlamasıyla ölçülür. Hedef: 30-90 dk. 30 dk'nın altında kalması R2 enflasyonunu işaret eder; 90 dk'nın üzerinde kalması Lab'ın anlamsız hissettirme riskini doğurur.

---

### A.2 — Prestige Threshold Eğrisi (n. Prestige için T)

#### Bağlam

§9.1'de `prestige_available = (totalLifetimeProduced >= T_base)` tanımlanmıştı ve "MVP'de sabit T_base yeterlidir" notu düşülmüştü. Bu alt bölüm, 2.+ prestige'ler için threshold'un nasıl ölçekleneceğini karara bağlar.

#### Karar: Büyüyen Eşik Eğrisi

```
T_n = T_base × growthFactor ^ (n - 1)
```

Burada:
- `n` = prestige numarası (1, 2, 3, ...)
- `T_base` = 1e9 R1 (§11, değişmez)
- `growthFactor` = 1.5 (§11'e yeni satır — Addendum A.2)

Örnekler:

| Prestige No (n) | Threshold T_n (R1) | Yaklaşık Süre (hedef) |
|-----------------|-------------------|-----------------------|
| 1 | 1.00e9 | ~45 dk |
| 2 | 1.50e9 | ~50-55 dk |
| 3 | 2.25e9 | ~55-65 dk |
| 4 | 3.38e9 | ~60-70 dk |
| 5 | 5.06e9 | ~65-80 dk |
| 10 | ~57.7e9 | ~90-120 dk (azalan artış) |

Süre tahminleri ilk-cut; prestige permanent bonus'ları `prestige_formula_exponent` ile birlikte gerçek değerleri etkiler.

#### growthFactor = 1.5 Seçiminin Gerekçesi

Prestige kazanç formülü karekök (`exponent = 0.5`) kullandığı için, aynı T'de kalan bir sistemde her prestige daha kısa sürer ve daha az essence getirir — oyuncu çok sık prestige yaparak ilerler ama her prestige anlamsız hissettirmeye başlar. Büyüyen bir T bu sorunu giderir.

**Alternatif 1: growthFactor = 2.0**
Her prestige threshold'u ikiye katlar. 5. prestige'de T = 16e9 R1. Bu agresif bir eğridir; erken prestige yapanlar sonraki prestige'lerde çok uzun bekleme süreleriyle karşılaşır. Retention riski yüksek. Reddedildi.

**Alternatif 2: growthFactor = 1.25**
Daha yavaş büyüme. 5. prestige'de T = 3.05e9 R1. Prestige süresi çok hızlı normalleşir; 10. prestige'de bile threshold görece düşük kalır. Uzun vadeli esans biriktirme teşvikini zayıflatır. Reddedildi.

**Seçilen: growthFactor = 1.5**
5. prestige'de T = 5.06e9; 10. prestige'de ~57.7e9. Yeterince hissedilir bir zorluk artışı, ancak katlanarak değil. Prestige başına süre ~%15-25 artarken permanent bonus birikimi bu süreyi telafi eder. Diminishing returns eğrisiyle uyumlu.

#### Edge Case: 10.+ Prestige

10.+ prestige'de growthFactor 1.5 üstel artışıyla T değerleri çok büyür; ancak prestige permanent bonus'ları da biriktiğinden süre artışı telafi edilir. MVP aşamasında 10+ prestige erişen oyuncu sayısı sınırlı olacağından bu durum MVP değerlendirme kapsamı dışındadır. Phase 2'de azalan büyüme eğrisi (ör. `growthFactor → 1.2` geçiş, n > 8 için) değerlendirilecektir.

#### Mevcut Formülle Çelişki Yok

Karekök formülü (`essence_gained = floor((totalLifetimeProduced / T_n)^0.5)`) değişmemiştir. Yalnızca `T_n` hesaplamasına `growthFactor ^ (n-1)` çarpanı eklenmektedir. T_1 = T_base olduğundan ilk prestige deneyimi korunur.

---

### A.3 — Synergy Upgrade Maliyet / Etki Tablosu

#### Bağlam

§4.1'de synergy eşikleri `{10, 25, 50, 100, 200}` olarak tanımlanmıştı. Aynı bölümde "synergy upgrade'ler otomatik değil, oyuncu tarafından satın alınır" notu vardı.

**Bu alt bölüm bu kararı değiştirmektedir.** Synergy unlock'lar satın alma gerektirmez; otomatik uygulanır.

#### Revize Karar: Ücretsiz Otomatik Unlock

Oyuncu bir binanın sahiplik sayısı eşiğe (10, 25, 50, 100, 200) ulaştığında, o binaya özgü `building_specific_multiplier` otomatik olarak güncellenir. Maliyeti yoktur, satın alma kuyruklanmaz, onay gerekmez.

**Neden bu değişiklik?**
Milestone hissi en güçlü olduğu anda (tam sayıyı geçme anı) ödülün de verilmesi gerekir. "Şimdi bir şey satın alabilirsin" friction'ı bu anı zayıflatır. Ücretsiz otomatik unlock, Cookie Clicker'ın "milestone achievement" tasarım prensibini takip eder: sayı eşiğe gelir, ekranda bir şey parlar, güç artar.

**D3 upgrade kataloğuyla karışma riski:** D3 task'ı ücretli upgrade'leri kapsar. Synergy unlock'lar bu katalogdan ayrı tutulmalıdır; bunlar free otomatik eşik ödülleridir.

#### Çarpan Pattern'i

Tüm 8 bina için aynı pattern uygulanır:

| Eşik (owned) | Bu Eşikte Uygulanan Çarpan | Kümülatif `building_specific_multiplier` |
|--------------|---------------------------|------------------------------------------|
| 10 | ×2 | ×2 |
| 25 | ×2 | ×4 |
| 50 | ×3 | ×12 |
| 100 | ×3 | ×36 |
| 200 | ×5 | ×180 |

**Kümülatif**: Her eşik bir öncekinin üstüne çarpılır. 200 adede ulaşmış bir bina, base production'ının 180 katını üretir (yalnızca synergy'den; diğer çarpan katmanları ek olarak uygulanır).

#### Tüm 8 Bina — Eşik Tablosu

Tüm binalar için pattern aynıdır. Her bina kendi `building_specific_multiplier` değerini taşır; farklı binaların synergy'leri birbirini etkilemez.

| Bina | T=10 | T=25 | T=50 | T=100 | T=200 |
|------|------|------|------|-------|-------|
| Crumb Collector | ×2 | ×4 | ×12 | ×36 | ×180 |
| Oven | ×2 | ×4 | ×12 | ×36 | ×180 |
| Bakery Line | ×2 | ×4 | ×12 | ×36 | ×180 |
| Delivery Van | ×2 | ×4 | ×12 | ×36 | ×180 |
| Franchise Booth | ×2 | ×4 | ×12 | ×36 | ×180 |
| Factory Floor | ×2 | ×4 | ×12 | ×36 | ×180 |
| Drone Fleet | ×2 | ×4 | ×12 | ×36 | ×180 |
| Portal Kitchen | ×2 | ×4 | ×12 | ×36 | ×180 |

**MVP için bina-tipine göre farklılaştırma neden tercih edilmedi:** Her binanın farklı pattern'i 8 × 5 = 40 ayrı tasarım kararı gerektirir; playtest olmadan bu kararlar keyfi olur. Aynı pattern, binaları eşit güç eğrisinde tutar ve erken oyunlarda yatırım kararını bina seçimi değil maliyet/çıktı oranı üzerine kurar. Phase 2'de differentiation değerlendirilebilir.

#### §6 Çarpan Katmanlarıyla Entegrasyon

`building_specific_multiplier` (§6) kaynakları:
1. Bina-özgü satın alınan upgrade'ler (D3 task kapsamı)
2. **Synergy eşik unlock'ları — bu Addendum A.3'te tanımlandı**

İki kaynak çarpımsal olarak birleşir. Örnek:

```
building_specific_multiplier(Crumb Collector) =
    upgrade_purchased_factor × synergy_factor

// T=50 aşıldı ve 1 bina upgrade satın alındıysa:
synergy_factor = 12
upgrade_purchased_factor = <upgrade'e özgü değer>
```

Bu çarpan `final_production` formülündeki `building_specific_multiplier` katmanına doğrudan beslenir (§6).

#### Playtest Doğrulama Sorusu

"Oyuncu, bina eşiğine ulaştığında synergy bonus'unu fark etti mi?" — Gözlem: sahiplik sayısı 10'a geldiğinde üretim sayacında ani artış görünür mü? Playtestte `currentProductionPerSecond` artışının UI'da yeterince vurgulu olup olmadığı kontrol edilmelidir.

---

### A.4 — Buff Stacking Kuralı

#### Bağlam

§6'daki `temporary_event_multiplier` katmanı şu buff kaynaklarını birleştirir: aktif event'ler (Rush Hour, Crit Storm), rewarded ad boost ve Welcome Back bonusu. Ancak bu buff'ların aynı anda aktif olduğunda birbirleriyle nasıl birleştiği tanımlanmamıştı.

#### Karar: Çarpımsal Birleşme (Multiplicative Stacking)

```
temporary_event_multiplier =
    rewarded_ad_multiplier
    × event_bonus_multiplier
    × welcome_back_multiplier
```

Burada her faktör mevcut duruma göre ya aktif değerini ya da 1.0 (nötr) kullanır. Aktif olmayan buff'lar çarpanı etkilemez.

**Not:** Combo multiplier bu katmanda **değildir**; yalnızca tap geliri hesabında ayrı çarpan olarak uygulanır — detay §A.4 "Combo Multiplier'ın Konumu" alt bölümünde.

**Örnek:**
- Rush Hour aktif: ×1.5 (pasif üretim çarpanı)
- Rewarded ad aktif: ×2.0
- Welcome Back aktif: ×1.2

```
temporary_event_multiplier = 1.5 × 2.0 × 1.2 = 3.6
```

Bu değer `final_production` formülüne (§6) doğrudan girer.

#### Neden Çarpımsal?

Toplamalı (additive) stacking yerine çarpımsal stacking:
- §6 formülü zaten çarpımsal yapıda kurulmuştur; tutarlılık sağlar.
- Her buff'ın tam değerini koruması oyuncuya vaat edilen ödülü yerine getirir.
- Toplamalı birleşme buff'ların marjinal değerini düşürür ve "daha önce al, daha çok al" dinamiğini kırar.

#### Aynı Türden Buff Yığılmaz

İki Rush Hour buffı aynı anda aktif olamaz. Aynı `buff_type` ikinci kez tetiklenirse süresi sıfırlanır (refresh), miktarı eklenmez (stack).

```
// Yanlış (stack):
event_bonus_multiplier = rush_hour_1 × rush_hour_2

// Doğru (refresh):
event_bonus_multiplier = rush_hour (süre yenilendi)
```

Farklı buff türleri (Rush Hour + Rewarded Ad) tam çarpımsal olarak birleşir.

#### Toplam Cap

MVP'de `temporary_event_multiplier` için üst sınır uygulanmaz. Gerekçe:

1. Aynı anda aktif olabilecek buff türleri sayısal olarak sınırlıdır (en fazla 4 faktör).
2. Maksimum teorik çarpan: combo ×2 × ad ×2 × Rush Hour ×1.5 × Welcome Back ×1.2 = ×7.2. Bu değer 30 saniyelik event penceresinde peak üretim anlamına gelir; kalıcı etki yaratmaz.
3. Exploit riski düşük: buff'ların hepsinin aynı anda aktif olması nadir ve oyuncunun aktif çaba göstermesini gerektirir — ödüllendirici tasarım.

Phase 2'de veri incelenirse cap değerlendirilebilir.

#### Combo Multiplier'ın Konumu

Combo multiplier (§7.3) `temporary_event_multiplier` katmanında değil, tap geliri hesabında ayrı bir çarpan olarak uygulanmaktadır. Bu nedenle yukarıdaki formülde `combo_multiplier` pasif üretimi değil yalnızca tap gelirini etkiler. Formül netliği için:

```
// Tap geliri (aktif oyun):
tap_income = tapPower × critMultiplier × comboMultiplier

// Pasif üretim (tüm binalar):
final_production(building) = ... × temporary_event_multiplier × ...

// temporary_event_multiplier (pasif ve aktif ikisi için):
temporary_event_multiplier =
    rewarded_ad_multiplier
    × event_bonus_multiplier
    × welcome_back_multiplier
```

Combo yalnızca tap income formülüne girer, `temporary_event_multiplier`'a dahil değildir.

#### Playtest Doğrulama Sorusu

"Rewarded ad + Rush Hour aynı anda aktifken oyuncu üretim farkını ekranda fark etti mi?" — `currentProductionPerSecond` sayacının görünür bir sıçrama yapması beklenir. Eğer oyuncu buff'ları biriktirmekten keyif alıyorsa (gözlemlenen davranış), tasarım amacına ulaşmıştır.

---

## 13. Bu Doküman Ne Değildir

| Konu | Nerede Bulunur |
|------|---------------|
| Visual / UX spesifikasyon (renk, tipografi, animasyon) | `docs/ux-flows.md` |
| Dart implementasyon kodu | `lib/core/economy/` (ayrı task) |
| PRD §8 birebir replikası | `cookie_clicker_derivative_prd.md` §8 |
| Prestige tree node'larının tam içerik listesi | Post-MVP task — `docs/research-tree.md` veya addendum |
| Kozmetik fiyatlandırma / IAP SKU detayı | Monetization runbook (ayrı) |
| Research node'larının bireysel bağımlılık grafiği | Post-Sprint 5 task |
| Save format şeması | `docs/save-format.md` |
| Telemetri event kataloğu | `docs/telemetry.md` |
| Test senaryosu matrisi | `docs/test-plan.md` |
