# Research Tree — MVP Node Kataloğu

**Proje:** Project Crumbs
**Versiyon:** 0.1 | **Tarih:** 2026-04-16
**Kapsam:** MVP'nin 12 research node'unun tam katalog ve bağımlılık tanımı
**Kaynak:** PRD §9 (unlock), §6.4 (Research Lab), §13 (MVP kapsamı); CLAUDE.md §13 kararlar; `economy.md §2.2`, `§11`; `ux-flows.md §5.4`; `telemetry.md §4.3`
**Güncelleme:** 2026-04-16

> Bu doküman PRD'nin §9.3 "Research tree örneği"nin tam ve uygulanabilir genişlemesidir.
> Çelişki varsa PRD kazanır. Formül parametreleri ilk-cut; `economy.md §11` tek balans kaynağıdır.
> Dart kaynak kodu ayrı task'ta üretilir — bu dokümanda kod yoktur.

---

## 1. Doküman Amacı

Bu doküman Project Crumbs MVP'sinin Research Lab sistemini oluşturan **tam 12 research node'unu** tanımlar: her node'un kimliği, maliyeti, araştırma süresi, etkisi, bağımlılıkları ve kategori sınıflandırması.

**Bu doküman şunlar değildir:**

- R2 (Research Shards) üretim mekanizması — detay `economy.md §A.1`'de netleşti; bu doküman yalnızca node maliyetlerini sabitler.
- Node ikon ve görsel spesifikasyonu — `docs/visual-design.md` (hazırlanıyor).
- Research Lab UI spesifikasyonu — `ux-flows.md §5.4`.
- Post-MVP research kolonları veya ikinci research kolu — PRD §14 Phase 2 roadmap.
- Dart implementasyon kodu.

---

## 2. Tasarım İlkeleri

PRD §9.2 ve §9.3'e göre:

**Her node şu kategorilerden birine hizmet eder:**

| Kategori | Tanım |
|----------|-------|
| **Güç** | Sayısal üretim gücü artışı — pasif veya aktif |
| **Karar** | Oyuncuya yeni bir stratejik seçenek açar |
| **Merak** | Sistemi anlamaya ve keşfetmeye teşvik eder |
| **Görünür Değişim** | Ekranda fark edilen görsel veya yapısal değişim |
| **Yaşam Kalitesi (QoL)** | Aynı oynanışı daha kolay veya bilgiye dayalı yapar |

**Kilit tasarım kısıtları:**

1. Tüm sistemler bir anda açılmaz — kolon ve bağımlılık mimarisi bunu zorlar.
2. Sonraki hedef her zaman görünürdür — tamamlanan her node en az bir yeni node'u görünür kılar veya mevcut gizli node'un koşulunu açıklar.
3. Her node güçlü ama tek boyutlu değil — QoL ve görsel değişim node'ları sayısal güçten bağımsız retention motivasyonu sağlar.
4. İlk 3 node ön koşulsuz olup ilk R2 birikimiyle (~20-30 R2) alınabilmeli (balans notu §8'de).

---

## 3. Beş Research Kolonu

| Kolon | Tema | Node Sayısı | Açılma Sırası |
|-------|------|-------------|---------------|
| **Automation** | Tap → otomatik; pasif üretim otomasyonu | 3 | Erken: Research Lab açıldığında ilk görünen 3 node bu kolondan |
| **Burst Play** | Aktif oyun güçlendirme; anlık yoğun oynanış | 2 | Mid-tier: en az 1 Automation node tamamlanmış olmalı |
| **Offline Growth** | Pasif oyun güçlendirme; yokken kazanç optimizasyonu | 2 | Mid-tier: en az 1 Automation node tamamlanmış olmalı |
| **Prestige Mastery** | Meta ilerleme; reset döngüsünü bilinçli kılmak | 3 | Geç: en az 1 prestige yapılmış olması ön koşul (node 10 hariç) |
| **Collection** | Koleksiyon, kozmetik, tamamlanma motivasyonu | 2 | Esnek: ilk Automation node tamamlanınca erişilebilir |

**Toplam: 12 node**

---

## 4. Node Kataloğu

### 4.1 Kimlik ve Bağımlılık Tablosu

| # | ID | Ad | Kolon | Ön Koşul (node ID) | R2 Maliyeti | Araştırma Süresi |
|---|----|----|-------|--------------------|-------------|-----------------|
| 1 | `auto_taps_i` | Auto Taps I | Automation | — (ön koşulsuz) | 5 R2 | 60 sn |
| 2 | `better_return_bonus` | Better Return Bonus | Offline Growth | — (ön koşulsuz) | 6 R2 | 75 sn |
| 3 | `rare_event_chance` | Rare Event Chance | Burst Play | — (ön koşulsuz) | 5 R2 | 60 sn |
| 4 | `auto_taps_ii` | Auto Taps II | Automation | `auto_taps_i` | 20 R2 | 150 sn |
| 5 | `new_achievement_tier` | New Achievement Tier | Collection | `auto_taps_i` | 12 R2 | 90 sn |
| 6 | `research_speed_boost` | Research Speed Boost | Automation | `auto_taps_i` | 18 R2 | 120 sn |
| 7 | `offline_efficiency` | Offline Efficiency | Offline Growth | `better_return_bonus` | 25 R2 | 180 sn |
| 8 | `crit_storm_power` | Crit Storm+ | Burst Play | `rare_event_chance` | 30 R2 | 200 sn |
| 9 | `building_visual_evolution` | Building Visual Evolution | Collection | `new_achievement_tier` | 22 R2 | 150 sn |
| 10 | `prestige_formula_boost` | Prestige Formula Boost | Prestige Mastery | `auto_taps_ii` | 45 R2 | 300 sn |
| 11 | `permanent_prod_boost` | Permanent Production +%2 | Prestige Mastery | `prestige_formula_boost` | 80 R2 | 420 sn |
| 12 | `prestige_calculator` | Prestige Calculator | Prestige Mastery | `prestige_formula_boost` | 120 R2 | 600 sn |

### 4.2 Etki ve Kategori Tablosu

| # | ID | Etki Tipi | Etki Değeri | Kategori |
|---|----|-----------|-------------|---------|
| 1 | `auto_taps_i` | `auto_tap_rate` | 0.5 tap/sn (pasif otomatik tap eklenir) | Güç |
| 2 | `better_return_bonus` | `offline_cap_hours` | +4 saat (8 saat → 12 saat cap) | Güç |
| 3 | `rare_event_chance` | `event_rarity_pct` | +%5 (rare event tetiklenme olasılığı) | Karar |
| 4 | `auto_taps_ii` | `auto_tap_rate` | +1.0 tap/sn (toplam: 1.5 tap/sn) | Güç |
| 5 | `new_achievement_tier` | `achievement_tier_unlock` | +10 gizli achievement slot'u açılır | Merak |
| 6 | `research_speed_boost` | `research_speed_pct` | -%20 araştırma süresi (tüm sonraki node'lar) | QoL |
| 7 | `offline_efficiency` | `offline_bonus_pct` | +%20 offline üretim oranı (pasif oranın %60'ına çıkar; `economy.md §8.4` cap kuralına tabidir) | Güç |
| 8 | `crit_storm_power` | `event_crit_storm_multiplier` | Crit Storm event süresinde tüm tap geliri ×1.5 (mevcut Crit Storm bonus'una ek) | Karar |
| 9 | `building_visual_evolution` | `cosmetic_unlock` | Binalarda artisan → endüstriyel → galaktik görsel geçişini etkinleştirir | Görünür Değişim |
| 10 | `prestige_formula_boost` | `prestige_multiplier_pct` | Prestige Essence kazancı +%20 (her reset) | Güç |
| 11 | `permanent_prod_boost` | `production_multiplier_pct` | Kalıcı üretim çarpanı +%2 (tüm bina üretimine; `economy.md §9.4` `prestige_prod_multiplier_per_node` ile bağımsız yığılır) | Güç |
| 12 | `prestige_calculator` | `qol_unlock` | Home ekranında "Şu an prestige yapsan X Essence kazanırsın" canlı önizleme aktif olur | QoL |

> **Node 6 — `research_speed_boost` uygulama notu:** -%20 süre indirimi, node 6 tamamlandıktan sonra başlayan araştırmalar için geçerlidir. Hâlihazırda devam eden araştırma etkilenmez. Etki tipi `research_speed_pct`; `ResearchState.researchProgressSeconds` tick'i bu çarpanla hesaplanır.

> **Node 7 — `offline_efficiency` sınır notu:** `economy.md §8.4` "offline kazanç aktif kazancın %50-60'ı düzeyinde tutulmalıdır" ilkesi korunur. +%20 bonus, `offline_bonus_base = 1.0` başlangıç değerini 1.2'ye çıkarır; prestige offline node'larıyla toplam çarpan 2.0'ı (=%100 offline oranı) aşamaz. Cap aşılırsa değer 2.0'da kilitlenir.

---

## 5. Bağımlılık Grafiği

```
RESEARCH LAB AÇILIR (15-30 dk penceresi — ux-flows.md §3.1)
│
├── [Ön Koşulsuz Giriş Noktaları]
│   ├── auto_taps_i          (Automation #1)
│   ├── better_return_bonus  (Offline Growth #1)
│   └── rare_event_chance    (Burst Play #1)
│
auto_taps_i ──────────────────────────────────────────────┐
│                                                          │
├── auto_taps_ii             (Automation #2)               │
│   └── prestige_formula_boost  (Prestige Mastery #1)      │
│       ├── permanent_prod_boost (Prestige Mastery #2)      │
│       └── prestige_calculator (Prestige Mastery #3)      │
│                                                          │
├── research_speed_boost     (Automation #3)               │
│                                                          │
└── new_achievement_tier     (Collection #1)               │
    └── building_visual_evolution (Collection #2)          │
                                                           │
better_return_bonus ─────────────────────────────────────┐ │
└── offline_efficiency       (Offline Growth #2)         │ │
                                                         │ │
rare_event_chance ───────────────────────────────────────┤ │
└── crit_storm_power         (Burst Play #2)             │ │
                                                         │ │
                                               (bağımsız zincirlerin
                                                cross-kolon bağımlılığı yok)
```

**Döngü yok doğrulaması:** Her node ileriye yönlü bağımlılık içerir; geriye dönen kenar yoktur. Zincir: `auto_taps_i → auto_taps_ii → prestige_formula_boost → permanent_prod_boost` ve `auto_taps_i → auto_taps_ii → prestige_formula_boost → prestige_calculator` en uzun bağımlılık zinciridir (derinlik 4). Tüm diğer zincirler derinlik ≤ 3'tür.

**Cross-kolon bağımlılıkları:** `prestige_formula_boost` (Prestige Mastery) `auto_taps_ii`'ye (Automation) bağlıdır. Bu kasıtlı bir tasarım kararıdır: Prestige Mastery geç açılır ve oyuncunun önce Automation'ı yatırıma değer bulması gerekir. Diğer kolonlar (Burst, Offline, Collection) birbirinden bağımsızdır.

**Başlangıç görünürlüğü:** Research Lab ilk açıldığında yalnızca 3 ön koşulsuz node görünür ve araştırılabilir durumdadır. Bağımlı node'lar "kilitli" görünür; ön koşul node'unun tamamlanması üstündeki kilit kaldırır.

---

## 6. Açılma Akışı

### 6.1 Research Lab Sekmesinin Aktifleşmesi

Research Lab sekmesi oyun başından tab bar'da görünürdür fakat kilit ikonlu pasif durumdadır (`ux-flows.md §3.1`, `§5.4`). PRD §9.1'deki 15-30 dakika unlock penceresinde bir milestone koşulu sağlandığında tam erişime açılır.

Aktifleşme koşulu: `totalLifetimeProduced >= r2_unlock_threshold_r1` — değer `5e6 R1` (bkz. `docs/economy.md §A.1` ve §11 parametre tablosu).

### 6.2 İlk Node Görünürlüğü

Research Lab sekmesi aktifleştiğinde:

1. 3 ön koşulsuz node (`auto_taps_i`, `better_return_bonus`, `rare_event_chance`) araştırılabilir durumda gösterilir.
2. Bağımlı node'lar kilitli ama isim ve maliyetleri görünürdür — oyuncuya roadmap verilmiş olur (PRD §6.4 "görünür roadmap").
3. Aktif araştırma kuyruğu boştur; oyuncu herhangi birini seçerek başlatabilir.

### 6.3 Research Lab Açılma Telemetrisi

Research Lab ilk aktifleştiğinde:

```
feature_unlocked
  unlock_id: "research_lab"
  unlock_category: "system"
  time_since_install_ms: <değer>
```

Bu event `telemetry.md §4.3` tanımıyla uyumludur.

### 6.4 Node Araştırma Akışı

Oyuncu bir node araştırmayı başlattığında:

1. `first_research_started` event'i — yalnızca ilk araştırma başlatmasında (`telemetry.md §4.3`):
   ```
   first_research_started
     node_id: "<node_id>"
     time_since_install_ms: <değer>
   ```

2. Araştırma tamamlandığında her node için `feature_unlocked` event'i (`telemetry.md §4.3`):
   ```
   feature_unlocked
     unlock_id: "<node_id>"
     unlock_category: "research"
     time_since_install_ms: <değer>
   ```

3. Tamamlanan node yeni node'ların kilidini açıyorsa, o node'lar görünür araştırılabilir duruma geçer; ek event gönderilmez (görünürlük UI state'i, unlock event'i değil).

### 6.5 İptal Kuralı

Devam eden araştırma iptal edilebilir; **R2 maliyeti iade edilmez** (`CLAUDE.md §13 karar #7`). Tek slot kuyruk sistemiyle birlikte bu kural, dikkatli planlama teşvik eder ve R2 ekonomisine anlam katar.

---

## 7. R2 Ekonomisi — Kısa Özet

Bu doküman R2 üretim mekanizmasını tanımlamaz. Detay `economy.md §2.2` ve `economy.md §A.1`'dedir.

**Bu dokümandan sabit olan:**

- R2, prestige'de korunur (`economy.md §2.2`, §9.3); research progress sıfırlanmaz.
- R2 pasif üretim kaynağı değildir — milestone, achievement drop ve event reward ile gelir.
- Her node maliyeti bu dokümanın §4.1 tablosunda sabitlenmiştir ve `economy.md §11` balans parametrelerine eklenmesi gereken kalemlerdir.

**Toplam node maliyeti özeti:**

| Kolon | Node'lar | Toplam R2 |
|-------|---------|-----------|
| Automation | 5 + 20 + 18 | 43 R2 |
| Burst Play | 5 + 30 | 35 R2 |
| Offline Growth | 6 + 25 | 31 R2 |
| Prestige Mastery | 45 + 80 + 120 | 245 R2 |
| Collection | 12 + 22 | 34 R2 |
| **Tüm ağaç** | | **388 R2** |

Tüm 12 node tamamlamak MVP beklentisi değildir — bu değer geç oyuncu aspiration hedefidir.

---

## 8. Balans Notları

### 8.1 Erken Erişim Dengesi

İlk 3 ön koşulsuz node (maliyetler: 5 + 6 + 5 = 16 R2) ilk R2 birikimiyle (~20-30 R2) satın alınabilmelidir. R2 üretimi milestone ve event odaklı olduğundan, Research Lab açılırken oyuncunun zaten 20-30 R2 biriktirmiş olması beklenir.

### 8.2 Orta Oyun Ritmi

İlk prestige'den sonra, ilk 5-7 node'un kilidi açılabilir ritmi hedeflenir:
- Node 1-3: ön koşulsuz, toplam 16 R2
- Node 4-6: bağımlı, toplam 58 R2 ek (kümülatif 74 R2)
- Node 7-9: ikinci bağımlılık katmanı, toplam 77 R2 ek (kümülatif 151 R2)

Bu ritim, playtest'te `first_research_started` event'i zamanlamasıyla (`telemetry.md §4.3`) doğrulanır.

### 8.3 Geç Oyun Maliyetleri

Prestige Mastery kolonu (node 10-12) kasıtlı olarak yüksek maliyetlidir (245 R2 toplam). Bu colony tam anlamıyla aspiration hedefidir; MVP oturumunda tamamlanması beklenmez.

### 8.4 Araştırma Süreleri

`research_speed_boost` (node 6) tamamlandıktan sonra tüm sonraki node süreleri -%20 ile hesaplanır. Bu önbellekleme `ResearchState` içinde tutulur; aktif araştırma etkilenmez.

| Koşul | Örnek: node 12 (600 sn) |
|-------|------------------------|
| `research_speed_boost` yok | 600 sn |
| `research_speed_boost` var | 480 sn |

### 8.5 Prestige Koruması

Research node'ları prestige'de sıfırlanmaz (`economy.md §9.3`). R2 korunur, node tamamlanma durumu korunur. Bu, research'in run-başına değil, kalıcı meta ilerleme olduğunu teyit eder.

---

## 9. Telemetri Alan Örnekleri

Bu event'ler `telemetry.md §4.3` ile tam uyumludur. Aşağıdaki örnekler doküman içi referans amaçlıdır.

**Research Lab açılma:**
```
feature_unlocked
  unlock_id: "research_lab"
  unlock_category: "system"
```

**İlk araştırma başlangıcı (tek seferlik):**
```
first_research_started
  node_id: "auto_taps_i"
  time_since_install_ms: 932000
```

**Node tamamlanma:**
```
feature_unlocked
  unlock_id: "auto_taps_i"
  unlock_category: "research"
  time_since_install_ms: 993000
```

**Ortak alanlar** (`session_id`, `schema_version`, `app_version`, `platform`, `install_id`, `locale`, `client_timestamp_ms`) her event'e eklenir — `telemetry.md §3`.

---

## 10. Bu Doküman Ne Değildir

| Konu | Nerede Bulunur |
|------|---------------|
| R2 üretim mekanizması detayı (milestone eşikleri, drop miktarları) | `economy.md §A.1` |
| Node ikonları ve görsel spesifikasyonu | `docs/visual-design.md` (hazırlanıyor) |
| Research Lab UI spesifikasyonu (layout, kaydırma, animasyon) | `ux-flows.md §5.4` |
| Post-MVP research kolonları ve ikinci research kolu | PRD §14 Phase 2 roadmap |
| Dart implementasyon kodu | `lib/core/research/` (ayrı task) |
| Prestige tree node'larının tam içerik listesi | `economy.md §9.5` ve addendum |
| Balans parametrelerinin tek kaynak tablosu | `economy.md §11` — bu dokümanın §4.1 maliyet satırları oraya eklenecektir |

---

## Revizyon Geçmişi

| Ver. | Tarih | Özet |
|------|-------|------|
| 0.1 | 2026-04-16 | İlk taslak — 12 node, 5 kolon, bağımlılık grafiği ve balans notları |
