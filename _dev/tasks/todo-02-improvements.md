# Plan-02: Sonraki Geliştirmeler

**Tarih:** 2026-04-16
**Önceki plan:** `todo.md` (B kümesi docs tamamlandı)
**Çalışma modeli:** `superpowers:subagent-driven-development` (implementer → spec → quality)

---

## Kapsam ayrımı

"Geliştirmeler" kelimesi birden fazla yolu gösterir. Önce karar: **hangi yolu gideceğiz?**

### Yol 1 — Docs derinleştirme (zero infra, güvenli)
Kod yok, sadece doküman. Mevcut docs üzerindeki açık paramterelere detay ekler. Scaffold öncesi hâlâ değerli çünkü scaffold içeriğini bu dokümanlar besler.

### Yol 2 — Scaffold hazırlığı (doc seviyesi)
Scaffold PR'ı için blueprint dokümanları. Hâlâ kod değil — ama scaffold PR'ında "ne yazılacağı" tam tanımlı olur, scaffold saatler değil dakikalar sürer.

### Yol 3 — Gerçek Flutter scaffold (kod üretimi)
`pubspec.yaml`, `analysis_options.yaml`, `lib/` dizin iskeleti, ilk boot kodu, temel test setup. **Dikkat:** Flutter CLI local yüklü olmalı (`flutter pub get` çalışmalı), aksi halde scaffold doğrulanamaz. Ayrıca PRD §16.5 `src/` diyor ama Flutter convention `lib/` — bu governance kararı gerekir.

Önerim: **Yol 1 + Yol 2** paralel; Yol 3 ayrı bir oturum/PR (cihaz bağımlılığı var).

---

## Yol 1 — Docs derinleştirme görevleri

### D1. `docs/research-tree.md` — 12 node içeriği
- Her node için: ad, ön koşul, maliyet (R2), etki, hangi kolona (Automation/Burst/Offline/Prestige/Collection) ait.
- PRD §9.3 research kolonları + §9.1 unlock window + §13 "12 node".
- Ekonomi etkileri `docs/economy.md §11` tek parametre kaynağına bağlanır.
- **Ajan:** `game-designer`.
- **Doğrulama:** PRD §9.3 kolonları × ~2-3 node her birinde; 12 toplam; her node `unlock_id` `docs/telemetry.md §4.3` feature unlock funnel ile uyumlu.

### D2. `docs/economy.md` addendum — açık param setleri
B5 open questions:
- R2 (Research Shards) üretim mekanizması: hangi milestone'lardan ne kadar düşer?
- Prestige threshold artış eğrisi (2., 3., ... prestige için T_base sabit mi değişken mi?)
- Synergy upgrade maliyet/etki tablosu (her bina için 5 eşikte {10,25,50,100,200} multiplier değerleri)
- Buff stacking kuralı (çarpımsal mı toplamalı mı, cap var mı?)
- **Ajan:** `game-designer` (economy.md sahibi).
- **Doğrulama:** §11 balans parametre tablosu yeni satırlarla tutarlı; mevcut formüllerle çelişki yok.

### D3. `docs/upgrade-catalog.md` — 30-40 upgrade listesi (PRD §13)
- PRD §6.3'teki 6 upgrade tipi (global mult, bina mult, tap power, crit, offline, event spawn).
- Her upgrade: id, isim, etki tipi, etki değeri, maliyet, kategori, ön koşullar.
- İlk 20 upgrade Sprint 2 için yeterli; tümü lansman için.
- **Ajan:** `game-designer`.
- **Doğrulama:** 6 upgrade tipinden her birinden ≥3 örnek; prerequisite ağacı döngüsüz.

---

## Yol 2 — Scaffold blueprint görevleri

### S1. `docs/scaffold-plan.md` — Flutter scaffold exact spec
- `pubspec.yaml` içeriği (dependencies + dev_dependencies; versiyonlar pin).
- `analysis_options.yaml` içeriği (very_good_analysis veya lints paketi seçimi).
- Dizin yapısı: **PRD §16.5 `src/` → Flutter `lib/src/` olarak map edilecek mi, yoksa `lib/core/...` yapılacak mı?** Bu bölüm **karar kaydeder**.
- Stub dosya listesi: her modül için `// TODO` yorumlu minimum Dart dosyası.
- Entry point `lib/main.dart` içeriği (5-10 satır).
- **Ajan:** `general-purpose` (pattern-following, build tooling).
- **Doğrulama:** `flutter pub get` ile tutarlı pubspec; PRD §16.5 mapping kararı açık yazılı.

### S2. `docs/ci-plan.md` — CI platform seçim framework'ü + GitHub Actions template
- Platform adayları: GitHub Actions (öncelik), CircleCI, Codemagic (Flutter odaklı).
- Karar kriterleri: iOS build ihtiyacı (macOS runner), ücretlendirme, TestFlight/Play Store entegrasyonu.
- GitHub Actions YAML template (`analyze`, `test`, `build-ios`, `build-android` jobs).
- Coverage gate: `lcov` + threshold (`docs/test-plan.md §5`'teki hedefler).
- Golden diff zorunluluğu.
- **Ajan:** `general-purpose`.
- **Doğrulama:** `docs/test-plan.md §10.1` ile birebir uyum; coverage threshold'ları `§5`'teki tabloyla aynı.

### S3. `docs/visual-design.md` brief
- Tone/mood referansları (artisan/endüstriyel/galaktik 3 dönem için).
- Palet placeholder'ları (hex YOK, sadece sıcaklık/kontrast tanımı: "sıcak amber artisan için, cool steel endüstriyel, neon mavi galaktik").
- Tipografi adayları (Google Fonts veya fallback sistem font).
- İkon paketi tercih (`flutter_svg` ile custom SVG'ler mi, `phosphor_flutter` gibi hazır mı).
- Motion tonu (smooth + playful; easing eğrileri placeholder; süre ranges).
- **Ajan:** `art-director` (bu iş için en doğru ajan).
- **Doğrulama:** Hex renk yok; spec "tasarımcı briefi" seviyesinde; sonraki iterasyon için kilit sabitleyici değil.

---

## Yol 3 — Actual Flutter scaffold (önerim: ayrı PR / oturum)

Bu kısmı **bu oturumda yapmıyoruz** çünkü:
- Flutter CLI local test olmadan scaffold doğrulanamaz.
- `lib/` vs `src/` governance değişimi CLAUDE.md + PRD güncellemesi gerektirir (PRD §16.8 kapsamında riskli değişiklik ise plan mode zorunlu).
- Scaffold PR'ı CI kurulumu + TestFlight/Play credentials gibi DevOps adımlarını da tetikler.

**Sen onaylarsan** bunu ayrı bir oturumda, üstte yazılı S1+S2 blueprint'leri girdi olarak kullanarak açarız.

---

## Önerilen yürütme sırası

### Faz 1 — hemen başlayabileceğimiz (onay bekliyor)
Seri akış (skill'in paralel yasağı nedeniyle):
1. **D1** — `research-tree.md` (12 node, game-designer)
2. **D2** — `economy.md` addendum (4 açık param seti, game-designer)
3. **D3** — `upgrade-catalog.md` (30-40 upgrade, game-designer)
4. **S1** — `scaffold-plan.md` (general-purpose)
5. **S2** — `ci-plan.md` (general-purpose)
6. **S3** — `visual-design.md` brief (art-director)
7. **Final** — `CLAUDE.md §4` listesi yeni docs ile güncellenir; cross-ref audit.

### Faz 2 — sonraki oturum
Yol 3: Flutter scaffold PR'ı. S1+S2 blueprint girdi.

---

## Kararlar (2026-04-16 onaylı)

- [x] **Kapsam:** Yol 1 + Yol 2 — 6 doc task. Yol 3 ayrı oturum.
- [x] **Sıralama:** D1 → D2 → D3 → S1 → S2 → S3 → Final.
- [x] **Dizin mapping:** `lib/core/...` (Flutter convention). `CLAUDE.md §5` güncellendi; PRD §16.5 `src/` → `lib/` mapping'i belgelendi.
- [x] **Kaldırma yok.**

---

## Kabul kriterleri

- [ ] Her yeni doc PRD veya mevcut doc ile cross-ref kurarak yazılmış.
- [ ] Spec reviewer + quality reviewer her dokümanı yeşillendirmiş.
- [ ] `CLAUDE.md §4` yeni eklenen docs ile güncel.
- [ ] PRD'deki 4 açık MVP kapsamı (12 research node, 30-40 upgrade, visual style, scaffold topology) dokumentasyon seviyesinde kapatılmış.
- [ ] Scaffold PR'ı için engel kalmamış (governance + CI + tool chain ayarları netleşmiş).

---

## İnceleme (tamamlandı 2026-04-16)

### Tamamlanan kısım

- **D1-D3** (research-tree, economy addendum, upgrade-catalog) game-designer ile tamamlandı.
- **S1-S3** (scaffold-plan, ci-plan, visual-design) general-purpose + art-director ile tamamlandı.
- Her biri spec + quality review'dan geçti; identified issue'lar fix edildi.
- **Final cross-cutting audit** 13 dokümanı birlikte denetledi; tespit edilen Critical sorun: 4 eski doküman (economy, save-format, telemetry, test-plan) hâlâ PRD'nin abstract `src/core/` referansını kullanıyordu. Tüm suite'te global `src/core/` → `lib/core/` replace edildi. Stale "D2 addendum" referansları güncellendi. `README.md` + `docs/prd.md` yeni 5 dokümanla genişletildi. `flutter_animate` pubspec claim'i doğru biçimde "önerilir" olarak ayarlandı.

### Çıkan dosyalar

| Dosya | Satır | Ajan |
|-------|-------|------|
| `docs/research-tree.md` | ~312 | game-designer |
| `docs/upgrade-catalog.md` | ~344 | game-designer |
| `docs/economy.md` addendum | +291 (toplam ~803) | game-designer |
| `docs/scaffold-plan.md` | ~608 | general-purpose |
| `docs/ci-plan.md` | ~473 | general-purpose |
| `docs/visual-design.md` | ~355 | art-director |

### Yol 3 (gerçek Flutter scaffold) — ayrı oturumda

Scaffold PR'ı için tüm blueprint hazır. Planlama başladığında:
- `docs/scaffold-plan.md` tam spec (pubspec + dizin + stub içerikleri)
- `docs/ci-plan.md` GitHub Actions YAML'ları kopya-yapıştır hazır
- `docs/visual-design.md` tasarımcı briefi
- `CLAUDE.md §13` 7 tasarım kararı commit
- Tüm `lib/` path mapping tutarlı
