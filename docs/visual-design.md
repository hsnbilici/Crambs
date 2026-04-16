# Görsel Tasarım Brief — Project Crumbs

**Proje:** Project Crumbs
**Doküman tipi:** Sanat yönetmeni brief'i — kesin spec değil
**Yazar:** Sanat Yönetmeni
**Versiyon:** 0.1
**Tarih:** 2026-04-16
**Kaynak:** PRD §1, §6.1–6.9, §12 NFR-3/5; `docs/ux-flows.md` §9; `docs/economy.md` §4; `docs/scaffold-plan.md` §5

> Çelişki olduğunda PRD kazanır.
> Bu doküman bir Figma workshop'u veya tasarımcı oturumu için başlangıç noktasıdır;
> hex renk, piksel değeri veya kesin font adı içermez. Bunlar sonraki adımda kesinleştirilir.

---

## 1. Doküman Amacı ve Kapsam

Bu doküman Project Crumbs'ın görsel kimliğini **yönlendirmek** için yazılmıştır; kilitleyen bir spec değildir. Bir tasarımcı veya tasarım ekibi bu brief'ten başlayarak Figma'da token sistemi, komponent kütüphanesi ve asset rehberi oluşturabilir.

**Kapsam dahili:** Üç dönem görsel tonu, palet geçiş stratejisi, tipografi sistemi, ikon stratejisi, motion tonu, UI bileşen tarzı ve erişilebilirlik koruma kuralları.

**Kapsam dışı:** Hex renk değerleri, piksel ölçüleri, spesifik font adları ve lisanslar, asset pipeline detayları, animasyon curve tanımları, Flutter widget implementasyonu. Bu başlıklar ayrı bir görsel spec veya teknik sanat dokümanında ele alınır.

**Sonraki iterasyon:** Tasarımcı bu brief'i alıp Figma'da renk tokenları, tip skalası ve komponent taslakları oluşturur; ardından `lib/ui/theme/app_theme.dart` stub'ı (`docs/scaffold-plan.md §5`) bu kararlarla doldurulur.

---

## 2. Vizyon Cümlesi

Project Crumbs'ın görsel kimliği, sıcak ve davetkâr bir zanaat mutfağından başlayarak oyuncuyu kademeli biçimde büyük ölçekli bir endüstriyel operasyona, oradan da galaktik ölçekte hayal gücünün sınırlarını zorlayan bir fırın imparatorluğuna taşır. Her dönem kendi renk sıcaklığını, malzeme hissini ve animasyon ritmini taşır; oyuncu ekrana baktığında "hangi dönem"de olduğunu bilinçsizce fark eder, bunun için düşünmesi gerekmez. Görsel dil oyunu anlatır: küçük bir ocakta başlayan kor, zamanla yıldız yakıtına dönüşür. Fırın teması hiçbir zaman terk edilmez — sadece büyür, dönüşür ve soyutlanır.

---

## 3. Tema Dönemi 1 — Artisan

### Genel Mood

El yapımı, samimi ve küçük ölçekli. Bir mahalle fırınının ilk saatleri: un tozu, tereyağının kokusu, ahşap tezgah üzerinde şekillenen hamur. Her şey insan eliyle yapılmış gibi görünmeli; mükemmel değil, ama tam da bunun için sevimli.

### Renk Sıcaklığı

Sıcak amber, karamel kahverengi ve soluk krem baskın. Vurgular için yanmış tereyağı tonu veya koyu şekerpancarı kırmızısı kullanılabilir. Paletten uzak tutulması gereken renkler: soğuk metaller, neon parlamalar ve gri-mavi tonlar — bu dönemin sıcak dokusunu kırar.

### Doku ve Yüzey

Kağıt grain, hafif watercolor leke izi, elle kazınmış çizgi hissi. Görseller "baskı kalitesi mükemmel" değil, "zanaat defterine çizilmiş" gibi davranmalı. Küçük kusurlar — hafif fırça sürüklenmesi, düzensiz kenarlar — dönem kimliğinin parçasıdır.

### Tipografi Hissi

Ana başlıklar için insan yazımını hatırlatan slab serif veya humanist display. Harflerin uçlarında küçük el teması hissi olmalı; soğuk ve steril bir baskı görünümünden kaçınılmalı.

### UI Chrome

Yumuşak gölge, belirgin ama sert olmayan yuvarlak köşe. Kartlar sanki kalın bir mukavvaya yapıştırılmış gibi hafifçe üste çıkar; kenar çizgisi yok veya çok ince, neredeyse kağıt kıvırması.

### Oyuncunun Duygusu

Ev gibi, güvenli, keşfedilir. Oyuncu ilk açtığında yabancı hissetmemeli; "burası benim" diyebilmeli.

### Zaman Dilimi

Onboarding'den başlar, yaklaşık ilk 30 dakikalık oyunun karşılığıdır. Ekonomi tarafından belirlenmiş bina sıralamasına göre binalar 1–3 arası bu döneme aittir (Crumb Collector, Oven, Bakery Line — `docs/economy.md §4`).

---

## 4. Tema Dönemi 2 — Endüstriyel

### Genel Mood

Üretken, mekanik ve ritimli. Sayaçlar daha hızlı döner, bantlar akar, vagonlar gelir gider. Küçük fırından fabrikaya geçiş; el yapımının cazibesi yerini sistematik güce bırakmaya başlar. Ölçek kazanımı görsel dilden okunmalı.

### Renk Sıcaklığı

Soğuk çelik grisi baskın; lacivert ve koyu çivit vurgular için, fırçalanmış bakır ise sıcak aksanlar ve önemli eleman vurguları için. Artisan döneminin karamel tonu tamamen kaybolmaz — devralınan mirası hatırlatır — ama birincil sözlükten çıkar.

### Doku ve Yüzey

Metal fırçası, pergel çizgisi, isometrik diyagram stilizasyonu. Görseller "endüstriyel katalog" estetiğine yaklaşır; düz çizgiler, belirgin grid yapısı, doku yerini yapıya bırakmaya başlar.

### Tipografi Hissi

Geometrik sans; endüstriyel broadsheet, art deco fabrika afişi vibe'ı. Harfler daha disiplinli, daha az kişisel. Başlıklar daha büyük ve daha sert; aynı font ailesinin daha ağır ağırlıkları.

### UI Chrome

Daha keskin köşe. Kart gölgesi azalır; yerini flat + belirgin kenara bırakır. Dönem ilerledikçe satürasyon kademeli artar — dünya renklenmeye, ısınmaya değil netleşmeye başlar.

### Oyuncunun Duygusu

Güç kazanma, sistem inşa etme, makinenin dişlisi olma. Oyuncu artık bir usta değil; bir operatör, bir yönetici.

### Zaman Dilimi

Yaklaşık 30 dakika oynanış ile ilk prestige eşiğine (~45 dakika) kadar. Binalar 4–6 arası bu döneme aittir (Delivery Van, Franchise Booth, Factory Floor — `docs/economy.md §4`).

---

## 5. Tema Dönemi 3 — Galaktik

### Genel Mood

Dreamy, sonsuz ölçek, nadir enerji, yumuşak bilimkurgu. Artık bina değil; kozmik sistem. Rakamlar anlaşılmaz büyüklüğe ulaşır, ama oyun hâlâ fırın temasıyla konuşur — bu dönemdeki saçmalık kasıtlı ve sevimlidir. Hamur yoğuran drone'lar, yıldız enerjisiyle çalışan fırın portalleri. Ciddi değil, ama kendi içinde tutarlı.

### Renk Sıcaklığı

Neon magenta ve viyola vurgu renkleri; yıldızışığı fildişi ve derin kozmos laciverdinin üzerine oturur. Önceki dönemlerin renk belleği silinmez — amber artık yıldız yanmasına, çelik artık uzay metalleri korumasına dönüşür — ama baskın palet tamamen değişmiştir.

### Doku ve Yüzey

Gradient bloom, yumuşak parçacık efekti, nebula yıkama hissi. Formlar kesin sınırlarını kısmen yitirir; ışık yayılır, kenarlar parlar. Dijital ve soyut; organik değil.

### Tipografi Hissi

Geometrik sans devam eder; ama display başlıklar hafif italik ve "feral" bir enerji alır. Sanki rakamlar büyüklüğünden display karakterleri de etkilenmiştir.

### UI Chrome

Glow border orta yoğunlukta; fazlası okunabilirliği zedeler. Yumuşak bulanıklık backdrop'ta kullanılabilir; içerik kartı temiz kalmalı. Aşırı efekt yasaklı — görsel ses (visual noise) bu dönemin en büyük riski.

### Oyuncunun Duygusu

Transendens. "Küçük bir fırında başladım, artık evreni besleyen bir imparatorluk yönetiyorum." Saçmalığın bilinçli olduğu, ama kendisiyle tutarlı bir dünya.

### Zaman Dilimi

İlk prestige sonrasından endgame'e kadar. Binalar 7–8 bu döneme aittir (Drone Fleet, Portal Kitchen — `docs/economy.md §4`).

---

## 6. Palet Geçiş Stratejisi

### Geçiş Kararı: Chunk, Lerp Değil

Üç dönem arasındaki geçiş, oyuncunun fark edeceği kadar belirgin olmalıdır. Küçük adımlı, neredeyse fark edilmez bir renk geçişi (lerp) hem zayıf hem de anlamsız olur. Bunun yerine "chunk" geçişler: belirli bir eşiğe ulaşıldığında dönem değişir ve oyuncu bunu açıkça görür.

### Geçiş Tetikleyicileri

Geçişler economy.md §4'teki bina sırasına ve prestige eşiğine bağlıdır:

- **Artisan → Endüstriyel:** İlk prestige reset'inin tamamlanmasıyla UI chrome (tab bar rengi, arka plan tonu, kart stili) dönem 2'ye geçer. Ekonomik bağlam: binalar 4–6 bu noktada açılmaya başlar.
- **Endüstriyel → Galaktik:** İkinci prestige reset'inin tamamlanmasıyla dönem 3'e geçiş. Binalar 7–8'in görünür olduğu aşamaya denk gelir.

### Bina Görsel Tier'ı ile Uyum

Her binanın görseli kendi tema dönemine aittir (`economy.md §4` — Tema Dönemi sütunu). Bina 4 (Delivery Van) artık artisan dönemi çizgisiyle değil, endüstriyel stille çizilir. Böylece Shop ve Collection ekranlarındaki bina görselleri UI chrome'dan bağımsız biçimde kendi dönemlerini temsil eder; ikisi birlikte tutarlı bir evrim anlatısı kurar.

### Prestige Sonrası Görsel Kutlama

Prestige animasyonu (§9 Hero motion) geçişi dramatize etmeli; yeni dönem rengi "fade in" değil, "açılım" hissiyle gelmeli. Tasarımcı bu ani değişimin hem heyecan verici hem de aşırı gürültülü olmadığı bir çözüm bulmalıdır.

---

## 7. Tipografi Sistemi

### Üç Slot

MVP için tipografi üç işlevsel slotta düşünülür. Tek bir font ailesi üç ağırlık ve uygun bir tabular varyantla bu üç slotu doldurabilir; dönem-spesifik font değiştirme opsiyoneldir.

| Slot | İşlev | Dönem 1 (Artisan) | Dönem 2–3 |
|---|---|---|---|
| Display | Başlıklar, event banner'lar, büyük vurgu | Humanist slab serif veya humanist display; el yazısı tını | Geometrik sans; daha sert, daha disiplinli; galaktikte hafif italic |
| Body | Okunabilir gövde metni, açıklamalar, liste öğeleri | Okunabilir geometric veya humanist sans | Tüm dönemlerde aynı aile; ölçek değişebilir, aile değişmez |
| Numeric | Büyük sayaçlar, maliyet değerleri, üretim hızı | Tabular-figures zorunlu — sayaç titremesin | Tabular-figures zorunlu; monospace flavour veya tabular variant |

### Tabular Figures Zorunluluğu

Sayaç sürekli güncellenirken rakamlar genişlik değiştirmemeli; layout oynaması hem görsel rahatsızlık hem de erişilebilirlik sorunudur. Numeric slotta seçilen font veya variant tabular figures (sabit genişlikli rakamlar) desteklemelidir.

### Hiyerarşi Ölçeği

Büyük / orta / küçük şeklinde göreli bir skala yeterli. Kesin piksel değerleri Figma aşamasında belirlenir ve sistem font scale ile esnemelidir (§11 erişilebilirlik kuralı).

### MVP Font Kaynağı

Google Fonts üzerinden seçim yapılması tercih edilir — Flutter'da `google_fonts` paketi mevcuttur, ancak offline cache davranışı dikkatle test edilmelidir. Kritik fontların bundled assets olarak paketlenmesi daha güvenlidir. Lisans ve bundle kararı tasarımcı + geliştirici ortaklaşa verir; bu brief yön verir, kilitlemez.

---

## 8. İkon Stratejisi

### Genel Stil

Line-based + soft fill blend. İkonlar katı outline değil; dönem tonuyla yumuşak bir içsel dolgu alır. Stroke ağırlığı orta, uç kapakları yuvarlak. Tüm dönemlerde aynı stroke karakteri korunur; renklenme ve içsel dolgu tonu dönemle değişir.

### UI Utility İkonlar (Tab Bar, Settings, Geri, Vb.)

Mevcut bir paket ikon kütüphanesi yeterlidir. Önerilen: `phosphor_flutter` (6 stil varyantı, MIT lisans, tutarlı grid). Alternatif: `lucide_icons` (temiz, minimal). Paket seçimi performans ve lisans açısından geliştirici ile birlikte onaylanmalıdır.

### Custom Illustrated Görseller

Binalar, event kartları ve achievement görsel ödülleri kesinlikle custom illustrated olmalıdır. Paket ikonları bu alanda yetersiz kalır; dönem diliyle, dokuyla ve fırın temasıyla konuşan özgün görseller gereklidir. Bu, MVP'nin görsel bütçesindeki en kritik üretim kalemidir.

### Siluet Okunabilirliği

Tüm bina görselleri küçük boyutta (shop listesi, collection albümü) siluet düzeyinde tanınabilir olmalıdır. Bir bina, rengi kaldırıldığında dahi diğerinden ayırt edilmelidir. Bu kriter collection ekranındaki bina evrim görselleri için de geçerlidir (`ux-flows.md §5.7`).

### Animasyon

Tap, unlock ve satın alma micro-interaction'larında spring easing ile hafif ölçek darbesi. İkon animasyonu öne çıkan bir element değil; doğal bir dokunuş yanıtıdır.

---

## 9. Motion Tonu

### Üç Katman

**Micro (dokunuş yanıtı):** Kısa, yaylı, anlık. Buton basımı, tap feedback, satın alma onay flash'ı. Süre aralığı kısa; kullanıcı hareketi hissetmeden önce hareket başlayıp biter. Hafif ölçek darbesi — küçülüp normale döner. Flutter'ın yerleşik easing'i (`Curves.easeOutBack`) bu katman için yeterlidir.

**Macro (ekran geçişi ve modal):** Orta hız. Fade + yukarı kalkış hareketi; ekranlar arası geçişlerde zemin değişimini fark edilir kılar ama oyuncuyu bekletmez. Tab geçişleri, modal aç/kapat, bottom sheet animasyonu bu katmandadır. Aşırı animasyon burada oyunun akıcılığını kırar.

**Hero (prestij anı, session recap sayacı):** Uzun, sahneli, keyif odaklı. Prestige animasyonu ve Session Recap'taki kaynak sayaç animasyonu bu kategoridedir. Süre üst sınırı: 1,5 saniye — `ux-flows.md §6.2` bu süreyi hard cap olarak tanımlar. Animasyon süreci kullanıcıyı kilitlemez; "Kapat" her zaman aktiftir.

### Low-Motion Mode

`ux-flows.md §9.4` tanımına uygun: sistem düzeyinde `prefers-reduced-motion` algılanır veya Settings'te oyuncu manuel açar. Bu mod aktifken:
- Macro ve Hero animasyonlar cross-fade'e indirgenir; hareket bileşeni kaldırılır.
- Süre yaklaşık yarıya iner.
- Micro animasyonlar dokunulmaz — dokunuş yanıtı her zaman aktiftir.

### Easing Kütüphanesi

Flutter'ın yerleşik `Curves.easeOutCubic` ve `Curves.easeOutBack` MVP için yeterlidir. Daha karmaşık sahneli Hero animasyonlar için `flutter_animate` paketi (`pubspec.yaml`'da mevcut — `docs/scaffold-plan.md §3`) kolaylaştırıcıdır.

---

## 10. UI Bileşen Tarzı

Dönem içindeki tüm bileşenler o dönemin stilistik sözleşmesine uymalıdır. Aynı ekran içinde farklı dönem stilini taşıyan bileşenler yalnızca kasıtlı dramatik bir amaçla (örneğin prestige geçiş ekranı) kullanılabilir.

### Primary Button

| Dönem | Tarz |
|---|---|
| Artisan | Yumuşak köşe, dolgu rengi sıcak; hafif gölge; "elle yapılmış" hissi |
| Endüstriyel | Daha keskin köşe, belirgin kenar çizgisi; daha az gölge; güçlü, doğrudan |
| Galaktik | Glow border orta yoğunlukta; içsel dolgu gradient; parlaklık ölçülü |

### Kart (Card)

| Dönem | Tarz |
|---|---|
| Artisan | Katmanlı gölge, sıcak arka plan, hafif doku hint'i |
| Endüstriyel | Flat yüzey, belirgin border; grid hissi |
| Galaktik | Gradient dolgu veya yarı-saydam; yumuşak blur backdrop; glow kenar opsiyonel |

### Tab Bar

Persistent; tüm dönemlerde aynı konumda, aynı işlevde. Aktif sekme göstergesi (indicator) dönemin vurgu rengiyle işaretlenir. Tab bar'ın arka plan tonu prestige geçişiyle birlikte dönem değiştirir (§6 geçiş stratejisi).

### Modal ve Backdrop

Tüm dönemlerde yumuşak backdrop blur. İçerik kartı, hangi dönemde açılırsa o dönemin kart stilini taşır. Session Recap modal'ı (`ux-flows.md §5.9`) özellikle hero motion ile uyumlu olmalıdır.

### Büyük Sayı Biçimi

PRD §12 NFR-3 ve `ux-flows.md §9.2` gereksinimine göre: Settings'ten seçilebilen biçim (örn. `1.5K / 1.5M / 1.5B / 1.5T` veya `aa/bb`). Sayı biçimi UI bileşeni olarak tüm ekranlarda tutarlı davranmalıdır; değiştirildiğinde anlık güncellenir. Numeric slotun tabular figures zorunluluğu burada kritiktir.

---

## 11. Erişilebilirlik Koruma Kuralları

Bu bölüm `ux-flows.md §9.5` ile senkrondur ve sanat kararlarında erken aşamadan itibaren gözetilmelidir. Erişilebilirlik sonradan eklenen bir katman değil, her görsel kararın parçasıdır.

### Renk Körlüğü Uyumu

Kritik görsel bilgi hiçbir zaman yalnızca renge dayandırılmamalıdır. Aşağıdaki her eleman renk + şekil + ikon + metin arasından en az ikisini kullanmalıdır:

- **Event marker'lar** (`ux-flows.md §5.5`): renk + ikon + etiket üçlüsü zorunlu.
- **Achievement tamamlanma:** tik ikonu + renk değişimi + metin.
- **Buff göstergeleri** (Home ekranı): ikon + kalan süre metni.
- **ROI etiketi** (Shop): ikon + "Önerilen" etiketi + renk; renk tek taşıyıcı değil.
- **Session Recap CTA'ları:** her buton ikon + etiket ile ayrıştırılır.
- **Achievement tier'ları** ve **koleksiyon sınıflandırmaları:** şekil veya desen farkı rengin yanında kullanılır.

### Kontrast

WCAG AA standardı minimum eşiktir:
- Metin ve arka plan arası: 4,5:1
- Büyük metin (display, büyük sayı görüntüleri): 3:1

Dönem palet seçimlerinde bu eşikler tasarımcı tarafından Figma'da kontrol edilir. Özellikle Galaktik dönemin glow ve gradient kararlarında düşük kontrast riski en yüksektir.

### Font Ölçeği Esnekliği

Sistem font scale %200'e kadar layout'u kırmamalıdır. Sayılar ve etiketler taşacak biçimde sabit kutu içine yerleştirilmemelidir. Flutter'ın `MediaQuery.textScaleFactor` davranışı komponent düzeyinde test edilmeli; bu brief ekran boyutlarını kilitlemediğinden layout stratejisi Figma aşamasında ve implementasyon sırasında birlikte çözülür.

### Low-Motion

§9'da tanımlanan low-motion kuralları erişilebilirlik gereksinimidir; estetik tercih değil. Sistem `prefers-reduced-motion` sinyali alındığında animasyon davranışı otomatik değişmelidir.

---

## 12. Referans Ruh Hali (Mood Board Yönlendirmesi)

Link verilmez; anahtar kelimeler üzerinden yönlendirme yapılır. Tasarımcı kendi görsel araştırmasını yapar; bu listeler başlangıç noktasıdır.

### Dönem 1 — Artisan

- "artisan bakery illustration"
- "cozy cafe branding hand drawn"
- "sourdough bread packaging design"
- "small batch bakery typography"

Kaçınılacak: steril white-label "foodtech" estetiği, fazla temiz vektör.

### Dönem 2 — Endüstriyel

- "art deco factory poster"
- "mid-century industrial design"
- "modernist broadsheet typography"
- "stamped metal badge industrial"

Kaçınılacak: steampunk klişesi, aşırı çark ve dişli görselleri.

### Dönem 3 — Galaktik

- "solarpunk celestial illustration"
- "dreamy nebula illustration pastel"
- "cosmic bakery absurdism"
- "soft sci-fi game UI glow"

Referans görsel: uzay gemisinde hamur yoğuran astronotlar — galaktik dönemi hem fırın tematizasyonunu hem de dönemin soyut ölçeğini yakalayan bir imge olarak düşünülebilir.

Kaçınılacak: ağır cyberpunk karanlık estetiği; dönem dreamy ve yumuşak, distopik değil.

---

## 13. Bu Doküman Ne Değildir

| Konu | Nerede Bulunur |
|---|---|
| Hex renk paleti ve token tablosu | Figma — tasarımcı kesinleştirir |
| Spesifik font adı ve lisans kararı | Figma + `pubspec.yaml` — tasarımcı + geliştirici |
| Asset pipeline ve export spec | Ayrı teknik sanat dokümanı |
| Motion timing kesin spec | `flutter_animate` implementasyonu sırasında kesinleşir |
| Animation curve tanımları | Implementasyon sırasında playtest ile kalibre edilir |
| Flutter widget implementasyonu | `lib/ui/theme/app_theme.dart` stub — `docs/scaffold-plan.md §5` |
| Shade/tint algoritması | Teknik sanatçı / Flutter tema sistemi |
| Şekil/ikon dosya adları ve yolları | Asset pipeline dokümanı |
| UI animasyon easing tanımı (tam) | Motion spec (ayrı doküman) |
| Dokunmatik hedef boyutu ve odak göstergesi | `docs/ux-flows.md §9.1` |

---

## Açık Sorular (Tasarımcıya)

Aşağıdaki kararlar bu brief kapsamında bilerek açık bırakılmıştır. Figma workshop'unda veya tasarımcı oturumunda yanıtlanmalıdır.

1. **Dönem geçiş görseli:** Prestige animasyonu sırasında dönem tonu değişimini nasıl dramatize edeceğiz? Renk patlaması mı, gradual wash mı, başka bir sinematik araç mı?
2. **Tek aile mi, dönem-spesifik font mu?** Display slotunda her dönem için ayrı font ailesi mi kullanılacak (daha güçlü dönem farkı, daha karmaşık yönetim) yoksa tek aile × farklı ağırlık/stil mi (daha sade, daha tutarlı)?
3. **Bina görsel evrim:** Her bina için kaç görsel tier gereklidir? Synergy eşikleri (`economy.md §4.1`) görsel değişimi tetikler mi, yoksa yalnızca prestige dönemlerinde mi değişir?
4. **Dark mode:** MVP'de dark mode desteklenecek mi? `app_theme.dart` stub'ı hem `light` hem `dark` tanımlıyor — ama görsel brief bu ayrımı henüz ele almadı.
5. **Galaktik glow yoğunluğu:** Glow efektinin erişilebilirlik eşiklerini (kontrast) karşılarken dönem atmosferini yeterince iletmesini sağlayan referans bir UI örneği bulunabilir mi?
6. **Onboarding görsel sesi:** Artisan döneminin el yapımı dokusu onboarding'de ne kadar yoğun? Çok fazla doku yeni oyuncuyu bunaltabilir; ne kadar "yalın" başlanmalı?
7. **Custom illustration kapsamı:** MVP'de kaç bina görseli tam illüstrasyon olarak üretilecek? Kalan slotlar için hangi placeholder stratejisi kullanılacak?
