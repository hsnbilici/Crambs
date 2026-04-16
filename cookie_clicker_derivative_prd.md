# Cookie Clicker Türevi Ürün Gereksinim Dokümanı

## 0. Doküman amacı
Bu doküman, Cookie Clicker’dan ilham alan fakat doğrudan kopya olmayan, mobil öncelikli, tek oyunculu, offline-first incremental oyunun ürün gereksinimlerini tanımlar. Doküman aynı zamanda Claude Code ile geliştirilecek bir repo için uygulanabilir olacak şekilde yazılmıştır.

Bu dokümanın hedefi üç şeyi aynı anda netleştirmektir:
1. Ne inşa edeceğiz
2. Hangi sırayla inşa edeceğiz
3. Claude Code ile çalışırken hangi doğrulama ve repo kurallarını kullanacağız

## 1. Ürün özeti
### Ürün tanımı
Kod adı: **Project Crumbs**

Project Crumbs; tek dokunuşla başlayan, kısa seanslarda oynanabilen, offline ilerleme sunan, otomasyon ve soft-reset katmanlarıyla derinleşen mobil incremental oyundur.

### Ürün vizyonu
Oyuncuya “sayı artıyor” hissinden daha fazlasını vermek:
- kısa sürede öğrenilen,
- sık geri dönüşte ödüllendiren,
- orta oyunda yeni sistemler açan,
- baskıcı değil ama güçlü ilerleme hissi veren,
- tek başına geliştirilebilir bir ürün çıkarmak.

### Hedef platform
- iOS ve Android
- Portre kullanım öncelikli
- Tek elle oynanabilir
- Offline-first

### İş modeli
MVP için:
- Free-to-play
- Rewarded ad
- Reklam kaldırma IAP
- 2 adet küçük convenience IAP paketi

### Tasarım ilkeleri
1. İlk 30 saniyede anlaşılır olmalı.
2. İlk 5 dakikada en az 10 anlamlı satın alma veya unlock vermeli.
3. Oyuncu oyundan ayrıldığında da geri dönmek için sebep bırakmalı.
4. Her 5-10 dakikada bir görünür yenilik göstermeli.
5. Ceza yerine geri dönüş ödülü kullanmalı.
6. Sistemler artmalı ama ekran karmaşası kontrol altında kalmalı.

## 2. Hedef kitle
### Birincil kitle
- 18-35 yaş
- Casual / midcore mobil oyuncu
- Kısa oturumlarla oynayan kullanıcı
- “Bir bakıp çıkacağım” davranışına sahip
- Gün içinde çok kez geri dönen kullanıcı

### İkincil kitle
- Optimize etmeyi seven incremental oyuncu
- Excel zihniyeti olan, verimlilik farklarını görmek isteyen oyuncu
- Prestige zamanlaması, build verimi ve combo pencereleriyle ilgilenen kitle

### Oyuncu ihtiyaçları
- Çok hızlı öğrenme
- Net hedefler
- Sürekli ama kontrollü ödül hissi
- Geri dönüşte görünür ilerleme özeti
- Orta oyunda yeni mekanikler

### Oyuncu problemleri
- Salt sayı artışı kısa sürede sıkabilir
- Orta oyunda tekrar hissi oluşabilir
- Çok fazla sistem erken açılırsa korkutucu olur
- Sadece aktif oynamaya ödül verirse idle oyuncu kopar
- Sadece pasif oynanırsa aktif oyuncu sıkılır

## 3. Ürün konumlandırması
### Referans oyunlardan farkımız
Bu ürün doğrudan Cookie Clicker klonu olmayacak.

Farklarımız:
- daha net hedef paneli
- daha güçlü “sen yokken ne oldu” özeti
- daha görünür unlock roadmap
- mobil için sadeleştirilmiş bilgi mimarisi
- orta oyunda daha sık mikro-unlock
- daha etik retention: streak cezası yok, baskılı FOMO yok

### Ürün vaadi
“30 saniyede öğren, 30 gün boyunca geri dön.”

## 4. Oyun döngüsü
### Çekirdek döngü
1. Tap ile temel kaynağı üret
2. Otomatik üretim binaları satın al
3. Üretim çarpanları ve sinerji upgrade’leri aç
4. Kısa süreli event fırsatlarını değerlendir
5. Meta kaynağı biriktir
6. Prestige yap
7. Daha hızlı yeni run başlat

### Sekonder döngüler
- günlük mikro hedefler
- koleksiyon sayfası
- aktif bonus pencereleri
- araştırma / laboratuvar sistemi
- görsel evrim / tema açılımları

### Seans türleri
- 15-60 saniye: hızlı check-in
- 2-5 dakika: alışveriş ve hedef planlama
- 5-15 dakika: combo kovalamaca / aktif event seansı

## 5. Yüksek seviyeli bilgi mimarisi
Oyunda aşağıdaki ana ekranlar bulunur:
1. Home / Production
2. Shop
3. Upgrades
4. Research Lab
5. Events
6. Prestige
7. Collection / Achievements
8. Settings
9. Session Recap modal

## 6. Ekran gereksinimleri
### 6.1 Home / Production ekranı
Amaç: Oyunun ana oynanış yüzeyi.

Bileşenler:
- büyük ana üretim nesnesi
- mevcut kaynak sayacı
- saniyelik üretim hızı
- kısa hedef paneli
- aktif buff göstergeleri
- alt tab bar
- mini görev / next unlock kartı

Davranış:
- ana nesneye dokunma anında görsel ve sayısal geri bildirim üretir
- ekranda aynı anda en fazla 3 aktif öneri gösterilir
- ekrandan ayrılmadan temel satın alma önerisi görülebilir

Kabul kriterleri:
- kullanıcı ilk açılışta 10 saniye içinde ana etkileşimi anlar
- tıklama sonrası 100 ms altında görsel yanıt görünür
- saniyelik üretim değeri sürekli güncellenir

### 6.2 Shop ekranı
Amaç: Otomatik üretim varlıklarının satın alınması.

Bileşenler:
- bina listesi
- mevcut sahiplik adedi
- bir sonraki maliyet
- 1x / 10x / 25% / max satın alma seçenekleri
- ROI etiketi
- en verimli satın alma önerisi

Davranış:
- liste açılışta en erişilebilir satın almayı üstte gösterebilir
- satın alım sonrası ilgili üretim etkisi anında yansır

Kabul kriterleri:
- oyuncu en karlı satın almayı tek bakışta ayırt edebilmeli
- satın alma gecikmesi hissedilmemeli

### 6.3 Upgrades ekranı
Amaç: Çarpan ve sinerji sistemlerini yönetmek.

Bileşenler:
- satın alınabilir upgrade kartları
- kaynak gereksinimi
- etki açıklaması
- kategori filtresi

Upgrade tipleri:
- global multiplier
- bina bazlı multiplier
- tap power
- crit chance / combo modifier
- offline bonus
- event spawn modifier

### 6.4 Research Lab ekranı
Amaç: Orta oyun derinliğini kontrollü açmak.

Bileşenler:
- araştırma düğümleri
- bağımlılık çizgileri
- araştırma süresi / maliyeti
- aktif araştırma kuyruğu (MVP’de tek slot)

Amaç:
- güç artışı dışında yeni sistemler açmak
- oyuncuya görünür roadmap vermek

### 6.5 Events ekranı
Amaç: Kısa süreli aktif fırsatları ve düşük baskılı görevleri göstermek.

Bileşenler:
- anlık event’ler
- günlük görevler
- geri dönüş bonusu
- limited thematic weekend event alanı (post-MVP)

### 6.6 Prestige ekranı
Amaç: reset karşılığında kalıcı meta ilerleme sunmak.

Bileşenler:
- şu an reset atılırsa kazanılacak meta kaynak
- bir sonraki önerilen reset eşiği
- bu run vs sonraki run tahmini güç farkı
- permanent upgrade tree özeti

### 6.7 Collection / Achievements ekranı
Amaç: sayısal ilerleme dışında koleksiyon ve tamamlanma motivasyonu sağlamak.

Bileşenler:
- achievement listesi
- gizli achievement slotları
- kozmetik unlock albümü
- bina evrim görselleri

### 6.8 Settings ekranı
Bileşenler:
- ses
- titreşim
- büyük sayı biçimi
- battery saver mode
- save export/import
- analytics izinleri
- mola hatırlatıcısı

### 6.9 Session Recap modal
Amaç: geri dönüşte ilerleme özetini vermek.

Gösterilecekler:
- yokken üretilen toplam kaynak
- en çok katkı veren bina
- pasif kazanç çarpanı
- alınabilecek en verimli 3 aksiyon
- varsa açılan yeni özellik

Bu ekran kritik özelliktir. MVP kapsamındadır.

## 7. State model
### 7.1 Top-level state
```text
GameState
- meta
- run
- inventory
- buildings
- upgrades
- research
- events
- achievements
- collections
- settings
- telemetry
- save
```

### 7.2 Meta state
```text
MetaState
- prestigeCurrency
- totalLifetimeProduced
- totalPrestiges
- permanentUnlocks[]
- permanentMultipliers
- featureFlagsUnlocked[]
```

### 7.3 Run state
```text
RunState
- currentResource
- currentProductionPerSecond
- tapPower
- critChance
- critMultiplier
- comboState
- activeBuffs[]
- currentRunStartAt
- lastActiveAt
- offlineAccumulated
```

### 7.4 Building state
```text
BuildingState
- id
- owned
- baseCost
- currentCost
- baseProduction
- unlocked
- levelVisualTier
- synergyTags[]
```

### 7.5 Upgrade state
```text
UpgradeState
- id
- unlocked
- purchased
- category
- price
- prerequisiteIds[]
- effectType
- effectValue
```

### 7.6 Research state
```text
ResearchState
- nodes[]
- activeResearchId
- researchProgressSeconds
- unlockedSystems[]
```

### 7.7 Event state
```text
EventState
- activeRandomEvents[]
- dailyGoals[]
- returnBonusAvailable
- eventSpawnSeed
- lastDailyResetAt
```

### 7.8 Save model
Save yaklaşımı:
- tek local save slot zorunlu
- ikinci manuel save slot opsiyonel
- offline progress timestamp tabanlı hesaplanır
- save checksum ile bozulma tespiti yapılır
- save migration versiyon alanı zorunlu

```text
SaveEnvelope
- version
- lastSavedAt
- gameState
- checksum
```

### 7.9 State management ilkeleri
- state deterministic olmalı
- tüm ekonomiyi etkileyen hesaplamalar saf fonksiyonlarda tutulmalı
- görsel state ile ekonomik state ayrılmalı
- offline hesap deterministic replay yerine timestamp delta ile çözülebilir
- feature flag yaklaşımı unlock ağacı ile uyumlu olmalı

## 8. Ekonomi tasarımı
### 8.1 Kaynaklar
#### R1: Ana kaynak
- her tıklama ve pasif üretimle kazanılır
- tüm erken oyun satın alımlarında kullanılır

#### R2: Research Shards
- orta oyunda açılır
- research node’ları için kullanılır
- pasif değil, belirli milestone ve event’lerden gelir

#### R3: Prestige Essence
- reset ile kazanılır
- kalıcı meta ilerleme kaynağıdır

### 8.2 Üretim kaynakları
Üretim iki eksende akar:
1. manual tap income
2. passive building income

Bu iki akış aynı kaynakta birleşir fakat farklı multiplier katmanları alabilir.

### 8.3 Ekonomi ilkeleri
1. İlk bina ilk 20-40 saniyede alınmalı.
2. İlk 5 bina türü ilk 10-15 dakikada açılmalı.
3. Oyuncu her 2-3 dakikada bir anlamlı karar vermeli.
4. Prestige ilk kez 30-60 dakika arasında mantıklı görünmeli.
5. Aktif oyun kazancı pasif oyunu tamamen öldürmemeli.
6. Pasif oyun aktif oyunu anlamsızlaştırmamalı.

### 8.4 Bina kademeleri
Örnek bina sıralaması:
1. Crumb Collector
2. Oven
3. Bakery Line
4. Delivery Van
5. Franchise Booth
6. Factory Floor
7. Drone Fleet
8. Portal Kitchen

Her yeni bina:
- daha yüksek base production verir
- daha yüksek cost curve ile gelir
- belirli sayıda alımda bir synergy upgrade açar

### 8.5 Cost curve
Başlangıç yaklaşımı:
- her bina için exponential cost growth
- farklı bina sınıfları için farklı eğimler
- erken oyunda çok sert olmayan, orta oyunda prestige ihtiyacını görünür kılan eğri

Önerilen mantık:
- cost(n) = baseCost × growthRate^owned
- growthRate bina sınıfına göre 1.12 - 1.18 bandında başlar

### 8.6 Üretim çarpanları
Çarpan katmanları:
- base production
- owned count
- building-specific multiplier
- global multiplier
- temporary event multiplier
- research bonus
- prestige bonus

Bu çarpanlar tek yerde toplanmalı; kodda dağınık tutulmamalı.

### 8.7 Aktif oyun ekonomisi
Aktif oyuncu için:
- tap crit chance
- short combo window
- random bonus drops
- active burst event

Amaç:
- aktif oyuncuya avantaj ver
- fakat oyunu sadece spam tap yarışına çevirme

### 8.8 Prestige ekonomisi
Prestige şu ihtiyaçları çözmeli:
- ekonomik duvarı kırmak
- yeni meta karar alanı açmak
- oyuncuya tekrar başlama sebebi vermek

Prestige çıktıları:
- permanent multiplier
- offline gain bonus
- event rarity bonus
- research speed bonus
- QoL unlock

### 8.9 Monetization ile ekonomi sınırı
Asla yapılmayacaklar:
- sert paywall
- premium bina
- temel progression’ı bozan IAP
- günlük streak kaybı cezası
- aşırı reklam zorlaması

Yapılabilecekler:
- rewarded ad ile kısa boost
- reklam kaldırma
- küçük starter convenience pack
- kozmetik tema

## 9. Unlock ağacı
### 9.1 Erken oyun unlock’ları
0-5 dakika:
- tap tutorial
- ilk bina
- x10 satın alma
- ilk global upgrade
- ilk mini achievement
- session recap intro

5-15 dakika:
- yeni bina türleri
- crit tap
- first random event
- achievement panel
- collection panel teaser

15-30 dakika:
- research lab
- daily goals
- offline gain modifier
- first synergy upgrade set

30-60 dakika:
- prestige preview
- prestige currency
- permanent nodes
- return bonus improvements

### 9.2 Unlock ağacı tasarım ilkeleri
- oyuncuya her an bir sonraki hedef gösterilmeli
- ama tüm sistemler bir anda açılmamalı
- her unlock kategorilerden birine hizmet etmeli:
  - güç
  - karar
  - merak
  - görünür değişim
  - yaşam kalitesi

### 9.3 Research tree örneği
Araştırma kolonları:
- Automation
- Burst Play
- Offline Growth
- Prestige Mastery
- Collection

Örnek node’lar:
- Auto Taps I
- Better Return Bonus
- Rare Event Chance +5%
- New Achievement Tier
- Building Visual Evolution
- Prestige Calculator

## 10. Event tasarımı
### 10.1 Event kategorileri
#### A. Random moment events
Örnek:
- Golden Spark
- Rush Hour
- Crit Storm

Özellikler:
- kısa süreli
- yüksek görünürlük
- düşük açıklama yükü
- anlık karar üretir

#### B. Return events
Oyuncu geri döndüğünde tetiklenir.

Örnek:
- Welcome Back bonus choice
- Top Producer spotlight
- Stored Heat bonus

#### C. Daily goals
Örnek:
- 50 kez tap yap
- 3 upgrade al
- 2 bina türünü unlock et
- 1 research tamamla

#### D. Weekend thematic events (post-MVP)
- geçici buff setleri
- kozmetik ödüller
- düşük FOMO, yüksek flavor

### 10.2 Event ilkeleri
- event’ler oyunun ana ekonomisini gölgelememeli
- event kazancı, normal oynanışı geçersiz kılmamalı
- event tetikleme görünür olmalı
- event kaçırma duygusu cezalandırıcı olmamalı

### 10.3 Dopamin/retention prensibi
Bu ürün kısa geri bildirim döngülerini kullanır ama baskılı bağımlılık mekaniklerinden kaçınır.

Bu yüzden:
- streak kaybı yok
- ceza tabanlı geri dönüş tasarımı yok
- sürekli alarm zorlaması yok
- “geri dönersen hoş bir şey var” mantığı var
- “gelmezsen kaybedersin” mantığı yok

## 11. Fonksiyonel gereksinimler
### FR-1 Oyun tek oyunculu ve offline çalışmalıdır.
### FR-2 Oyun kapanınca üretim zamanı kaydedilmeli ve dönüşte offline kazanç hesaplanmalıdır.
### FR-3 İlk açılışta en fazla 3 adımlı onboarding olmalıdır.
### FR-4 Kullanıcı en geç 60 saniye içinde ilk otomatik üretim varlığını satın alabilmelidir.
### FR-5 Home ekranı mevcut kaynak, üretim/saniye ve aktif hedefi aynı anda göstermelidir.
### FR-6 Shop ekranı bina bazlı ROI veya tavsiye etiketi gösterebilmelidir.
### FR-7 Upgrade ekranı bina ve global upgrade’leri ayrı gösterebilmelidir.
### FR-8 Session recap dönüşte otomatik açılmalı ve kapanabilir olmalıdır.
### FR-9 Prestige sistemi ilk sürümde aktif olmalıdır.
### FR-10 Research Lab ilk sürümde en az 12 node ile gelmelidir.
### FR-11 Random event sistemi ilk sürümde en az 3 event türü içermelidir.
### FR-12 Daily goals ilk sürümde en az 3 görev üretmelidir.
### FR-13 Oyuncu save export/import yapabilmelidir.
### FR-14 Rewarded ad izlenirse geçici buff verilebilmelidir.
### FR-15 Reklam kaldırma satın alımı kalıcı olmalıdır.

## 12. Fonksiyonel olmayan gereksinimler
### NFR-1 Performans
- orta sınıf cihazda 60 FPS hedefi
- ana ekranda frame drop hissedilmemeli
- tıklama yanıtı 100 ms altında olmalı

### NFR-2 Güvenilirlik
- save bozulması durumunda son güvenli save’e dönebilme
- versiyonlu migration

### NFR-3 UX
- portre kullanımda tek başparmakla ana aksiyon erişimi
- yazı kalabalığı kontrol altında
- büyük sayılar okunabilir biçimde gösterilmeli

### NFR-4 Analytics
İlk sürümde minimum analytics:
- tutorial completion
- D1/D7 retention
- first prestige time
- avg session length
- ad opt-in rate
- feature unlock funnel

### NFR-5 Erişilebilirlik
- titreşim kapatma
- düşük hareket modu
- metin ölçek seçenekleri
- renk körlüğüne dayanıklı event işaretleri

## 13. MVP kapsamı
### Dahil
- core tap loop
- 8 bina
- 30-40 upgrade
- 12 research node
- 3 random event
- 3 daily goal tipi
- 1 prestige currency
- 1 session recap modal
- 1 collection/achievement ekranı
- rewarded ad
- no-ads IAP
- local save

### Hariç
- cloud save
- sosyal özellikler
- canlı ops event sistemi
- çoklu meta kaynak
- complex minigame’ler
- sezon sistemi
- PvP / leaderboard
- A/B test paneli

## 14. MVP sonrası yol haritası
### Phase 2
- ikinci research kolu
- kozmetik tema sistemi
- bina görsel evrim animasyonları
- daha gelişmiş prestige node’ları

### Phase 3
- weekend events
- limited collection sets
- cloud save
- soft social sharing

## 15. Ölçüm planı
### Başarı metrikleri
- tutorial complete rate > %80
- first session length 8-15 dk
- D1 retention hedefi: %35+
- first prestige conversion > %45
- rewarded ad opt-in > %20
- session recap view-to-action rate > %50

### İzlenecek sorun metrikleri
- 10. dakikadan önce churn
- research unlock’a ulaşamayan kullanıcı oranı
- ilk prestige’i hiç görmeyen kullanıcı oranı
- shop ekranında yüksek abandon

## 16. Claude Code’a uygun repo ve çalışma standardı
Bu doküman yalnızca ürünü tanımlamaz; Claude Code ile üretilecek repoda nasıl çalışılması gerektiğini de belirler.

### 16.1 Repo sözleşmesi
Projede en az aşağıdaki dosyalar bulunmalıdır:
- `CLAUDE.md`
- `README.md`
- `docs/prd.md`
- `docs/economy.md`
- `docs/ux-flows.md`
- `docs/test-plan.md`
- `docs/telemetry.md`
- `docs/save-format.md`

### 16.2 CLAUDE.md içeriği
`CLAUDE.md` kısa ve operasyonel olmalıdır.

İçermesi gerekenler:
- proje amacı
- teknoloji stack’i
- çalıştırma komutları
- test komutları
- lint / typecheck komutları
- ana mimari kurallar
- state management kuralları
- ekonomi hesaplarının bulunduğu dosyalar
- save migration kuralları
- UI ve domain katman ayrımı
- hangi dosyalara dokunmadan önce plan mode istendiği

### 16.3 Geliştirme modu
Claude Code için önerilen görev tipi:
- önce keşif
- sonra plan
- sonra implementasyon
- sonra test ve rapor

Buna uygun iş emri formatı:
1. Problem
2. Scope
3. Affected files
4. Constraints
5. Verification
6. Output expected

### 16.4 Görev boyutlandırma
Claude Code’a verilecek görevler küçük ve doğrulanabilir olmalıdır.

İyi görev örnekleri:
- session recap modal UI ve state binding’ini ekle
- offline gain hesaplayıcısına test yaz
- prestige currency formülünü economy module içine taşı
- shop ekranına ROI etiketi ekle ve snapshot test yaz

Kötü görev örnekleri:
- oyunu bitir
- ekonomiyi düzelt
- UI’ı daha iyi yap

### 16.5 Dosya ve modül sınırları
Önerilen yapı:
```text
src/
  core/
    economy/
    progression/
    save/
    events/
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
```

Kurallar:
- ekonomi hesapları UI dosyalarında bulunmamalı
- progression unlock logic tek modülde olmalı
- save serialize/deserialize tek yerde tutulmalı
- temporary buff hesapları event modülünde kalmalı

### 16.6 Doğrulama standardı
Her task en az bir doğrulama yolu içermelidir:
- unit test
- integration test
- deterministic formula test
- golden snapshot
- manuel repro steps

“Bitti” tanımı:
- kod derleniyor
- ilgili testler geçiyor
- acceptance criteria karşılanıyor
- doküman gerekiyorsa güncelleniyor

### 16.7 Test öncelikleri
İlk günlerden itibaren testlenecek kritik alanlar:
- economy formulas
- prestige gain formula
- offline progress calculation
- upgrade prerequisite resolution
- save migration
- daily reset logic
- event spawn rules

### 16.8 Checkpoint ve riskli değişiklikler
Aşağıdaki değişiklikler tek task’ta yapılmamalı:
- save format değişikliği
- economy rebalance + UI refactor aynı anda
- prestige reset mantığı değişikliği
- event engine rewrite

Bunlar için önce plan ve etki analizi çıkarılmalı.

### 16.9 Session hygiene
- her oturum adı belirgin olmalı
- tek task = tek oturum tercih edilmeli
- context şişmesini azaltmak için task ortasında hedef değiştirilmemeli
- büyük refactor yerine dilimlenmiş teslimat yapılmalı

## 17. MVP sprint planı
### Sprint 0 - Kurulum ve iskelet
Hedef:
- repo oluştur
- state iskeleti kur
- routing/tab yapısı kur
- save envelope tanımla
- CLAUDE.md ve temel docs ekle

Teslimatlar:
- app boots
- boş ekranlar geçiş yapar
- local save read/write çalışır
- economy test altyapısı hazırdır

### Sprint 1 - Çekirdek loop
Hedef:
- tap üretimi
- kaynak sayacı
- production tick
- ilk 3 bina
- shop ekranı

Teslimatlar:
- oyuncu 5 dakika oynanabilir deneyim yaşar
- passive income devreye girer
- cost curve çalışır

### Sprint 2 - Upgrade ve hedef sistemi
Hedef:
- upgrade ekranı
- 15-20 upgrade
- next target paneli
- ROI önerisi

Teslimatlar:
- oyuncuya net hedef gösterilir
- satın alma kararı güçlenir

### Sprint 3 - Offline progress + session recap
Hedef:
- offline hesaplama
- geri dönüş özeti
- en iyi sonraki aksiyon önerisi

Teslimatlar:
- idle hissi gerçek anlamda oluşur
- re-entry friction düşer

### Sprint 4 - Event sistemi
Hedef:
- 3 random event
- event timer/state
- görsel event gösterimi

Teslimatlar:
- aktif oyuncu için spike pencereleri oluşur

### Sprint 5 - Research ve midgame
Hedef:
- research lab
- 12 node
- yeni sistem unlock akışı

Teslimatlar:
- orta oyun tekrar hissi azalır

### Sprint 6 - Prestige
Hedef:
- prestige hesaplama
- prestige ekranı
- kalıcı node’lar
- reset flow

Teslimatlar:
- oyuncu ikinci döngüye geçer

### Sprint 7 - Achievements + monetization + polish
Hedef:
- achievements
- rewarded ad entegrasyonu
- no-ads IAP
- settings
- performance polish

Teslimatlar:
- MVP store submission seviyesine gelir

## 18. Kullanıcı hikayeleri
### US-1
Bir oyuncu olarak ilk 1 dakika içinde oyun mantığını anlamak istiyorum ki oyunda kalıp kalmayacağıma hızlı karar verebileyim.

### US-2
Bir oyuncu olarak oyundan çıkınca da üretimin devam etmesini istiyorum ki geri dönmek anlamlı olsun.

### US-3
Bir oyuncu olarak sıradaki en mantıklı satın almayı görmek istiyorum ki kafa karışıklığı yaşamayayım.

### US-4
Bir oyuncu olarak zaman zaman aktif oynadığımda ekstra fayda görmek istiyorum ki sadece pasif bekleme hissi olmasın.

### US-5
Bir oyuncu olarak reset attığımda belirgin güç farkı görmek istiyorum ki prestige tatmin edici olsun.

## 19. Açık sorular
1. Ana tema gıda/cookie mi kalacak, yoksa yeni tema mı seçilecek?
2. MVP’de tek resource yeterli mi, yoksa ikinci resource erken mi açılmalı?
3. Rewarded ad kaç saatlik soğuma ile verilmeli?
4. Prestige için önerilen ilk reset zamanı ne olmalı?
5. Research node sayısı 12 mi 16 mı başlamalı?

## 20. Nihai ürün kararı
Bu ürünün başarısı yeni bir mekanik icat etmekten çok, aşağıdaki dört şeyi iyi yapmasına bağlıdır:
- hızlı anlaşılma
- net hedef görünürlüğü
- güçlü geri dönüş özeti
- orta oyunda kontrollü yenilik ritmi

MVP bunlara hizmet etmeyen hiçbir sistem eklememelidir.

