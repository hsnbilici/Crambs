# Project Crumbs

**30 saniyede öğren, 30 gün boyunca geri dön.** Mobil, offline-first bakery empire incremental oyun. Cookie Clicker'dan ilham almış, Flutter ile geliştirilmektedir.

## Durum

**Geliştirme öncesi.** Dokümantasyon tamamlanmış, scaffold henüz oluşturulmamıştır. Kod ve CI/CD ilk sprint'teki PR'lar tarafından kurulacaktır.

## Teknoloji

- **Framework:** Flutter (Dart)
- **State management:** Riverpod (tercih)
- **Persistence:** `path_provider` + JSON (MVP)
- **Test:** `flutter_test` (unit + widget) + `integration_test`
- **Platform:** iOS + Android

## Hızlı Başlangıç

```bash
# Scaffold sonrası eklenecek
# flutter pub get
# flutter run
# flutter test
```

Komut detayları `CLAUDE.md §3` bölümündedir; scaffold PR'ı sonrasında blok çalışır hale gelir.

## Dokümantasyon Haritası

Proje tüm gereksinimler ve teknik spec'i `docs/` dizininde tutar:

- **`cookie_clicker_derivative_prd.md`** — Ürün gereksinim dokümanı (tek gerçek kaynak)
- **`CLAUDE.md`** — Claude Code operasyonel rehberi; geliştirme akışı ve governance
- **`docs/prd.md`** — PRD stub; root'taki tam PRD'ye ve türetilen dokümanlara pointer
- **`docs/economy.md`** — Ekonomi formülleri, bina maliyetleri, balans parametreleri
- **`docs/ux-flows.md`** — 9 ekran akışı, navigasyon, UI/UX pattern'leri
- **`docs/save-format.md`** — Save şeması, JSON yapısı, migration stratejisi
- **`docs/telemetry.md`** — Analytics event kataloğu ve ölçüm planı
- **`docs/test-plan.md`** — Test stratejisi, coverage hedefleri, test case'leri
- **`docs/research-tree.md`** — 12 MVP research node kataloğu
- **`docs/upgrade-catalog.md`** — 36 MVP upgrade (6 etki tipi) listesi
- **`docs/scaffold-plan.md`** — Flutter scaffold blueprint (pubspec, lib/ iskelet)
- **`docs/ci-plan.md`** — GitHub Actions workflow şablonları
- **`docs/visual-design.md`** — Görsel kimlik briefi (artisan → endüstriyel → galaktik)

## Geliştirme Akışı

1. PRD'yi oku (`cookie_clicker_derivative_prd.md`)
2. `CLAUDE.md` rehberini incele (governance, stack, test beklentileri)
3. 3+ adımlı görevler için `_dev/tasks/todo.md` dosyasına plan yaz
4. Uygula (minimal change policy: sadece istenen değişiklikler)
5. Doğrula: testler geç, lint başarılı, build işler, diff incelendi

Detay için `CLAUDE.md §1–7` bakınız.

## Katkı

Pull request'ler `CLAUDE.md §10` plan mode kurallarına uymalıdır. Save format değişikliği, ekonomi rebalance + UI refactor aynı anda, prestige reset mantığı ve event engine rewrite **tek task'ta yapılmaz** — önce plan ve etki analizi çıkarılır, iş dilimlenerek teslim edilir.

## Lisans

TBD — Lisans kararı alınmamıştır.
