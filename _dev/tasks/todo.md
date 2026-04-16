# Plan: CLAUDE.md açık alanlarını kapat

**Bağlam:** `CLAUDE.md` üç açık bölümle oluşturuldu — §2 Tech stack (TBD), §3 Komutlar (scaffold sonrası), §13 PRD §19 açık soruları. Bu plan hangilerinin otonom kapanabileceğini, hangilerinin insan kararı beklediğini ayırır ve her otonom task için uygun agent'ı önerir.

**Çalışma modeli:** `superpowers:subagent-driven-development` — her task için implementer → spec reviewer → code quality reviewer akışı.

---

## A. İnsan kararı gerektiriyor

- [x] **A1. Tech stack: Flutter** (2026-04-16)
  - Gerekçe: iOS+Android tek codebase, idle oyun için yeterli performans, Dart öğrenme eğrisi düşük. Unity overkill; RN game tick performans riski.
  - Etki: `CLAUDE.md §2` Flutter ile güncellenecek; §3 komutları Flutter/Dart'a göre doldurulacak (`flutter run`, `flutter test`, `dart analyze`, `flutter build`).

- [x] **A2.1. Tema: Bakery empire, premium execution** (2026-04-16)
  - Gerekçe: Bina isimleri zaten cookie/bakery evreninde (Crumb Collector → Portal Kitchen); "Project Crumbs" ismi commit edilmiş.
  - Evrim arcı: **artisan → endüstriyel → galaktik fırın imparatorluğu**. Prestige her seferinde scale'i büyütür — doğal dopamin ritmi.
  - Etki: Art direction briefi bu üç dönemi kapsar; bina visual tier'ları (`BuildingState.levelVisualTier`) bu scale'e göre planlanır.

- [x] **A2.2. MVP'de tek kaynak (R1)** (2026-04-16)
  - Gerekçe: Erken çift kaynak onboarding'i karmaşıklaştırır. R2 (Research Shards) PRD §9.1'deki 15-30 dk window'da açılır.
  - Etki: `docs/economy.md` R1'e odaklanır; R2/R3 "mid/late game" başlıklarında tanımlanır.

- [ ] **A2.3-5. Kalan 3 balancing sorusu — PRD default'ları öneriliyor:**
  - **A2.3 Rewarded ad cooldown:** **4 saat** öneri. Idle oyunlarda standart; rahatsız etmez, değerli hissettirir. Playtest sonrası ayarlanır.
  - **A2.4 İlk prestige zamanı:** **~45 dk** öneri (PRD §8.3 "30-60 dk" aralığının ortası). Prestige formülü ilk run ~45 dk'da 2-3× kalıcı multiplier verecek şekilde kalibre edilir.
  - **A2.5 Research node sayısı:** **12** (PRD §13 MVP scope açıkça 12 diyor). 16'ya çıkmak MVP kapsam genişlemesi olur; Phase 2'de ikinci kol (§14) eklenir.
  - Bu üçü playtest-driven sayılar; varsayılanlarla başlayıp `docs/economy.md`'de sabitleyelim mi?

> **Not:** A tamamlanmadan B kısmen yapılabilir; ancak `docs/economy.md` içindeki sayısal parametreler A2'ye bağımlıdır. Ben B'yi "stack/karar-agnostik" kısımlarıyla başlatıp, kararlar gelince parametre tamamlama geçişi yaparım.

---

## B. Otonom tamamlanabilir (PRD'den türetilecek)

Sıra önemli: bağımsız olanlar paralel gönderilebilir, ama skill "parallel implementation subagents yasak" diyor → seri gideceğim.

- [ ] **B1. `docs/save-format.md`** — PRD §7.8 (SaveEnvelope + migration kuralları) teknik spec.
  - Ajan: `general-purpose` (teknik, tarafsız dökümantasyon)
  - Kapsam: envelope şeması, version alanı, checksum algoritması seçimi (öneri), migration idempotency kuralı, corrupted save recovery akışı.
  - Doğrulama: PRD §7.8 maddeleri 1:1 karşılanıyor, `CLAUDE.md §8` ile çelişki yok.

- [ ] **B2. `docs/telemetry.md`** — PRD §12 NFR-4 + §15.
  - Ajan: `general-purpose`
  - Kapsam: event listesi (tutorial_complete, session_start, first_purchase, first_prestige, ad_opt_in, funnel_step_*), alan şemaları, D1/D7 retention tanımları, sorun metrikleri (§15), PII yasakları.
  - Doğrulama: PRD §12/§15 metriklerinin tamamı event'lerle eşleniyor.

- [ ] **B3. `docs/test-plan.md`** — PRD §16.6-16.7.
  - Ajan: `general-purpose`
  - Kapsam: test piramidi (unit / integration / golden / manuel), kritik alanlar (economy formulas, prestige, offline progress, upgrade prerequisites, save migration, daily reset, event spawn), "bitti" tanımı, coverage hedefi.
  - Doğrulama: PRD §16.7 listesinin her maddesine karşılık gelen test stratejisi var.

- [ ] **B4. `docs/ux-flows.md`** — PRD §6.
  - Ajan: `uiux-designer` (ekran akışları ve UX konusunda uzmanlaşmış)
  - Kapsam: 9 ekranın her biri için giriş/çıkış akışları, navigasyon haritası (tab bar + modals), first-run onboarding akışı (FR-3), session recap trigger akışı (FR-8), erişilebilirlik notları.
  - Doğrulama: §6.1-6.9'daki kabul kriterleri akışlarda görünüyor.

- [ ] **B5. `docs/economy.md`** — PRD §8.
  - Ajan: `game-designer` (ekonomi tasarımı ve GDD uzmanı)
  - Kapsam: 3 kaynak (R1/R2/R3), üretim akışı, cost curve formülasyonu (`cost(n) = baseCost × growthRate^owned`), çarpan katmanları (§8.6), aktif/pasif oyun dengesi, prestige çıktıları (§8.8), monetization sınırları (§8.9). A2 kararı beklenen parametreler `TBD` ile işaretlenir.
  - Doğrulama: §8 alt başlıkları tam karşılanıyor, §8.9 yasakları açıkça listelenmiş.

- [ ] **B6. `docs/prd.md`** — Root'taki `cookie_clicker_derivative_prd.md` dosyasına relative symlink veya 1-satırlık stub (symlink mobil build sistemlerinde sorun yaratabilir, önce stub deneyeceğim).
  - Ajan: Doğrudan ben yaparım (trivial, agent aşırı).
  - Doğrulama: `docs/prd.md` ile root PRD tek gerçek kaynak olmaya devam eder.

- [ ] **B7. `README.md`** — Kısa proje özeti.
  - Ajan: `general-purpose`
  - Kapsam: proje adı, bir paragraflık tanım, stack placeholder, "Geliştirme" için `CLAUDE.md` yönlendirmesi, PRD'ye link.
  - Doğrulama: 80 satırdan kısa, komut blokları `CLAUDE.md §3` ile senkron.

---

## C. Stack kararı sonrası (ertelendi)

- [ ] **C1.** `CLAUDE.md §3` komutlarını doldur (A1 sonrası).
- [ ] **C2.** Repo scaffold (`src/core/*`, `src/features/*`, `src/ui/*`, `src/app/*`).
- [ ] **C3.** Test altyapısı + CI hooks.

---

## Önerilen yürütme sırası

1. **Şimdi beklenen onay:** B1 → B7 akışını subagent-driven başlatmama izin ver.
2. **Paralel:** Sen A1 (stack) + A2 (5 açık soru) üzerine düşün; cevaplar gelince ekonomi parametreleri ve komut bloğu kapanır.
3. B bitince: final code-reviewer tüm doc setini kontrol eder, `CLAUDE.md §4` listesi güncellenir.

## Kabul kriterleri

- [ ] PRD §16.1'deki 8 zorunlu dosyanın 6'sı (prd.md dahil) oluşturuldu (save-format, telemetry, test-plan, ux-flows, economy, prd + README)
- [ ] Her doc PRD'deki ilgili bölümle 1:1 izlenebilir (spec reviewer onayı)
- [ ] Her doc code-quality reviewer onayından geçti
- [ ] `CLAUDE.md §4` güncel durum ile senkron
- [ ] Hiçbir doc PRD'yi tekrarlamıyor; sadece operasyonel detay ekliyor

## İnceleme (tamamlandı 2026-04-16)

### Tamamlanan kısım

- **A1** (Flutter stack) ve **A2.1/A2.2** (bakery tema + tek resource MVP) sen verdin.
- **A2.3/A2.4/A2.5** için PRD-hizalı default'lar önerildi ve onaylandı (4h ad cooldown, ~45dk prestige, 12 node).
- **B1-B7** subagent-driven olarak tamamlandı: her biri implementer → spec reviewer → code-quality reviewer akışıyla, reviewer'ın açtığı issue'lar fix edildi.
- **B6** (`docs/prd.md` stub) trivial olarak doğrudan yazıldı.
- **Cross-doc senkronizasyon:** B4 quality review'u sırasında `session_recap_action_taken` için `action_type: "collect"` ihtiyacı ortaya çıktı — `docs/telemetry.md §4.7` ve `docs/ux-flows.md §6.2` birlikte güncellendi.
- **Final:** `CLAUDE.md` §3 (Flutter komutları), §4 (doc listesi check'li), §13 (5 karar kayıtlı) güncellendi.

### Çıkan dosyalar

| Dosya | Satır | Kaynak PRD bölümü |
|-------|-------|-------------------|
| `docs/save-format.md` | ~305 | §7.8 + §16.6-8 |
| `docs/telemetry.md` | ~275 | §12 NFR-4 + §15 |
| `docs/test-plan.md` | ~265 | §16.6-7 + §12 NFR |
| `docs/ux-flows.md` | ~725 | §6 (9 ekran) + §9 + §FR-3/4/8 + §NFR-3/5 |
| `docs/economy.md` | ~515 | §8 + §9.1 + §10 |
| `docs/prd.md` | ~15 | (stub) |
| `README.md` | ~56 | (özet) |

### Açık bırakılan, sonraki task'larda çözülecek

- **C1:** Scaffold PR → `CLAUDE.md §3` komutları canlı hale gelir, CI platformu seçilir.
- **Ekonomi detayları** (B5 open questions): R2 Research Shard üretim miktarları, prestige threshold artış eğrisi, synergy upgrade maliyeti/etkisi, buff stacking kuralı — ayrı doc task'larında.
- **Research node içeriği** (12 node'un ekonomik etkisi): Sprint 5 öncesi `docs/research-tree.md` veya `economy.md` addendum.
- **B4 UX açık soruları:** Research Lab iptal refund? No-ads IAP + rewarded ad buff kart etkileşimi? More sekmesi navigasyon tipi (push vs sheet)? — implementation task'larında kararlaştırılacak.

### Gözlem

- Skill'in 300-450 satır ux-flows hedefi 9 ekran × 6-parça şablon için yapısal olarak yetersizdi — 719 satıra ulaşıldı, bloat değil structural zorunluluk.
- Spec reviewer 2 kez (B1, B2, B3, B5) ve 1 kez (B4, B7) fix round ile yeşile geçti — ortalama çevrim hızlı.
- Tüm cross-ref'ler doğrulandı, telemetry event adları docs arasında tutarlı.
