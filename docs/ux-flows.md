# UX Akışları — Ekran Akış ve Navigasyon Spesifikasyonu

**Proje:** Project Crumbs
**Kapsam:** MVP ekran akışları ve navigasyon spesifikasyonu
**Kaynak:** PRD §6, §9, §10, §12 NFR-3/5, §13, §FR-3, §FR-4, §FR-8
**Güncelleme:** 2026-04-16

> Bu doküman CLAUDE.md §4 ve PRD §6'nın operasyonel detayıdır. Çelişki varsa PRD kazanır.
> Dart kaynak kodu ayrı bir task'ta üretilir — bu dokümanda kod yoktur.

---

## 1. Doküman Amacı

Bu doküman, Project Crumbs MVP'sindeki 9 ekranın kullanıcı akışlarını, navigasyon mimarisini ve kabul kriterlerini tanımlar.

**Kapsam dahili:**
- Ekran akışları (entry point, exit point, adım adım kullanıcı davranışı)
- Navigasyon haritası ve tab bar yapısı
- Session Recap modal akışı
- Rewarded ad ve No-ads IAP akışları
- Onboarding akışı (FR-3, FR-4)
- Erişilebilirlik kontrol listesi (NFR-3, NFR-5)

**Kapsam dışı:**
- Görsel tasarım spesifikasyonu (renk paleti, tipografi, ikonlar — görsel spec ayrı)
- Animasyon ve hareket spesifikasyonu (gecikme süreleri, easing — motion spec ayrı; Session Recap sayaç animasyonu için kritik süre sınırı olan 1,5 sn buraya dahildir)
- PRD §6'nın birebir kopyası — bu doküman akış ve kabul kriteri odaklıdır
- Metin kopyası (copywriting ayrı)
- Non-MVP ekranlar (hafta sonu etkinlikleri, cloud save UI, sosyal paylaşım)

---

## 2. Tasarım İlkeleri (PRD §1 Operasyonel)

Aşağıdaki ilkeler her ekran kararını değerlendirirken referans alınır.

| # | İlke | Operasyonel Kural |
|---|------|--------------------|
| 1 | İlk 30 saniyede anlaşılır | Home ekranı açıldığında oyuncunun bir sonraki aksiyonu bulmak için düşünmesi gerekmez; ana etkileşim tek bakışta görünür |
| 2 | İlk 5 dakikada ≥10 anlamlı unlock/satın alma | Shop ve Upgrades unlock sıraları bu pencereye göre kalibre edilir; onboarding bu eşiği karşılayacak şekilde tasarlanır. Onboarding bittiğinde oyuncu ≥2 bina satın almış ve ≥1 upgrade görmüş olmalı; 10 unlock eşiği ekonomi kalibrasyonuna bağlıdır — `docs/test-plan.md`'de manuel test senaryosu zorunludur. |
| 3 | Her 5–10 dakikada görünür yenilik | Unlock ağacı (PRD §9.1) UI'ya yeni eleman olarak yansır; kilitli alanlar görünür ama erişilemez biçimde gösterilir |
| 4 | Ekranda aynı anda ≤3 aktif öneri | Home ekranında eş zamanlı öneri sayısı programatik olarak sınırlanır; fazlası sonraki açılışa ertelenir |
| 5 | Ceza yok, geri dönüş ödülü var | Boş state mesajları ceza dili kullanmaz; Session Recap ödül odaklıdır |
| 6 | Tek başparmak erişilebilir ana aksiyon | Ana CTA alt yarıda; tab bar hit area ≥44×44 pt; thumb reach zone birincil önceliktir |

---

## 3. Navigasyon Haritası

### 3.1 Yapı

Uygulama navigasyonu **5 sekmeli alt tab bar** üzerine kuruludur. Tüm ana ekranlar en fazla tek sekme dokunuşu uzaklığındadır.

**Research sekmesi koşullu erişim:** Tab bar'da her zaman görünür fakat oyun başlangıcında kilit ikonlu pasif durumdadır; PRD §9.1'deki 15-30 dk unlock penceresinde tam erişime açılır (detay §5.4).

```
┌─────────────────────────────────────────────────────────┐
│                   EKRAN İÇERİĞİ                         │
│                                                         │
│   ┌──────────────────────────────────────────────────┐  │
│   │           Session Recap Modal (üstte)            │  │
│   │   [Collect]   [Take Action]   [Dismiss]          │  │
│   └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
┌───────────┬───────────┬───────────┬───────────┬─────────┐
│   Home    │   Shop    │ Upgrades  │ Research  │  More   │
│           │           │           │           │         │
│  (§6.1)   │  (§6.2)   │  (§6.3)   │  (§6.4)   │ ┌─────┐│
│           │           │           │           │ │Events││
│           │           │           │           │ │Prst. ││
│           │           │           │           │ │Coll. ││
│           │           │           │           │ │Sett. ││
│           │           │           │           │ └─────┘│
└───────────┴───────────┴───────────┴───────────┴─────────┘
```

### 3.2 Navigasyon Kuralları

- **Modal üstüne modal açılmaz.** Session Recap açıkken başka modal tetiklenmez.
- **Session Recap modalı** cold start veya warm-return'de Home ekranına gelindikten sonra, `lastActiveAt` > 60 sn ise tek seferlik gösterilir (FR-8). Detay §6.
- **Geri tuşu / swipe-back davranışı:** Tab bar sekmeleri arasında geri yok; More alt ekranlarından geri tuşu More listesine döner.
- **Deep link desteği (implementation-ready):**

| Deep Link URL | Hedef Ekran |
|---------------|-------------|
| `crumbs://home` | Home / Production |
| `crumbs://shop` | Shop |
| `crumbs://upgrades` | Upgrades |
| `crumbs://research` | Research Lab |
| `crumbs://prestige` | Prestige |

Deep link geldiğinde önce Home yüklenir, ardından hedef sekme veya ekran aktif edilir. Session Recap bekleyen bir geri dönüşte deep link, recap gösterildikten sonra işlenir.

---

## 4. First-Run Onboarding Akışı (FR-3, FR-4)

### 4.1 Genel Kurallar

- En fazla **3 adım** (FR-3).
- Her adım tamamlandığında `tutorial_step_complete` gönderilir (`telemetry.md §4.2`).
- Kullanıcı adımları atlayabilir; atlama varsayılan değildir.
- Skip → `tutorial_skipped` event gönderilir, `at_step_index` alanı hangi adımda atlandığını taşır (`telemetry.md §4.2`).
- Kabul kriteri: kullanıcı ilk binayı en geç **60 saniyede** satın alabilmeli (FR-4).

### 4.2 Adımlar

**Başlangıç (adım öncesi):** Tutorial ilk adımı görünür olduğunda `tutorial_started` gönderilir (`step_index: 0` sabit — bu **event** step_index'idir, aşağıdaki `tutorial_step_complete` step_index'i ile aynı numaralandırma düzlemini paylaşır ancak farklı event türüdür).

**Adım 1 — Ana fırın nesnesine tap (PRD §6.1 davranış)**

| Alan | Değer |
|------|-------|
| Amaç | Oyuncunun temel etkileşimi öğrenmesi |
| Bileşen | Ana üretim nesnesi üzerinde pulse efekti + yönlendirici callout |
| Beklenen aksiyon | Nesneye tap |
| Tamamlanma koşulu | İlk tap gerçekleşti |
| Skip yolu | Callout'ta "Atla" butonu |
| Telemetri | `tutorial_step_complete` → `step_index: 0`, `step_name: "first_tap"` |

**Adım 2 — İlk bina satın alımı (PRD §9.1 ilk 5 dk unlock'ı)**

| Alan | Değer |
|------|-------|
| Amaç | Shop akışını öğretmek; ekonomik döngünün hissini vermek |
| Bileşen | Shop sekmesine yönlendiren callout + ilk bina kartında highlight |
| Beklenen aksiyon | İlk binayı satın almak |
| Tamamlanma koşulu | `first_building_purchased` state güncellemesi |
| Skip yolu | Callout'ta "Atla" butonu |
| Telemetri | `tutorial_step_complete` → `step_index: 1`, `step_name: "first_building"` |

**Adım 3 — Session Recap teaser — "Siz yokken de çalışır"**

| Alan | Değer |
|------|-------|
| Amaç | Offline-first döngüsünü tanıtmak; geri dönüş motivasyonunu erken kurmak |
| Bileşen | Home ekranında tek sayfalık bilgi kartı (tam ekran modal değil) |
| İçerik | "Uygulamadan çıksan da fırının çalışır. Geri döndüğünde ne biriktirdiğini görürsün." |
| Beklenen aksiyon | "Anladım" CTA'sına tap |
| Tamamlanma koşulu | CTA'ya tap veya skip |
| Skip yolu | "Atla" butonu |
| Telemetri | `tutorial_step_complete` → `step_index: 2`, `step_name: "recap_teaser"` → ardından `tutorial_complete` |

### 4.3 Tutorial Kabul Kriterleri

- Adım 1'de ilk tap'tan sonra kaynak sayacı güncellenir (< 100 ms, NFR-1).
- Adım 2'de bina satın alma, tutorial başından itibaren en geç 60 sn içinde mümkün olmalı (FR-4).
- Üç adım toplam süresi ekonomik dengeye bağlı; en kötü senaryoda 90 sn kabul edilir.
- Skip edilen tutorial sonrasında oyun tamamen işlevseldir; kilitli UI elemanı kalmaz.
- Tutorial yalnızca `is_first_session == true` oturumunda gösterilir.

---

## 5. Ekran Akışları

### 5.1 Home / Production (PRD §6.1)

**Amaç:** Oyunun ana oynanış yüzeyi; kaynak üretimi ve hız izleme.

**Entry points:**
- Uygulama cold start (varsayılan açılış ekranı)
- Tab bar → "Home" sekmesi
- Deep link: `crumbs://home`
- Session Recap modal kapandıktan sonra

**Exit points:**
- Tab bar → diğer sekmeler
- Session Recap modal tetiklenir (warm return)
- Rewarded ad dialog tetiklenir (buff kart tap)

**Ana bileşenler (PRD §6.1):**
- Büyük ana üretim nesnesi (tap hedefi)
- Mevcut kaynak sayacı
- Saniyelik üretim hızı
- Kısa hedef paneli
- Aktif buff göstergeleri
- Alt tab bar
- Mini görev / next unlock kartı (≤3 aktif öneri)

**Kullanıcı akışı:**

1. Uygulama açılır → Home ekranı yüklenir → kaynak sayacı ve üretim/sn görünür
2. Oyuncu ana nesneye tap eder → anlık sayısal artış ve görsel feedback (< 100 ms)
3. Kaynak biriktikçe hedef paneli güncellenir ("X crumbs biriki → Oven satın al")
4. Aktif buff varsa buff göstergesi ekranda belirir (≤3 eş zamanlı)
5. Mini görev / next unlock kartı güncel en yakın hedefi gösterir
6. Oyuncu buff kartına tap eder → Rewarded Ad Dialog tetiklenir (§7)
7. Tab bar ile diğer ekranlara geçiş

**Kabul kriterleri:**
- Tap sonrası görsel yanıt < 100 ms (NFR-1)
- Saniyelik üretim değeri sürekli güncellenir
- Ekranda aynı anda ≤3 aktif öneri (PRD §6.1)
- Kullanıcı ilk açılışta 10 sn içinde ana etkileşimi anlar (PRD §6.1)
- Yalnızca aktif buff'lar gösterilir; boş buff alanı yer kaplamaz

**Boş state:** İlk açılışta bina yok, üretim/sn = 0; hedef paneli "İlk binanı satın al" önerisi gösterir.

**Hata state:** Kaynak sayacı yüklenemezse son bilinen değer gösterilir; save okuma hatası olursa `SaveLoadResult.recovered` veya `SaveLoadResult.fresh` durumuna göre kullanıcıya bilgi mesajı (save-format.md §8).

**Loading state:** Cold start'ta save yüklenirken sayaç alanı yükleniyor göstergesi (skeleton) kullanır; tab bar bu süre boyunca devre dışı değil, yalnızca sayaç alanı beklemede.

---

### 5.2 Shop (PRD §6.2)

**Amaç:** Otomatik üretim binalarının satın alınması.

**Entry points:**
- Tab bar → "Shop" sekmesi
- Onboarding Adım 2 yönlendirmesi
- Home ekranındaki öneri kartı (varsa)
- Session Recap modal → "Take Action" → satın alma önerisi
- Deep link: `crumbs://shop`

**Exit points:**
- Tab bar → diğer sekmeler
- Geri butonu (eğer öneri kartından açıldıysa)

**Ana bileşenler (PRD §6.2):**
- Bina listesi (kaydırılabilir)
- Mevcut sahiplik adedi
- Bir sonraki maliyet
- 1x / 10x / 25% / max satın alma seçenekleri
- ROI etiketi (FR-6)
- En verimli satın alma önerisi highlight'ı

**Kullanıcı akışı:**

1. Tab bar'dan "Shop" sekmesine tap → ekran açılır
2. Bina listesi kaydırılır; mevcut kaynak ile satın alınabilir binalar aktif, diğerleri görünür-kilitli
3. En verimli satın alma önerisi highlight veya etiketle işaretlenir
4. Oyuncu miktar seçiciyle (1x / 10x / 25% / max) alım adedini seçer
5. Bina kartına tap → satın alma gerçekleşir → anlık görsel onay (flash veya badge artışı)
6. Üretim/sn değeri anında güncellenir
7. Yeni bina satın alındığında ilgili synergy upgrade'i açılmışsa Upgrades sekmesinde bildirim noktası belirir

**Kabul kriterleri:**
- Oyuncu en karlı satın almayı tek bakışta ayırt edebilmeli (FR-6)
- Satın alma gecikme hissedilmemeli (< 100 ms görsel yanıt)
- Yetersiz kaynak durumunda bina kartı devre dışı görünür, tap'ta yetersiz kaynak uyarısı gösterilir
- Satın alma sonrası Home ekranındaki üretim/sn anlık güncellenir

**Boş state:** Tüm binalar kilitli (ekonomik eşik aşılmamış) — "Daha fazla üret, ilk binanı aç!" mesajı.

**Hata state:** Satın alma işlemi state güncellenemezse önceki değer restore edilir; kullanıcıya sessiz hata gösterilmez, geliştirici log'a yazılır.

**Loading state:** İlk yüklemede bina listesi skeleton ile gösterilir; satın alma butonu skeleton süresince devre dışı.

---

### 5.3 Upgrades (PRD §6.3)

**Amaç:** Çarpan ve sinerji sistemlerini yönetmek.

**Entry points:**
- Tab bar → "Upgrades" sekmesi
- Shop ekranında yeni bina alındığında sinerji unlock bildirimi
- Session Recap modal → "Take Action" → upgrade önerisi

**Exit points:**
- Tab bar → diğer sekmeler

**Ana bileşenler (PRD §6.3):**
- Satın alınabilir upgrade kartları
- Kaynak gereksinimi
- Etki açıklaması
- Kategori filtresi (global multiplier / bina bazlı / tap power / crit / offline / event)

**Kullanıcı akışı:**

1. Tab bar'dan "Upgrades" sekmesine tap → ekran açılır
2. Varsayılan görünüm: satın alınabilir upgrade'ler üstte, kilitliler altta
3. Kategori filtresi ile liste daraltılır
4. Upgrade kartına tap → etki açıklaması genişler (accordion veya bottom sheet)
5. "Satın Al" butonu aktif ve yeterli kaynak varsa tap → anlık satın alma
6. Satın alma sonrası kart "alındı" durumuna geçer ve listedeki sırası değişir (alınanlar alta iner veya gizlenir)

**Kabul kriterleri (PRD §6.3 + FR-7):**
- Bina bazlı ve global upgrade'ler ayrı görülebilir (kategori filtresi veya bölüm başlığı)
- Satın alınan upgrade listeden çıkar veya devre dışı duruma düşer
- Gereksinim karşılanmayan upgrade'ler görünür-kilitli; gereksinim koşulu etiketle gösterilir

**Boş state:** Tüm upgrade'ler alındıysa "Harika! Tüm mevcut upgrade'leri aldın. Yeni upgrade'ler için araştır." mesajı.

**Hata state:** Satın alma başarısız olursa kart durumu geri alınır.

**Loading state:** Kategori filtresi değiştirildiğinde anlık; skeleton yok.

---

### 5.4 Research Lab (PRD §6.4)

**Amaç:** Orta oyun derinliğini kontrollü açmak; oyuncuya görünür roadmap vermek.

**Entry points:**
- Tab bar → "Research" sekmesi
- Belirli bir unlock eşiği aşıldığında Home'dan bildirim noktası (PRD §9.1, 15-30 dk penceresi)

**Exit points:**
- Tab bar → diğer sekmeler

**Ana bileşenler (PRD §6.4):**
- Araştırma düğümleri (12 node, FR-10)
- Bağımlılık çizgileri (hangi node hangisini açar)
- Araştırma süresi / maliyeti
- Aktif araştırma kuyruğu (MVP: tek slot)

**Kullanıcı akışı:**

1. Tab bar'dan "Research" sekmesine tap → ekran açılır
2. Araştırma ağacı kaydırılabilir tuval olarak gösterilir; tamamlananlar, aktif olan ve kilit açılabilirler görsel olarak ayrışır
3. Araştırılabilir bir node'a tap → detay paneli açılır (maliyet, beklenen süre, etki açıklaması)
4. "Araştır" butonuna tap → araştırma başlar → tek slot dolar, diğer node'lar "Kuyruk dolu" durumuna geçer
5. Aktif araştırma ilerleme çubuğuyla gösterilir; uygulama kapatılsa da süre gerçek zamanda ilerler (offline)
6. Araştırma tamamlandığında; node tamamlandı olarak işaretlenir, yeni sistemler açılır, Home'da bildirim noktası belirir

**Kabul kriterleri:**
- Research Lab sekmesi tab bar'da her zaman görünürdür; başlangıçta kilit ikonu ile pasif, PRD §9.1'deki 15-30 dk unlock penceresinde etkileşime açılır (bkz. §3.1 kural tutarlılığı)
- Oyuncu aktif araştırmayı iptal edebilir; **maliyet iade edilmez** (tasarım kararı 2026-04-16 — `CLAUDE.md §13` karar #7)
- Tek slot kuyruk dolduğunda başka araştırma başlatılamaz, butona basılamaz
- Düğüm bağımlılıkları görsel olarak ayrışır (prerequisite karşılanmadıysa node erişilemez)

**Boş state:** Research Lab henüz unlock olmadıysa tab bar'da kilit ikonu ve "15. dakikada açılır" bilgi metni.

**Hata state:** Araştırma başlatılamadıysa (yetersiz kaynak) detay panelinde hata mesajı, butona dokunulmaz yapılmaz — devre dışı görünür.

**Loading state:** Araştırma ağacı yüklenmesi < 1 sn beklenir; uzarsa skeleton.

---

### 5.5 Events (PRD §6.5)

**Amaç:** Kısa süreli aktif fırsatları ve düşük baskılı günlük görevleri göstermek.

**Entry points:**
- More → Events
- Home ekranından aktif event bildirimi (overlay veya badge)

**Exit points:**
- More listesine geri
- Tab bar → diğer sekmeler

**Ana bileşenler (PRD §6.5):**
- Anlık event'ler (Golden Spark, Rush Hour, Crit Storm — PRD §10.1.A)
- Günlük görevler (FR-12: ≥3 görev türü)
- Geri dönüş bonusu (PRD §10.1.B)

**Kullanıcı akışı:**

1. More → Events → ekran açılır
2. Anlık event'ler üstte listelenir; süre sayacı geri sayar
3. Günlük görevler ilerleme çubuğuyla gösterilir
4. Aktif bir event kartına tap → event detayı ve katılım aksiyonu gösterilir
5. Günlük görev tamamlandığında ödül anında verilir ve kart tamamlandı durumuna geçer
6. Geri dönüş bonusu varsa özel kart olarak ayrışır; bonusu al → ödül verilir → kart kaybolur

**Kabul kriterleri:**
- Event tetikleme görünür olmalı (PRD §10.2)
- Event kaçırmak cezalandırıcı değil (streak kaybı yok — PRD §10.3)
- Günlük görevler gece yarısı sıfırlanır (PRD §7.7 `lastDailyResetAt`)
- Event marker'lar renk + ikon + etiket birleşimi kullanır (NFR-5 renk körlüğü uyumu)
- Anlık event'lerin süresi dolduğunda kart listeden kayar; "kaçırdın" mesajı gösterilmez

**Boş state:** Aktif event yok → "Şu an aktif fırsat yok. Yakında yenisi gelecek." mesajı; günlük görevler her zaman gösterilir.

**Hata state:** Event listesi yüklenemezse son bilinen state gösterilir; internet gerekmez (offline-first).

**Loading state:** Offline-first yapı nedeniyle liste local state'ten anlık okunur. Yalnızca cold start'ta ve liste henüz hiç yüklenmemişse kısa skeleton gösterilir (< 300 ms; uzarsa skeleton devam eder). Tekrar açılışlarda skeleton gerekmez.

---

### 5.6 Prestige (PRD §6.6)

**Amaç:** Reset karşılığında kalıcı meta ilerleme sunmak.

**Entry points:**
- More → Prestige
- Deep link: `crumbs://prestige`
- Home ekranında prestige eşiği yaklaştığında bildirim kartı (PRD §9.1, 30-60 dk penceresi)

**Exit points:**
- More listesine geri
- Tab bar → diğer sekmeler
- Prestige onaylandığında: Home ekranına yönlendir (yeni run başlar)

**Ana bileşenler (PRD §6.6):**
- Şu an reset atılırsa kazanılacak meta kaynak (Prestige Essence)
- Bir sonraki önerilen reset eşiği
- Bu run vs sonraki run tahmini güç farkı
- Permanent upgrade tree özeti

**Kullanıcı akışı:**

1. More → Prestige → ekran açılır
2. Mevcut run verisi gösterilir: kazanılacak Prestige Essence miktarı, güç farkı tahmini
3. Permanent upgrade tree özeti kaydırılabilir listede gösterilir; hangi node'un ne kadar Prestige Essence gerektirdiği açık
4. "Prestige Yap" CTA butonuna tap → onay dialog'u açılır
5. Onay dialog'unda: "Bu run sıfırlanacak; X Prestige Essence kazanacaksın. Devam et?" + "İptal" ve "Prestige Yap" butonları
6. "Prestige Yap" → state sıfırlanır, Prestige Essence eklenir → `prestige` event gönderilir (`telemetry.md §4.4`) → Home ekranına yönlendirilir
7. Yeni run başlangıcında Home ekranı temizlenmiş kaynakla açılır; kalıcı bonus aktif

**Kabul kriterleri (FR-9):**
- Prestige sistemi MVP'de aktif
- Onay dialog'u atlanamaz (doğrulama zorunlu)
- Prestige sonrası save anında force-flush (save-format.md §5.1)
- Kazanılacak Prestige Essence değeri prestige yapılmadan görünür; "Şimdi değil" mümkün

**Boş state:** Prestige eşiğine ulaşılmamışsa "Daha fazla üret — prestige seçeneği [X] Crumbs'ta aktif olacak." mesajı; "Prestige Yap" butonu devre dışı.

**Hata state:** Prestige state güncellenemezse işlem geri alınır; kullanıcıya "Tekrar dene" mesajı.

---

### 5.7 Collection / Achievements (PRD §6.7)

**Amaç:** Sayısal ilerleme dışında koleksiyon ve tamamlanma motivasyonu sağlamak.

**Entry points:**
- More → Collection

**Exit points:**
- More listesine geri
- Tab bar → diğer sekmeler

**Ana bileşenler (PRD §6.7):**
- Achievement listesi (tamamlanan + kilitli)
- Gizli achievement slotları
- Kozmetik unlock albümü
- Bina evrim görselleri

**Kullanıcı akışı:**

1. More → Collection → ekran açılır
2. Tamamlanan achievement'lar üstte; kilitliler altta; gizliler "???" olarak gösterilir
3. Achievement kartına tap → detay paneli (koşul, ödül, ne zaman alındığı)
4. Kozmetik albüm bölümünde unlock edilmiş görseller ve kilitli slot'lar gösterilir
5. Bina evrim bölümünde her binanın mevcut görsel seviyesi gösterilir

**Kabul kriterleri:**
- Yeni achievement açıldığında Home'da bildirim noktası (badge) belirir
- Gizli achievement koşulları tamamlanmadan açıklanmaz
- Achievement verileri save'e yazılır; prestige'de kaybolmaz (kalıcı koleksiyon)

**Boş state:** Hiç achievement kazanılmamışsa "Oynamaya devam et — ilk achievement yakında!" mesajı.

**Hata state:** Görsel yüklenemezse placeholder ikon kullanılır; liste yapısı bozulmaz.

**Loading state:** Achievement ve koleksiyon listeleri local state'ten anlık okunur; skeleton gerekmez. Bina evrim görselleri ve kozmetik albüm görselleri lazy-load ile yüklenir; yüklenene kadar placeholder görünür, yükleme tamamlandığında content reflow olmaz (görsel alanı önceden rezerve edilir).

---

### 5.8 Settings (PRD §6.8)

**Amaç:** Oyuncu tercihlerini ve save yönetimini barındırmak.

**Entry points:**
- More → Settings

**Exit points:**
- More listesine geri
- Tab bar → diğer sekmeler
- "Reklamları Kaldır" tap → No-ads IAP Sheet (§8)
- "Save Export" tap → sistem paylaşım sheet'i
- "Save Import" tap → dosya seçici

**Ana bileşenler (PRD §6.8):**
- Ses toggle
- Titreşim toggle (NFR-5)
- Büyük sayı biçimi seçimi (aa, bb, 1.5K/1.5M) (NFR-3)
- Battery saver mode toggle
- Save export / import (FR-13)
- Analytics izinleri (reklam consent yönetimi)
- Mola hatırlatıcısı
- "Reklamları Kaldır" butonu (No-ads IAP girişi)
- "Satın Alımları Geri Yükle" butonu (Restore Purchases)

**Kullanıcı akışı:**

1. More → Settings → ekran açılır
2. Toggle'lar anlık etki yapar; confirm dialog gerektirmez
3. Büyük sayı biçimi değişikliği anlık önizleme gösterir (örnek sayıyla)
4. "Save Export" tap → platform paylaşım sheet'i açılır → kullanıcı dosyayı kaydeder/paylaşır
5. "Save Import" tap → dosya seçici açılır → dosya seçilir → checksum doğrulaması yapılır → başarılı ise state yüklenir, başarısız ise hata mesajı
6. "Reklamları Kaldır" tap → No-ads IAP akışı (§8)
7. "Satın Alımları Geri Yükle" tap → platform IAP restore API çağrısı → başarılı ise `ad_removal_purchased` flag güncellenir → tüm reklam entry noktaları gizlenir

**Kabul kriterleri:**
- Titreşim kapatıldığında tüm ekranlarda haptic feedback durur (NFR-5)
- Low-motion mode açıldığında animasyonlar kısalır / devre dışı kalır (NFR-5)
- Save export/import hata state'leri açık mesajla gösterilir
- "Reklamları Kaldır" butonu `ad_removal_purchased` flag true ise gizlenir veya "Satın alındı" olarak değişir
- Analytics toggle değişikliği `ad_consent_granted` / `ad_consent_denied` event'lerine eşleşir

**Boş state:** Geçerli değil; ayarlar her zaman gösterilir.

**Hata state:** Save import checksum hatası → "Dosya bozuk veya geçersiz. Başka bir save dosyası dene." mesajı; mevcut save değişmez.

**Loading state:** Anlık; tüm toggle ve tercih değerleri local state'ten okunur, skeleton gereksiz.

**Save corruption recovery UX:** `SaveLoadResult.recovered` durumunda Settings ekranında bilgi bandı: "Yedek save yüklendi. Bazı son değişiklikler kaybolmuş olabilir." — band kapatılabilir, kalıcı uyarı değil. `SaveLoadResult.fresh` durumunda aynı band farklı mesajla: "Save dosyası okunamadı. Oyun sıfırdan başlatıldı."

---

### 5.9 Session Recap Modal (PRD §6.9 — Kritik MVP)

Detaylı akış için §6'ya bakınız.

**Amaç:** Geri dönüşte ilerleme özetini vermek; re-entry friction'ı azaltmak.

**Entry points:**
- Uygulama cold start veya warm-return → `lastActiveAt` > 60 sn → Home ekranı yüklendikten sonra otomatik (FR-8)

**Exit points:**
- "Topla" (Collect) → modal kapanır, Home güncellenir
- "Aksiyona Geç" (Take Action) → modal kapanır, ilgili ekrana yönlendirilir
- "Kapat" (Dismiss) → modal kapanır, Home'da kalır

**Ana bileşenler (PRD §6.9):**
- Yokken üretilen toplam kaynak
- En çok katkı veren bina
- Pasif kazanç çarpanı
- Alınabilecek en verimli 3 aksiyon CTA'sı
- Varsa açılan yeni özellik bildirimi

**Kullanıcı akış adımları (özet — detay §6'da):**

1. Uygulama ön plana gelir → `lastActiveAt` > 60 sn ise modal hazırlanır
2. Home ekranı arka planda yüklendikten sonra modal açılır; özet gösterilir (kaynak, bina, çarpan)
3. Oyuncu CTA seçer: "Topla", "Aksiyona Geç" veya "Kapat"
4. Modal kapanır → Home güncellenir (kaynaklar sayaca eklenir)

**Kabul kriterleri (özet):**

- Modal oturum başına tek seferlik gösterilir; aynı cold start'ta ikinci kez tetiklenmez
- 3 CTA mevcut: Collect, Take Action, Dismiss
- Kaynak sayaç animasyonu ≤ 1,5 sn; animasyon tamamlanmadan önce de modal kapatılabilir

**Boş / Hata / Loading state:**

- **Boş:** `lastActiveAt` > 60 sn koşulu sağlanmıyorsa (yokluk süresi ≤ 60 sn) modal açılmaz; Home doğrudan gösterilir.
- **Hata:** Offline hesap tutarsızlığı veya veri bozulması durumunda basit "Hoş geldin" varyantı gösterilir; kaynak sayacı ve bina detayı atlanır, yalnızca geri dönüş selamı ve tek "Devam Et" CTA'sı bulunur.
- **Loading:** Animasyon süresince "Topla" ve "Aksiyona Geç" butonları devre dışıdır; "Kapat" her zaman aktiftir (animasyonu beklemeden modal kapatılabilir).

---

## 6. Session Recap Modal — Detaylı Akış

### 6.1 Trigger Koşulu

| Koşul | Değer |
|-------|-------|
| Kaynak alanı | `RunState.lastActiveAt` (PRD §7.3) |
| Eşik | `now - lastActiveAt > 60 sn` |
| Gösterim zamanı | Home ekranı yüklendikten sonra, modal üstüne modal kuralı ihlal edilmeden |
| Oturum başına gösterim | Tek seferlik; aynı cold start'ta ikinci kez gösterilmez |

### 6.2 Akış Adımları

1. Uygulama ön plana gelir → `session_start` gönderilir (`telemetry.md §4.1`)
2. `lastActiveAt` değeri okunur; 60 sn eşiği aşılmışsa modal hazırlanır
3. Home ekranı arka planda yüklenir (save okunur, production tick çalışır)
4. Modal açılır → `session_recap_shown` event gönderilir (`offline_duration_ms`, `resource_earned_offline` — `telemetry.md §4.7`)
5. Kaynak sayaç animasyonu çalışır — **maksimum 1,5 sn** (animasyon tamamlanmadan CTA'lar aktif olmayabilir; kullanıcı beklemeden kapatabilir)
6. Modal içeriği gösterilir:
   - "X Crumbs üretildi" (yokken üretilen)
   - "En çok katkı: [Bina Adı]"
   - Pasif çarpan değeri
   - En verimli 3 aksiyon önerisi (buton veya kart)
   - Yeni özellik unlock varsa "Yeni: [özellik adı]" bandı
7. Oyuncu seçim yapar:

| Aksiyon | Davranış | Telemetri (`telemetry.md §4.7`) |
|---------|----------|----------------------------------|
| "Topla" (Collect) | Modal kapanır, Home'daki sayaç güncellenir | `session_recap_action_taken` → `action_type: "collect"` (bkz. `docs/telemetry.md §4.7`) |
| "Aksiyona Geç" (Take Action — önerilerden birine tap) | Modal kapanır, ilgili ekrana yönlendirilir | `session_recap_action_taken` → `action_type: "buy_building"` / `"buy_upgrade"` / `"open_shop"` |
| "Kapat" (Dismiss — X veya dışarıya tap) | Modal kapanır, Home'da kalır | `session_recap_dismissed` |

8. Modal kapandıktan sonra Home ekranı güncellenmiş kaynakla gösterilir

### 6.3 Erişilebilirlik

| Konu | Kural |
|------|-------|
| Screen reader | Modal platform erişilebilirlik katmanına (iOS VoiceOver, Android TalkBack) dahil edilir; başlık, içerik ve her CTA butonu ayrı semantic node olarak tanımlanır |
| Focus yönetimi | Modal açılınca focus otomatik olarak modal başlığına taşınır; kapanınca önceki focus noktasına döner |
| Animasyon | `prefers-reduced-motion` / low-motion mode aktifse sayaç animasyonu atlanır, son değer doğrudan gösterilir |
| Renk | Önerilen aksiyonlar renk + ikon + metin üçlüsüyle gösterilir |
| Dokunma hedefi | Her CTA butonu ≥44×44 pt |

---

## 7. Rewarded Ad Akışı (PRD §FR-14)

### 7.1 Trigger

Oyuncu Home ekranında aktif buff kartına ("2x üretim 30 dk") tap eder.

**Cooldown:** 4 saat — PRD §19 açık soru 3 için alınan takım kararı (2026-04-16). Playtest sonrası ayarlanır. Cooldown süresince buff kartı devre dışı görünür; üzerinde geri sayım gösterilir.

### 7.2 Akış Adımları

1. Buff kartına tap → "Reklam izle ve 2x üretimi etkinleştir?" dialog'u açılır
2. Dialog'da: "İzle" ve "Vazgeç" butonları
3. İlk kez görüntüleniyorsa consent prompt gösterilir (iOS: ATT izni, Android: Play consent) — `ad_consent_prompt_shown` gönderilir (`telemetry.md §4.6`)
4. Oyuncu "İzle" → consent verilmişse devam, verilmemişse consent dialog açılır
5. Consent onaylandı → `ad_consent_granted` gönderilir; reklam SDK'sı yüklenir (yükleniyor göstergesi)
6. Reklam oynatılır → `rewarded_ad_viewed` gönderilir
7. Reklam tamamlanır → `rewarded_ad_completed` gönderilir → buff aktif edilir → "2x üretim aktif! 30 dk boyunca." onay flash'ı
8. Dialog kapanır → Home ekranında buff göstergesi belirir

### 7.3 Hata ve Abort Durumları

| Durum | Davranış |
|-------|----------|
| Reklam yüklenemedi | "Reklam şu an yüklenemiyor. Daha sonra tekrar dene." mesajı → dialog kapanır |
| Reklam yarıda kesildi | Buff verilmez; "Reklamı tamamlamadın. Tekrar izlemek ister misin?" → yeniden deneme seçeneği |
| Consent reddedildi | `ad_consent_denied` gönderilir; buff kart devre dışı kalır; reklam izleme seçeneği gizlenmez (kullanıcı ileride tekrar consent verebilir) |
| Cooldown aktif | Buff kartına tap → "Bir sonraki reklam [X:XX] sonra" tooltip'i; dialog açılmaz |

---

## 8. No-ads IAP Akışı (PRD §FR-15)

### 8.1 Trigger

- Settings → "Reklamları Kaldır" butonu
- Events ekranındaki üst banner (varsa)

### 8.2 Akış Adımları

1. "Reklamları Kaldır" butonuna tap → platform native store sheet açılır
2. Kullanıcı ücret ve içeriği görür → "Satın Al" veya "İptal"
3. "Satın Al" → platform doğrulaması → başarılı
4. `ad_removal_purchased` flag save'e yazılır → force-flush (`save-format.md §5.1`)
5. Tüm reklam entry noktaları gizlenir:
   - Home ekranında rewarded ad buff kart'ı tamamen gizlenir — reklam satın alındığı için bedava buff verilmez (tasarım kararı 2026-04-16, `CLAUDE.md §13` karar #6)
   - Events ekranındaki reklam banner'ı gizlenir
   - Settings'teki "Reklamları Kaldır" butonu "Satın alındı" durumuna geçer veya gizlenir
6. Onay flash gösterilir: "Reklamlar kaldırıldı. Teşekkürler!"

### 8.3 Restore Purchases

1. Settings → "Satın Alımları Geri Yükle" butonu tap → yükleniyor göstergesi
2. Platform IAP restore API çağrısı yapılır
3. Başarılı ve daha önce No-ads satın alınmışsa → `ad_removal_purchased` flag set edilir → §8.2 adım 5 uygulanır
4. Restore edilecek satın alım bulunamazsa → "Geri yüklenecek satın alım bulunamadı." mesajı

### 8.4 Hata Durumları

| Durum | Davranış |
|-------|----------|
| Satın alma başarısız (platform hatası) | Platform hata mesajı gösterilir; flag değiştirilmez |
| Restore başarısız | "Geri yükleme başarısız. Daha sonra tekrar dene." |
| Çevrimdışı satın alma girişimi | Platform kendi hata mesajını gösterir; uygulama store sheet'i açmaz, internet bağlantısı uyarısı gösterir |

---

## 9. Erişilebilirlik ve NFR-3/NFR-5 Kontrolleri

### 9.1 Tek Elle Erişim (NFR-3)

| Kural | Uygulama |
|-------|----------|
| Ana CTA alt yarıda | Home tap hedefi, Shop satın alma butonu, Session Recap CTA'ları hepsi ekranın alt %60'ında |
| 5 sekmeli alt tab bar | Tüm sekmeler thumb reach zone içinde; tab hit area ≥44×44 pt |
| More alt menüsü | More'dan açılan ekranlar ayrı scroll sayfası değil — bottom sheet veya push navigation (UX kararı açık; tercih: push navigation) |
| Kaydırma geri dönüşü | Uzun listelerde (Shop, Upgrades) üstteki en verimli öneri sabit kalmaz — "en üste dön" FAB veya kayan başlık değerlendirmeye açık |

### 9.2 Büyük Sayı Biçimi (NFR-3)

- Settings'ten seçilebilen biçimler: `aa/bb` (Avrupa), `1.5K/1.5M` (kısa İngilizce)
- Seçim anında tüm sayı gösterimleri güncellenir (Home sayacı, Shop maliyetleri, Prestige Essence değeri)
- Varsayılan biçim: uygulama locale'ine göre belirlenir

### 9.3 Titreşim Toggle (NFR-5)

- Settings'te "Titreşim" toggle'ı; kapalıyken tap feedback, satın alma feedback, achievement kazanma gibi tüm haptic event'ler durur
- Ses kapalıyken ve titreşim kapalıyken modal bildirimler görsel olarak görünür kalır

### 9.4 Low-motion Mode (NFR-5)

- Settings'te "Düşük Hareket" toggle'ı veya sistem düzeyinde `prefers-reduced-motion` tespiti
- Açıkken:
  - Session Recap sayaç animasyonu atlanır; son değer doğrudan gösterilir
  - Bina satın alma onay flash'ı anlık geçer (animasyon yok)
  - Event kartı kayma animasyonları atlanır; liste anında güncellenir

### 9.5 Renk Körlüğü Uyumu (NFR-5)

- Event marker'lar: **renk + ikon + etiket** üçlüsü zorunlu; renk tek başına anlam taşımaz
- Achievement tamamlanma: tik ikonu + renk değişimi + metin
- ROI etiketi Shop'ta: ikon + "Önerilen" etiketi + renk (renk tek taşıyıcı değil)
- Buff göstergeleri Home'da: ikon + kalan süre metni
- Session Recap CTA'ları: "Topla", "Aksiyona Geç" ve "Kapat" butonlarının her biri ikon + etiket ile ayrıştırılır; renk farkı tek taşıyıcı değildir

### 9.6 Genel Kontrol Listesi

Aşağıdaki maddeler §9.1–9.5'teki kural setlerinin tamamlama kriteri özetidir. Detaylar ilgili alt bölümlerde bulunur.

- [ ] Hit area, focus yönetimi ve tek elle erişim — bkz. §9.1
- [ ] Renk körlüğü uyumu ve görsel ayrıştırma — bkz. §9.5
- [ ] Low-motion ve `prefers-reduced-motion` — bkz. §9.4

---

## 10. Bu Doküman Ne Değildir

| Konu | Nerede bulunur |
|------|----------------|
| Renk paleti, tipografi, ikon seti | Görsel spec (hazırlanıyor — `docs/visual-design.md` veya Figma) |
| Motion / animation spec (easing, süre) | Motion brief (hazırlanıyor) |
| PRD §6 birebir kopyası | `cookie_clicker_derivative_prd.md §6` |
| Metin kopyası (button label'lar, onboarding metni) | Copywriting dokümanı (hazırlanıyor) |
| Weekend events, cloud save UI, sosyal paylaşım | Non-MVP — PRD §14. Events ekranında bu dönem için placeholder veya kilitli UI alanı gösterilmez; ekran yalnızca MVP kapsamını içerir. |
| Ekonomi formülleri (ROI hesabı, prestige formülü) | `docs/economy.md` |
| Telemetri event detayları | `docs/telemetry.md` |
| Save format ve hata kodları | `docs/save-format.md` |
| Test senaryoları | `docs/test-plan.md` |
