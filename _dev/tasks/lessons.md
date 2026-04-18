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

---

## Sprint B3 → B4 review takeaways (2026-04-18)

### Ders: FirebaseBootstrap static state — widget test coverage limitation
**Problem:** `FirebaseBootstrap._initialized` static + private. Widget test'te `isInitialized=true` simulate edilemez — Crashlytics Test Crash button full path manual QA gerekir.

**Kök neden:** Static state sharing across tests + private field access pattern. Test isolation için provider wrapper gerekir.

**Önleme kuralı:** Production state'i provider wrapper'a koy (static flag yalnız pre-provider init ownership için). B5 followup: FirebaseBootstrap state → `Provider<bool>`.

### Ders: Firebase compliance regex invariant — scaling pattern
**Problem:** TelemetryEvent eklendiğinde regex invariant test events list manuel güncellenir. Unutulursa new event Firebase Analytics kurallarına uymayabilir.

**Kök neden:** Parameterized test events list hard-coded; sealed class introspection yok.

**Önleme kuralı:** Yeni `TelemetryEvent` eklenirken T4-equivalent invariant test güncellemesi DoD checklist'inde olsun. Future: `TelemetryEvent.allSubtypes` registry derive edilebilirse otomatik (Dart reflection limited — pragmatic: PR template'te "events list güncel mi?" checkbox).

### Ders: CI secret decode fork-safety
**Problem:** B3 ilk deploy CI'da `firebase_options.dart` eksik → analyze fail. Fork PR'larda secret erişimi yok.

**Kök neden:** Decode step `env != ''` guard ilk deploy'da vardı ama fallback (template copy) eksikti.

**Önleme kuralı:** Secret-dependent decode step her zaman fork-safe fallback'e sahip olmalı — template copy (`cp .template target`). Fork PR'larda template default path aktif. B3-T11-fix bu pattern'i kesinleştirdi.

### Ders: Atomic task chain compile-red window management
**Problem:** B3 T6→T7→T14 ve B4 T3→T4→T5→T6→T7 gibi shape change task'lar compile-red intermediate state'ler üretir. Subagent'a "bu beklenen" demezsek implementer panic eder.

**Kök neden:** TDD strict + atomic commit discipline — shape change commit'i tek başına kırık bırakır, downstream fix commit'leri takip eder.

**Önleme kuralı:** Plan task açıklamasında "compile-green restore T<n>'e kadar" açıkça yaz. Subagent brief'ine "Analyze expected FAIL after this commit — T<next> resolves" explicit note. B4 T3 bu pattern'i dokümante etti.

---

## Sprint B4 simulator deploy dersleri (2026-04-18)

### Ders: iOS deployment target — Firebase dependency'lerle senkron
**Problem:** `flutter build ios` fail: "firebase_crashlytics requires higher minimum iOS deployment version (15.0). Current: 13.0". B3'te pubspec'e `firebase_crashlytics: ^5.0.0` eklendi ama iOS side deployment target güncellenmedi — ilk iOS build B4'te yapıldığı için geç fark edildi.

**Kök neden:** Flutter pubspec dependency değişikliği native side requirement'larını otomatik bump etmez. `ios/Podfile` platform directive + `ios/Runner.xcodeproj/project.pbxproj` IPHONEOS_DEPLOYMENT_TARGET ayrı yerlerden yönetilir. CocoaPods post-install hook `flutter_additional_ios_build_settings` tam çözmedi.

**Önleme kuralı:** Firebase veya benzeri native-integrated package eklerken her zaman:
1. Package'ın minimum iOS version'ını kontrol et (pub.dev / docs)
2. `ios/Podfile` `platform :ios, 'X.X'` uncomment + güncelle
3. `ios/Runner.xcodeproj/project.pbxproj` IPHONEOS_DEPLOYMENT_TARGET'ı tüm 3 config'te (Debug/Profile/Release) güncelle
4. `flutter build ios --debug --simulator --no-codesign` ile early validation yap

Benzer pattern Android için: `android/app/build.gradle.kts` `minSdk` — firebase_crashlytics Android min SDK 21+.

### Ders: google_mobile_ads → GADApplicationIdentifier zorunluluğu
**Problem:** Simulator'de app launch sonrası hard crash: `GADInvalidInitializationException: The Google Mobile Ads SDK was initialized without an application ID`. Dart-level try/catch yutamaz (native Objective-C exception, boot time'da `dispatch_async` block'ta fire).

**Kök neden:** `google_mobile_ads: ^8.0.0` pubspec'te B1'den beri vardı (scaffold, post-MVP FR-14 için hazırlık). iOS SDK `applicationDidFinishLaunching` sırasında `GADApplicationVerifyPublisherInitializedCorrectly` çağırıyor — Info.plist'te `GADApplicationIdentifier` yoksa NSException throw. B1-B3'te iOS build hiç yapılmadı (Flutter test environment Mock-based), crash ancak B4 simulator deploy'unda ortaya çıktı.

**Önleme kuralı:**
1. Native-boot-time crash'i olan package'lar için pubspec ekleme sırasında aynı anda Info.plist / AndroidManifest.xml setup'ı yap
2. Dev environment için Google resmi test ID kullan: `ca-app-pub-3940256099942544~1458002511` (iOS), `ca-app-pub-3940256099942544~3347511713` (Android)
3. Production'da real AdMob account ID FR-14 rewarded ad implementation sprint'inde swap edilir (post-MVP)
4. Native SDK boot validation exception'ları Dart catch edemez — Info.plist requirement'ı zorunlu-at-commit-time

**Meta-ders:** "Pubspec'e dep ekle → hiç kullanma → saklı boot crash" pattern'i tehlikeli. Dependency eklerken o dep'in boot-time requirement'larını immediate execute et (Info.plist entry, native SDK init), değilse dep'i ekleme. B1 scaffold decision'ı retroactively temizlenmeli: ya google_mobile_ads/in_app_purchase Info.plist + AndroidManifest entry'leri tam setup, ya B6+'ya kadar pubspec'ten kaldır.
