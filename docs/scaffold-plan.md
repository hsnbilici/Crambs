# Scaffold Planı — Flutter İlk PR Blueprint

**Proje:** Project Crumbs
**Kapsam:** Scaffold PR için tek gerçek implementasyon rehberi
**Kaynak:** PRD §16.5, §17 Sprint 0; CLAUDE.md §3, §5, §6, §7, §8
**Güncelleme:** 2026-04-16

> Bu doküman scaffold PR'ının **ne üretmesi gerektiğini** tanımlar. Çalışan kod içermez; her modül `// TODO` stub'ıyla işaretlidir.
> Gerçek implementation ayrı task'larda yazılır. Firebase / Ads / IAP SDK konfigürasyonu için ayrı runbook hazırlanacaktır. CI pipeline için bkz. `docs/ci-plan.md` (S2). Visual design için bkz. `docs/visual-design.md` (S3).

---

## 1. Doküman Amacı ve Kapsam

Bu doküman **scaffold PR için tek gerçek kaynaktır (single source of truth)**. PR yazarı bu dokümanı okuyarak hangi dosyaların oluşturulacağını, hangi bağımlılıkların ekleneceğini ve smoke test kriterlerini tam olarak anlar.

**Bu doküman NE DEĞİLDİR:**

- Gerçek kod implementasyonu değil — her modül `// TODO` stub'ıyla işaretlidir.
- Firebase / Ads / IAP SDK konfigürasyonu değil — `pubspec.yaml` entry'leri eklenir; kurulum runbook'u ayrıdır.
- CI pipeline değil — bkz. `docs/ci-plan.md` (S2 hedefi).
- Visual design değil — bkz. `docs/visual-design.md` (S3 hedefi).
- PRD veya `docs/economy.md` gibi ürün kararı dokümanları değil.

---

## 2. Flutter Versiyon Pin

| Parametre | Değer |
|---|---|
| Flutter kanalı | stable |
| Flutter versiyonu | 3.27.x (FVM ile pin: `fvm use 3.27.0`) |
| Dart versiyonu | 3.6.x (Flutter 3.27 ile birlikte gelir) |
| iOS minimum | 13.0 (Flutter min) |
| Android minimum | API 21 (SDK min) |
| Cihaz desteği | Fiziksel cihaz + emülatör/simülatör |

**Versiyon doğrulama:**

```bash
# FVM kuruluysa
fvm use 3.27.0
fvm flutter --version

# FVM yoksa doğrudan
flutter --version
# "Flutter 3.27.x • channel stable" çıktısı beklenir
```

Repo kökünde `.fvm/fvm_config.json` eklenir:

```json
{
  "flutterSdkVersion": "3.27.0"
}
```

---

## 3. `pubspec.yaml` İçeriği

Aşağıdaki dosya scaffold PR'ında `flutter create` çıktısının yerini alır. Tüm versiyonlar pub.dev stable kanalına göre sabitlenmiştir.

```yaml
name: crumbs
description: Project Crumbs — mobile idle game
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ">=3.6.0 <4.0.0"
  flutter: ">=3.27.0"

dependencies:
  flutter:
    sdk: flutter

  # State management (CLAUDE.md §7)
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Save persist (docs/save-format.md §2.1)
  path_provider: ^2.1.5

  # SaveEnvelope checksum — SHA-256 (docs/save-format.md §3)
  crypto: ^3.0.6

  # Routing
  go_router: ^14.6.2

  # Lokalizasyon / format
  intl: ^0.19.0

  # Immutable state modeli (GameState, SaveEnvelope)
  freezed_annotation: ^2.4.4

  # Save serialize (docs/save-format.md §1)
  json_annotation: ^4.9.0

  # Analytics / Monetization (ayrı runbook ile yapılandırılır)
  firebase_core: ^3.8.0
  firebase_analytics: ^11.3.3
  google_mobile_ads: ^5.3.0
  in_app_purchase: ^3.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # Test mocking
  mocktail: ^1.0.4

  # Code generation
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  riverpod_generator: ^2.6.1

  # Lint
  custom_lint: ^0.7.0
  riverpod_lint: ^2.6.1
  very_good_analysis: ^7.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/
```

**Toplam:** 12 production dependency + 9 dev dependency = 21 paket.

> `firebase_core`, `firebase_analytics`, `google_mobile_ads`, `in_app_purchase` scaffold'da pubspec'e eklenir fakat `flutterfire configure` çalıştırılmaz; bu adım ayrı bir PR'a bırakılır.

---

## 4. `analysis_options.yaml` İçeriği

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint
  errors:
    missing_required_param: error
    missing_return: error
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "build/**"

linter:
  rules:
    # Proje özeline geçersiz kılmalar
    public_member_api_docs: false  # mobil uygulama, kütüphane değil
    prefer_const_constructors: true
    use_build_context_synchronously: true
```

---

## 5. Dizin Yapısı

CLAUDE.md §5 ile birebir eşleşen tam dosya listesi. `flutter create` sonrası elle oluşturulur.

```text
lib/
  main.dart                            # Flutter entry point
  app/
    boot/
      app_bootstrap.dart               # Firebase init + ProviderScope hazırlığı
    routing/
      app_router.dart                  # go_router yapılandırması
      routes.dart                      # Rota sabit ve yardımcıları
  core/
    economy/
      economy.dart                     # Barrel export
      cost_curve.dart                  # docs/economy.md §5 — bina maliyet eğrisi
      production.dart                  # docs/economy.md §3 — üretim formülleri
      offline_progress.dart            # docs/economy.md §3.4 — offline delta
      multiplier_chain.dart            # docs/economy.md §6 — toplam çarpan
      prestige.dart                    # docs/economy.md §9 — prestige kazanç
    progression/
      progression.dart                 # Barrel export
      unlock_resolver.dart             # Prerequisite çözümleme (CLAUDE.md §6/2)
    save/
      save_repository.dart             # Disk I/O, atomik yazma (docs/save-format.md §5)
      save_envelope.dart               # Freezed model — §1 şeması
      save_migrator.dart               # Versiyon zinciri (docs/save-format.md §6)
      migrations/
        # v{N}_to_v{N+1}.dart dosyaları ihtiyaç doğdukça eklenir
    events/
      events.dart                      # Barrel export
      event_spawner.dart               # Olay üretme (PRD §7.7)
      buff_calculator.dart             # docs/economy.md §A.4 — geçici buff
  features/
    home/
      home_page.dart                   # Boş Home ekranı
      home_controller.dart             # Riverpod controller stub
    shop/
      shop_page.dart
      shop_controller.dart
    upgrades/
      upgrades_page.dart
    research/
      research_page.dart
    prestige/
      prestige_page.dart
    achievements/
      achievements_page.dart
    settings/
      settings_page.dart
    session_recap/
      session_recap_modal.dart         # docs/ux-flows.md §6
  ui/
    components/
      .gitkeep
    theme/
      app_theme.dart                   # Placeholder — docs/visual-design.md hazırlanıyor

test/
  core/
    economy/
      cost_curve_test.dart
      prestige_test.dart
      offline_progress_test.dart
    save/
      save_envelope_test.dart
      save_migrator_test.dart
    progression/
      unlock_resolver_test.dart
  fixtures/
    save_v1.json                       # docs/test-plan.md §6.4 — pre-migration fixture
  golden/
    # Golden snapshot dosyaları burada oluşturulacak

integration_test/
  app_test.dart                        # Uçtan uca: uygulama boot + Home ekranı görünür

assets/
  .gitkeep
```

---

## 6. Stub Dosya İçerikleri

Scaffold PR'ında her dosya minimal içerikle oluşturulur. Gerçek implementasyon içermez — her stub `// TODO` + ilgili doc referansı taşır.

> **İstisna:** `lib/main.dart` ve routing/bootstrap dosyaları TODO değildir — uygulama boot olup smoke test'i geçmesi için **fonksiyonel** olmak zorundadır. Bu dosyalar tüm uygulama iskeletini kuran minimum kodu içerir, feature mantığı içermez.

### `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/app/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();
  runApp(const ProviderScope(child: CrumbsApp()));
}

class CrumbsApp extends ConsumerWidget {
  const CrumbsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Crumbs',
      routerConfig: router,
    );
  }
}
```

### `lib/app/boot/app_bootstrap.dart`

```dart
/// Uygulama başlatma — Firebase ve diğer SDK'ların sıralı init'i.
/// TODO: Firebase.initializeApp() — ayrı PR (flutterfire configure + CLAUDE.md §2 SDK listesi).
class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    // TODO: implement per CLAUDE.md §3 ve Firebase runbook
  }
}
```

### `lib/app/routing/app_router.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crumbs/app/routing/routes.dart';
import 'package:crumbs/features/home/home_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
      ),
      // TODO: diğer rotalar eklendikçe buraya eklenir
    ],
  );
});
```

### `lib/app/routing/routes.dart`

```dart
/// Rota sabit tanımları.
abstract class Routes {
  static const home = '/';
  static const shop = '/shop';
  static const upgrades = '/upgrades';
  static const research = '/research';
  static const prestige = '/prestige';
  static const achievements = '/achievements';
  static const settings = '/settings';
}
```

### `lib/features/home/home_page.dart`

```dart
import 'package:flutter/material.dart';

/// Ana oyun ekranı — boş scaffold.
/// TODO: implement per docs/ux-flows.md §1
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Crumbs — Home'),
      ),
    );
  }
}
```

### `lib/features/home/home_controller.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_controller.g.dart';

/// Home ekranı state controller.
/// TODO: implement GameState bağlantısı — ayrı task
@riverpod
class HomeController extends _$HomeController {
  @override
  void build() {}
}
```

### Feature stub'larının genel şablonu

Aşağıdaki dosyalar aynı minimal yapıyı izler (yorum değiştirilir):

- `lib/features/shop/shop_page.dart` — `// TODO: implement per docs/ux-flows.md §2`
- `lib/features/shop/shop_controller.dart`
- `lib/features/upgrades/upgrades_page.dart` — `// TODO: implement per docs/upgrade-catalog.md`
- `lib/features/research/research_page.dart` — `// TODO: implement per docs/research-tree.md`
- `lib/features/prestige/prestige_page.dart` — `// TODO: implement per docs/economy.md §9`
- `lib/features/achievements/achievements_page.dart`
- `lib/features/settings/settings_page.dart`
- `lib/features/session_recap/session_recap_modal.dart` — `// TODO: implement per docs/ux-flows.md §6`

### `lib/core/economy/cost_curve.dart`

```dart
/// Bina maliyet eğrisi.
/// TODO: implement per docs/economy.md §5
class CostCurve {
  // TODO
}
```

### `lib/core/economy/economy.dart` (barrel)

```dart
export 'cost_curve.dart';
export 'production.dart';
export 'offline_progress.dart';
export 'multiplier_chain.dart';
export 'prestige.dart';
```

### `lib/core/save/save_envelope.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// SaveEnvelope şeması — docs/save-format.md §1
/// TODO: implement GameState alanı — ayrı task
@freezed
class SaveEnvelope with _$SaveEnvelope {
  const factory SaveEnvelope({
    required int version,
    required String lastSavedAt,
    required Map<String, dynamic> gameState, // TODO: GameState tipine geç
    required String checksum,
  }) = _SaveEnvelope;

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) =>
      _$SaveEnvelopeFromJson(json);
}
```

### `lib/core/save/save_repository.dart`

```dart
/// Disk I/O, atomik yazma, yedek rotasyon.
/// TODO: implement per docs/save-format.md §4, §5
class SaveRepository {
  // TODO
}
```

### `lib/core/save/save_migrator.dart`

```dart
/// Versiyon zinciri yönetimi.
/// TODO: implement per docs/save-format.md §6
class SaveMigrator {
  // TODO
}
```

### `lib/ui/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

/// Uygulama teması — placeholder.
/// TODO: implement per docs/visual-design.md (hazırlanıyor)
class AppTheme {
  static ThemeData get light => ThemeData.light();
  static ThemeData get dark => ThemeData.dark();
}
```

### `integration_test/app_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:crumbs/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uygulama boot olur ve Home ekranı görünür', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Crumbs — Home'), findsOneWidget);
  });
}
```

### `test/fixtures/save_v1.json`

```json
{
  "version": 1,
  "lastSavedAt": "2026-04-16T10:00:00.000Z",
  "gameState": {},
  "checksum": "placeholder_checksum_replaced_by_real_value_in_save_task"
}
```

> Gerçek fixture değeri `SaveRepository` implementasyonunda doldurulur — bkz. `docs/save-format.md §9`.

---

## 7. Kod Organizasyon Kuralları

Bu kurallar CLAUDE.md §6'dan türetilir; scaffold'dan itibaren uygulanır.

1. **Barrel dosyaları:** Her `core/` modülü kendi barrel export dosyasını içerir (`economy.dart`, `progression.dart`, `events.dart`). Feature dosyaları bu barrel'ları import eder.

2. **Bağımlılık yönü:** `features/` → `core/` import eder. `core/` → `features/` import **etmez**. Bu kural ihlal edilemez (CLAUDE.md §6/1–4).

3. **Generated dosyalar:** `*.g.dart` ve `*.freezed.dart` çalışma dizininde üretilir fakat Git'e eklenmez (bkz. §9 `.gitignore`). Her PR'ın CI'ında `build_runner` yeniden çalıştırılır.

4. **State ayrımı:** UI animasyon state'i (`flutter_riverpod` lokal `StateProvider`) ekonomik state'ten fiziksel olarak ayrı dosyalarda tutulur (CLAUDE.md §7).

5. **Çarpan toplama:** Tüm çarpan hesapları `core/economy/multiplier_chain.dart` içinde merkezlenir; feature dosyalarına dağıtılmaz (CLAUDE.md §6/6).

---

## 8. Build ve Smoke Test Doğrulaması

Scaffold PR'ı aşağıdaki koşulların tümü sağlandığında **"geçti"** sayılır:

| Kontrol | Komut | Beklenen sonuç |
|---|---|---|
| Bağımlılık çözümleme | `flutter pub get` | Sıfır hata |
| Statik analiz | `flutter analyze` | Sıfır hata, sıfır uyarı |
| Unit + widget testleri | `flutter test` | Tüm testler geçer |
| Code generation | `flutter pub run build_runner build --delete-conflicting-outputs` | Sıfır hata; `*.g.dart`, `*.freezed.dart` üretilir |
| Çalıştırma | `flutter run` | Uygulama boot olur; boş Home ekranı görünür |
| Android debug build | `flutter build apk --debug` | APK başarıyla üretilir |
| iOS debug build | `flutter build ios --debug --no-codesign` | iOS build başarılı (codesigning olmadan) |

> Android build için `JAVA_HOME` ve Android SDK ortam değişkenleri gereklidir. iOS build yalnızca macOS üzerinde doğrulanır.

---

## 9. `.gitignore` Eklemeleri

`flutter create` çıktısının varsayılan `.gitignore`'una ek olarak aşağıdakiler eklenir:

```gitignore
# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/

# Generated — build_runner çıktıları Git'e eklenmez (CLAUDE.md §3)
*.g.dart
*.freezed.dart

# iOS
**/Pods/
**/Podfile.lock
**/ios/Flutter/Generated.xcconfig
**/ios/Flutter/flutter_export_environment.sh

# Android
**/android/.gradle/
**/android/captures/
**/android/gradlew
**/android/gradlew.bat

# IDE
.idea/
.vscode/
*.iml

# FVM
.fvm/flutter_sdk

# Env
.env
.env.local
```

---

## 10. Scaffold PR Checklist

Adımlar sırasıyla uygulanır. Her adım tamamlanmadan bir sonrakine geçilmez.

- [ ] `flutter create --template app --org com.crumbs --project-name crumbs .` çalıştır (mevcut repo kökünde).
- [ ] `flutter create` tarafından üretilen `lib/main.dart` ve `test/widget_test.dart` sil; bu dokümandaki stub'larla değiştir.
- [ ] `pubspec.yaml` içeriğini §3'teki spec ile değiştir.
- [ ] `analysis_options.yaml` dosyasını §4'teki içerikle ekle.
- [ ] §5'teki dizin yapısını oluştur; tüm stub dosyaları §6'ya göre yaz.
- [ ] `.fvm/fvm_config.json` ekle (§2).
- [ ] `.gitignore`'a §9'daki ekleri yap.
- [ ] `flutter pub get` çalıştır — sıfır hata doğrula.
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs` çalıştır.
- [ ] `flutter analyze` çalıştır — sıfır hata / uyarı olana kadar düzelt.
- [ ] `integration_test/app_test.dart` smoke test'i yaz (§6'daki içerik).
- [ ] `flutter test` çalıştır — tüm testler geçmeli.
- [ ] `flutter run` ile uygulamayı başlat — boş Home ekranı görünmeli.
- [ ] `flutter build apk --debug` ile Android debug build doğrula.
- [ ] `flutter build ios --debug --no-codesign` ile iOS debug build doğrula (macOS).
- [ ] PR açıklamasına §8 kontrol tablosunu ekle; her satırın geçtiğini belgele.
- [ ] `flutterfire configure` **çalıştırma** — Firebase kurulum adımı ayrı PR'a bırakılır.

---

## 11. Kapsam Dışılar

Bu doküman ve scaffold PR aşağıdakileri kapsamaz:

| Konu | Nerede ele alınır |
|---|---|
| Gerçek kod implementasyonu | Her modül ayrı task'ta (CLAUDE.md §11) |
| Firebase / Ads / IAP SDK yapılandırması | Ayrı runbook — `flutterfire configure` |
| CI pipeline kurulumu | `docs/ci-plan.md` (S2 hedefi) |
| Visual design / tema | `docs/visual-design.md` (S3 hedefi) |
| Save migration gerçek implementasyonu | `docs/save-format.md` — ayrı task |
| Economy formül implementasyonu | `docs/economy.md` — ayrı task |
| Research tree implementasyonu | `docs/research-tree.md` — ayrı task |
| Bulut kayıt / senkronizasyon | MVP dışı — PRD §13 |
