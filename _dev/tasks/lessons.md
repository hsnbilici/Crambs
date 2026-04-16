# Dersler

Bu dosya tamamlanmış planların ardından çıkan tekrarlanabilir derslerdir. Yeni plan başlatmadan önce oku; aynı kırılmayı tekrar etme.

Geçmiş planlar (tümü tamamlandı, git history'de):
- `docs: add complete pre-scaffold documentation suite` (commit `1da9c53`) — B1-B7 zorunlu 7 doc
- `scaffold(D1)...(S3)` — 6 ek doc (research-tree, upgrade-catalog, vb.)
- `scaffold(T1)...(T9-fix-2)` — Flutter scaffold PR (14 commit)

---

## Spec drift — spec tek gerçek kaynağıysa iki noktayı birden güncelle

**Olay:** scaffold-plan.md §4 `missing_return: error` kuralını pin ediyordu, post null-safety'de bu kural kaldırılmış. Aynı şekilde §4 linter.rules'da very_good_analysis varsayılanlarını duplicate ediyordu. Üretilen `analysis_options.yaml` spec'e harfi harfine uyunca `flutter analyze` uyarı üretti.

**Kök neden:** Doc yazan agent spec yazarken runtime doğrulama yapmadı; implementer agent spec'e bire bir uydu ve sorunu içerdi.

**Kural:** Spec + kod aynı satırı taşıyorsa, bir tarafı düzeltirken diğerini aynı commit'te güncelle. "Spec drift" olarak PR review'larda ilk taranan kategorilerden.

**Nasıl uygulanır:** Reviewer "spec drift" diyorsa önce spec dosyasını açıp düzelt, sonra kod tarafında replace_all çalıştır. Ayrı commit açma — `scaffold(TX-fix)` tek commit.

---

## Import sırası — very_good_analysis `directives_ordering` alfabetik

**Olay:** T6'da `lib/main.dart` spec'ten geliyordu; `package:flutter/...` → `package:crumbs/...` yazılıydı. very_good_analysis alfabetik sıra istiyor — `crumbs` < `flutter` olduğu için sıra ters.

**Kural:** Dart import blokları alfabetik sıralanır. Third-party paketler arasında bile: `package:crumbs/` önce, `package:flutter/` sonra gelir. `dart:*` importları en üstte ayrı blok.

**Nasıl uygulanır:** Yeni Dart dosyası yazarken `dart format` çalıştırmadan bile alfabetik yazmak yeterli. `flutter analyze` zaten kuralı yakalar.

---

## Flutter versiyon pin ≠ local Flutter

**Olay:** scaffold-plan.md §2 `flutter-version: '3.27.0'` pin ediyor; `.fvm/fvm_config.json` aynısı. Local Flutter 3.41.5 → analyzer 7.6.0 → pinned `custom_lint ^0.7.0` ile breaking change. `dart run build_runner` compile hatası aldı.

**Kök neden:** FVM kurulu değildi; local Flutter pin'den farklı sürüm. Scaffold versiyonuna kalibre edilmiş dev deps newer analyzer ile uyumsuz.

**Kural:** Flutter pin varsa lokal geliştirme FVM ile yapılmalı. `fvm install <pin> && fvm use <pin>` scaffold PR'ın öncesinde çalıştırılır. CI'da otomatik — local'de manuel.

**Nasıl uygulanır:** CLAUDE.md §3 komut bloğu FVM öneriyor; yeni dev onboarding scriptinde `fvm install` zorunlu adım olarak ekle.

---

## freezed / riverpod_generator — build_runner sırası sabittir

**Olay:** `save_envelope.dart` + 2 controller dosyası `part '*.freezed.dart'` / `part '*.g.dart'` direktifleri içeriyor. Fresh clone'da bu dosyalar yok; `flutter analyze` direkt hatalar verir.

**Kural:** Flutter codegen ile yazılan projelerde fresh clone sırası: `pub get → dart run build_runner build → flutter analyze → flutter test`. Bu sıra her ortamda korunmalı (local dev, CI, PR review).

**Nasıl uygulanır:** CI workflow'ların her birinde `Kod üretimi` adımı `Statik analiz`'den önce. `docs/ci-plan.md §5-7` şablonları bunu sağlıyor. Lokalde de aynı.

**Not:** `*.g.dart` ve `*.freezed.dart` `.gitignore`'da. Analyzer bunları dosya sistemi seviyesinde bulamadığı için `uri_does_not_exist` verir — codegen öncesi normal davranış, panik yok.

---

## Scaffold'da `flutter create` bypass — her dosya spec'ten manuel

**Olay:** `flutter create` template boilerplate üretiyor (counter app, widget_test vb.). Bunlar scaffold-plan §6'dan sapıyor. Manuel yazım spec'e bire bir uyum sağlar.

**Kural:** Scaffold PR'da `flutter create` ÇALIŞTIRMA. Dizin yapısı + tüm dosya içerikleri spec dokümanından gelir. `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart` elle yazılır.

**Nasıl uygulanır:** Yeni scaffold / re-scaffold ihtiyacı çıkarsa önce spec dokümanını doğrula, sonra 8 task'lık subagent-driven-development ile elle üret. `flutter create` yalnızca platform-spesifik dosyalar gerektiğinde (`android/`, `ios/` klasörleri) kısmi kullanılır.

---

## Subagent-driven review loop — 2 aşama zorunlu

**Olay:** T1-T9 akışında her task'ta spec reviewer YEŞIL verdi ama quality reviewer MINOR/IMPORTANT bulgu çıkardı (T1 dead lint rule, T6 import order, T7 deprecated build_runner cmd). Tek review loop'la bunlar kaçardı.

**Kural:** Skill'in iki aşamalı review'ını kısaltma. Spec compliance "istediğimi yaptı mı?" sorusunu, code quality "iyi mi yaptı?" sorusunu sorar — iki farklı lens, ikisi de gerekli.

**Nasıl uygulanır:** Fast-tracking temptation'ı yaşarsan (stub dosyalar için "zaten ufak, atla"), DURMA. Quality reviewer 1-2 dakika ekstra alır, bulgularla gelir. Yalnızca `.gitkeep` gibi gerçekten 0 byte dosyalar için birleşik tek subagent review kabul.

---

## Push shared-state aksiyonu — açık onay gerekli

**Kural:** `git push`, PR açma, branch silme gibi remote'u etkileyen aksiyonlar user'ın explicit onayı olmadan yapılmaz. "Push edeyim mi?" diye sorulur. Tek seferlik onay verilse dahi sonraki oturumda tekrar sorulur — onay scope-limited.

**Nasıl uygulanır:** Her remote-touching adımdan önce özet göster + tetikleme komutu öner + "çalıştırayım mı?" sor.
