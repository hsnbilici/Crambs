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

## Sprint B5 dersleri (2026-04-19)

### Ders: Flutter pubspec `assets:` NON-recursive — subdirectory'ler tek tek listelenir
**Problem:** B5 sprint'te 4 SFX + 1 ambient `.ogg` asset'ini `assets/audio/sfx/` ve `assets/audio/music/` altına koyduk. `pubspec.yaml` içinde mevcut `assets: - assets/` entry'si varsayım olarak "wildcard / recursive" kabul edildi; plan doc'una bile (`2026-04-19-sprint-b5-audio-layer.md` line 98) "yeni directory declaration gerekmez" yazıldı. 297 automated test yeşil, PR final review'a kadar bug silent kaldı. Final reviewer gerçek APK build yapıp `unzip -l build/.../app-debug.apk | grep ogg` ile kontrol edince **AssetManifest.bin içinde YALNIZ `assets/.gitkeep`** olduğunu, beş .ogg dosyasının bundle edilmediğini keşfetti. [I21] fail-silent sayesinde runtime'da crash yok — sadece sessiz oyun. T14-fix commit `f953861` ile 1-satır pubspec eklemesiyle çözüldü.

**Kök neden:** Flutter `pubspec.yaml` `flutter.assets:` declaration'ı — `- assets/` formatı **yalnız o dizinin direct children'ını** bundle eder, subdirectory'leri kapsamaz. Documented Flutter behavior ama counter-intuitive (diğer build system'lerde wildcard default). Plan yazım sırasında assumption doğrulanmadı, implementer spec'e bire bir uydu.

**Kritik tespit — neden otomatik test yakalamadı:**
- Tüm audio tests `FakeAudioEngine` override kullanır → gerçek asset resolve hiç çalışmaz
- `AudioplayersEngine` production path platform-bound, coverage dışında (spec §4.4)
- `flutter analyze` / `flutter test` asset bundling path'ini hiç expose etmez
- CI'da `flutter build apk --debug` yapılmıyor (test + coverage only); ancak real device deploy'da fark edilir

**Önleme kuralı:**
1. Yeni asset directory ekleyince **her zaman** pubspec'e explicit entry at:
   ```yaml
   assets:
     - assets/
     - assets/audio/sfx/      # her subdirectory ayrı satır
     - assets/audio/music/
   ```
2. Asset eklerken doğrulama: `flutter build apk --debug && unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep <ext>` — beklenen dosya sayısı listede mi?
3. CI pipeline'a APK build + asset manifest assertion ekle (Sprint D polish candidate)
4. `FakeAudioEngine` gibi test-only substitute'ler runtime asset path'ini validate etmez; platform-bound integration veya manuel QA zorunlu

**Meta-ders:** "Test yeşil + analyze clean + review geçti" yeterli değil — build artifact inspection kritik. Fail-silent invariant'lar ([I21] gibi) bug maskeleyebilir; bu durum tests'i invalidate etmez ama test scope'u build/asset tarafını kapsamalı. CLAUDE.md §4 zorunlu docs yeterli değil, §10 "plan mode" listesinde "asset pipeline değişikliği" kategorisi değerlendirilebilir.

### Ders: Riverpod 3 `overrideWithValue` builder'ı skip eder — `ref.onDispose` register olmaz
**Problem:** B5 T8'de `audioEngineProvider` test'inde `audioEngineProvider.overrideWithValue(fake)` kullanıldı. Test assertion "container.dispose → fake.disposed=true" — always false. Provider builder içindeki `ref.onDispose(() => engine.dispose())` hiç register olmadı.

**Kök neden:** Riverpod 3'te `overrideWithValue(v)` internal olarak `$SyncValueProvider<T>(v)` substitute eder — orijinal provider builder closure **hiç çalışmaz**. `ref.watch`, `ref.read`, `ref.listen`, `ref.onDispose` gibi Ref API'leri override builder'ı atlanarak direkt value injection yapar.

**Önleme kuralı:**
- Provider dispose side-effect'i veya ref.listen/onDispose teste dahilse: `overrideWithValue` yerine `overrideWith` kullan:
  ```dart
  audioEngineProvider.overrideWith((ref) {
    ref.onDispose(() => unawaited(fake.dispose()));
    return fake;
  })
  ```
- Yalnız value injection gerekliyse (side-effect yok) `overrideWithValue` hâlâ doğru seçim — daha sade.
- Test-reviewer sorgusu: "Override builder'ı çalışmasa da assertion geçer mi?" Evet ise assertion zayıf, overrideWith'e geçir.

### Ders: flutter_animate `.shake()` widget test'te `Timer(Duration.zero)` leak eder
**Problem:** B5 T11 sonrası `building_row_sfx_test` (widget test) `!timersPending` invariant assertion ile fail. Pending timer stack: `_AnimateState._restart → FakeTimer duration 0`. BuildingRow `.animate().shake(duration: 300.ms, hz: 6)` wrap'inden geliyor.

**Kök neden:** `flutter_animate` initState'te `Timer(Duration.zero)` spawn ediyor animasyon scheduling için. Widget test fake-async zone'unda bu timer pump(0) olmadan fire etmiyor; test bitişinde `_verifyInvariants` pending görünce hata veriyor.

**Önleme kuralı:**
- `flutter_animate .shake() / .fade() / .scale()` kullanan widget mount edildikten sonra `tester.pump(Duration(milliseconds: 1))` ile Duration.zero timer'larını drain et.
- Test sonunda unmount + dispose drain sırası: `pump(Duration(seconds: 3))` (snackbar + shake settle) → `pumpWidget(SizedBox.shrink())` → `pump(1ms)` → `container.dispose()`.
- Shared `_teardown(tester, container)` helper tekrar eden boilerplate'i azaltır (bkz `building_row_sfx_test.dart`).

### Ders: GameStateNotifier lifecycle test — hydrate hiç tetiklenmezse `persistNow()` silent skip eder
**Problem:** B5 T9-polish `[I23]` triple-order test'inde `persist.save` log'a eklenmedi. SessionController ve AudioController kanıtlı çalışıyordu ama SaveRepository.save hiç çağrılmadı.

**Kök neden:** `GameStateNotifier.persistNow()` → `if (state.value == null) return;` early return. Widget test'te `ProviderScope(overrides: ...)` ile mount → `gameStateNotifierProvider` lazy, AsyncLoading state kalır. `pumpAndSettle` path_provider I/O'yu (fake-async zone'unda) beklemez. Lifecycle pause hit ettiğinde state hâlâ null → persist skip.

**Önleme kuralı:**
- Widget test'te GameStateNotifier kullanan lifecycle path'i test ediyorsan pre-boot pattern zorunlu:
  ```dart
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(overrides: [...]);
    await container.read(gameStateNotifierProvider.future); // hydrate
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: ..., child: ...));
  ```
- Pattern zaten B5 T10 `tap_area_sfx_test` için kurulmuştu; lifecycle testleri de aynı pattern'i kullanmalı.

### Ders: audioplayers 6.x `AudioContext` const değil
**Problem:** B5 T6 plan snippet `const AudioContext(...)` yazıyordu. Compile hata: `AudioContextIOS` constructor non-const.

**Kök neden:** audioplayers 6.6.0'da `AudioContextIOS` constructor runtime assert'lere sahip (`assert(frameworksIsSet)` gibi) → const constructor olamıyor. Nested `AudioContextAndroid` const, outer `AudioContext` non-const.

**Önleme kuralı:** audioplayers config: outer `AudioContext(...)` non-const, nested `AudioContextAndroid(...)` const kalabilir. `const` keyword'u minimum seviyede uygula. Paket API versiyonu değişince re-verify.

### Ders: `unawaited(future)` try/catch async error'u yakalamaz
**Problem:** B5 T9 `_onResume` içinde `try { unawaited(resumeAmbient()); } catch {...}` pattern'i kullanıldı. Code review bulgusu: unawaited sync type-erasure; async throw Zone.handleUncaughtError'a kaçar, try/catch sync throw'u yakalar (ki ref.read ne throw eder ne de).

**Önleme kuralı:** Async error'ı fire-and-forget path'te yakalamak için `.catchError` future'a direkt attach et:
```dart
unawaited(
  someFuture().catchError((Object e, StackTrace st) => debugPrint('...')),
);
```
`try { unawaited(...) } catch` pattern'ı cosmetic, pratikte hiçbir şey yakalamaz. T9-fix commit `894b0b7` ile düzeltildi.

### Ders: Wall-clock gate testi `fakeAsync` ile çalışmaz
**Problem:** B5 T10 `tapCrumb` 80ms throttle `DateTime.now()` kullanıyor. `tester.pump(Duration(milliseconds: 100))` fake-async advance eder ama `DateTime.now()` sistem clock'tan okur, fake clock değil. Test assert "5 paced tap → 5 SFX" fail eder.

**Önleme kuralı:** Wall-clock (`DateTime.now()`) gate'li kod için test pattern:
```dart
await tester.runAsync(() async {
  for (var i = 0; i < 5; i++) {
    await tester.tap(tap);
    await Future<void>.delayed(const Duration(milliseconds: 100)); // real delay
  }
});
```
`runAsync` içinde gerçek clock advance eder. `fakeAsync`/`pump(Duration)` alternatifi değildir — yalnız periodic/delayed Timer'lar için çalışır.
