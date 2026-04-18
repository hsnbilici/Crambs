# Sprint B3 — Production Telemetry Activation Design

**Hedef:** B2'nin stub-first telemetry pipeline'ını Firebase Analytics'e bağla, Crashlytics error reporting aktif et, `install_id_age_ms` payload ile cohort analytics unlock et. TelemetryLogger interface (B2) değişmez — tek dosya swap noktası.

**Sonraki:** Sprint B4 (Settings Developer ekranı + Tutorial replay toggle + Purchase/Upgrade telemetry events). Sprint C (R2 Research Shards + 3 bina daha + Research Lab).

**Tarih:** 2026-04-18
**Referans:** `cookie_clicker_derivative_prd.md §11 (telemetry)`, `docs/telemetry.md`, `docs/superpowers/specs/2026-04-17-sprint-b2-tutorial-telemetry-design.md`, `CLAUDE.md §2/§12`

---

## 1. Kapsam

### 1.1 In Scope (B3)

- **Firebase core bootstrap:**
  - `lib/app/boot/firebase_bootstrap.dart` — `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` try/catch wrapper, `isInitialized` flag
  - Data transmission gate: `setAnalyticsCollectionEnabled(!kDebugMode)` + `setCrashlyticsCollectionEnabled(!kDebugMode)` — debug'da event/crash native'de işlenir ama gönderilmez
  - Error handlers register: `FlutterError.onError = recordFlutterError` (non-fatal), `PlatformDispatcher.instance.onError = recordError(fatal: true)`
  - Init failure silent fallback — app Firebase olmadan da çalışır
- **Firebase Analytics wiring:**
  - `lib/core/telemetry/firebase_analytics_logger.dart` — `TelemetryLogger` implementation, fire-and-forget `unawaited(logEvent)`
  - Payload coercion: `bool → int` (1/0), null drop (Firebase Analytics constraint: String/int/double only)
  - `telemetryLoggerProvider` 3-state gate: `kDebugMode` → `DebugLogger`; `!FirebaseBootstrap.isInitialized` → `DebugLogger`; else → `FirebaseAnalyticsLogger(FirebaseAnalytics.instance)`
- **Crashlytics integration:**
  - User identity: `FirebaseCrashlytics.instance.setUserIdentifier(gs.meta.installId)` — AppBootstrap step d sonrası, `unawaited` (boot'u bloklamaz)
  - Manual crash verification runbook (no production UI)
- **`install_id_age_ms` payload:**
  - `InstallIdNotifier` extension — `_prefKeyCreatedAt` ('crumbs.install_created_at' ISO8601), `_createdAt` field, `installIdAgeMs` getter, `kAgeNotLoaded = -1` sentinel, clock-backward clamp
  - `SessionStart.installIdAgeMs` yeni required field (AppInstall shape değişmez — `~0ms` redundant)
  - Corruption recovery: parse fail → `debugPrint` + reset to now
- **Config management:**
  - `.gitignore` rules: `firebase_options.dart`, `GoogleService-Info.plist`, `google-services.json`, `firebase_app_id_file.json`
  - Commit: `lib/firebase_options.dart.template` (throws UnimplementedError)
  - Native configs template DROP (Xcode/Gradle natural "file not found" error runbook'a yönlendirir)
- **CI secret wiring:** GitHub Actions decode step, `if: env.FIREBASE_OPTIONS_DART_B64 != ''` guard (fork PR'larda silent skip → template throw → DebugLogger fallback)
- **Dev onboarding:** `docs/firebase-setup.md` runbook (prereq, onboarding, secrets mgmt macOS+Linux, privacy, crash verification, troubleshooting)
- **Doc updates:** `CLAUDE.md §12` yeni gotcha'lar, `docs/telemetry.md` SessionStart shape update

### 1.2 Out of Scope (B4+)

- Dev/prod Firebase project ayrımı (tek project varsayımı)
- Firebase Remote Config
- Firebase Messaging (push notifications)
- Sentry alternative evaluation
- Dev-only "Test Crash" button (Settings/Developer ekranı B4'te)
- Crashlytics breadcrumb (`FirebaseCrashlytics.log(msg)`) — TelemetryEvent duplicate
- Riverpod ProviderObserver error capture
- Custom keys (`setCustomKey(...)`) — Analytics'te zaten korele
- Non-fatal manual captures (SaveRepository fail, network error) — mevcut `_persistSafe` debugPrint yeterli
- Tutorial replay toggle (B2 backlog carryover)
- Purchase/Upgrade/ResearchComplete telemetry events (B2 backlog carryover)
- `AppInstall.installIdAgeMs` — ~0ms redundant, SessionStart'ta anlamlı

### 1.3 Design assumptions

- B2 PR #4 merge sonrası B3 branch'i `main`'den çıkar (`sprint/b3-telemetry-activation`)
- Firebase project (`crumbs-prod` veya equivalent) hsnbilici account'ta önceden kurulu (Q1 (A))
- flutterfire CLI dev makinesinde kurulu (`dart pub global activate flutterfire_cli`)
- App Firebase'e hard dependency'si YOK — init failure'da silent fallback + normal game flow
- TelemetryLogger interface (B2) hiç değişmez — swap tek dosyada (`telemetry_providers.dart`)
- `AppInstall` shape korunur (B2 backward compat); yeni alan yalnız `SessionStart.installIdAgeMs`

---

## 2. Architecture

### 2.1 Yeni modüller

```
lib/app/boot/
└── firebase_bootstrap.dart          [YENİ]
      └── class FirebaseBootstrap
          ├── static bool _initialized (private)
          ├── static bool get isInitialized
          └── static Future<void> initialize()
              ├── try/catch wrapper
              ├── Firebase.initializeApp(options: ...)
              ├── setAnalyticsCollectionEnabled(!kDebugMode)
              ├── setCrashlyticsCollectionEnabled(!kDebugMode)
              ├── FlutterError.onError = recordFlutterError (non-fatal)
              └── PlatformDispatcher.onError = recordError(fatal: true)

lib/core/telemetry/
└── firebase_analytics_logger.dart   [YENİ]
      └── class FirebaseAnalyticsLogger implements TelemetryLogger
          ├── log(event) — fire-and-forget + bool→int coercion + null drop
          ├── beginSession() — no-op (Firebase auto session tracking)
          └── endSession() — no-op

lib/firebase_options.dart.template   [YENİ, committed]
      └── class DefaultFirebaseOptions
          └── static FirebaseOptions get currentPlatform
              → throw UnimplementedError('... run flutterfire configure ...')

docs/
└── firebase-setup.md                [YENİ]
      ├── §1 Prerequisites
      ├── §2 Dev onboarding (flutterfire configure)
      ├── §3 Secret management (macOS + Linux base64)
      ├── §4 Privacy (install_id anonymous UUID, no PII)
      ├── §5 Crashlytics verification (test crash runbook + delete warning)
      └── §6 Troubleshooting
```

### 2.2 Değişen modüller

```
lib/core/telemetry/
├── install_id_notifier.dart         [MODIFIED]
│     ├── YENİ: static const _prefKeyCreatedAt = 'crumbs.install_created_at'
│     ├── YENİ: static const int kAgeNotLoaded = -1
│     ├── YENİ: DateTime? _createdAt
│     ├── YENİ: DateTime? get installCreatedAt
│     ├── YENİ: int get installIdAgeMs (clock-backward clamp)
│     └── MODIFIED: ensureLoaded() — _createdAt load/write + parse corruption log
├── session_controller.dart          [MODIFIED]
│     └── _startNewSession — installIdAgeMs wiring (no ?? 0 fallback; -1 sentinel)
├── telemetry_event.dart             [MODIFIED]
│     └── class SessionStart
│         └── YENİ: final int installIdAgeMs; payload'a 'install_id_age_ms' eklendi
└── telemetry_providers.dart         [MODIFIED]
      └── telemetryLoggerProvider — 3-state gate (kDebugMode, !isInitialized, else)

lib/app/boot/
└── app_bootstrap.dart               [MODIFIED]
      └── step d sonrası:
          if (FirebaseBootstrap.isInitialized) {
            unawaited(FirebaseCrashlytics.instance
                .setUserIdentifier(gs.meta.installId));
          }

lib/main.dart                        [MODIFIED]
      └── WidgetsFlutterBinding.ensureInitialized();
          await FirebaseBootstrap.initialize();  // YENİ — AppBootstrap ÖNCESİ
          final boot = await AppBootstrap.initialize();
          ...

pubspec.yaml                         [MODIFIED]
      └── dependencies:
          firebase_core: ^3.x.x
          firebase_analytics: ^11.x.x
          firebase_crashlytics: ^4.x.x

.gitignore                           [MODIFIED]
      └── lib/firebase_options.dart
          ios/Runner/GoogleService-Info.plist
          ios/firebase_app_id_file.json
          android/app/google-services.json

.github/workflows/ci.yml             [MODIFIED]
      └── yeni step (flutter pub get ÖNCESİ):
          Decode Firebase config (3 base64 secret → file)
          if: ${{ env.FIREBASE_OPTIONS_DART_B64 != '' }}

docs/
├── telemetry.md                     [MODIFIED]
│     └── SessionStart shape update (+installIdAgeMs field + I15 invariant)
└── superpowers/backlog/
      └── sprint-b3-backlog.md       [MODIFIED]
            └── §1/1-2-3 done işaretle (Firebase wiring, Crashlytics, install_id_age_ms)

CLAUDE.md                            [MODIFIED]
      └── §12 yeni gotcha'lar (FirebaseBootstrap.isInitialized guard pattern,
                               kAgeNotLoaded sentinel invariant)
```

### 2.3 Test yapısı

```
test/app/boot/
└── firebase_bootstrap_test.dart     [YENİ]
      ├── initialize() success → isInitialized=true, handlers registered
      ├── initialize() Firebase.initializeApp throws → isInitialized=false, no exception
      └── (mocktail mock firebase_core platform interface)

test/core/telemetry/
├── firebase_analytics_logger_test.dart [YENİ]
│     ├── log(AppInstall) → _analytics.logEvent('app_install', {install_id, platform})
│     ├── log(TutorialCompleted) → bool 'skipped' coerced to 1/0
│     ├── log(event) with null payload value → key dropped
│     ├── beginSession/endSession → no Firebase method calls
│     └── event name regex validation (^[a-zA-Z_][a-zA-Z0-9_]*$, ≤40 char, no reserved prefix)
├── install_id_notifier_test.dart    [MODIFIED — +5 test]
│     ├── ensureLoaded fresh → _createdAt=now + pref yazılır
│     ├── ensureLoaded existing valid → parse success
│     ├── ensureLoaded corrupted string → reset + debugPrint (overridePrint capture)
│     ├── installIdAgeMs fresh → 0 veya positive int (< 100ms)
│     ├── installIdAgeMs pre-ensureLoaded → kAgeNotLoaded (-1)
│     └── installIdAgeMs clock-backward (mock DateTime) → 0 (clamp)
└── session_controller_test.dart     [MODIFIED]
      └── SessionStart payload includes installIdAgeMs (not -1)

integration_test/
└── tutorial_telemetry_integration_test.dart [MODIFIED]
      └── invariant: all SessionStart.installIdAgeMs >= 0
          (not InstallIdNotifier.kAgeNotLoaded)
```

---

## 3. FirebaseBootstrap + Logger routing

### 3.1 FirebaseBootstrap.initialize

```dart
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// main()'de ÖNCE çağrılır — AppBootstrap.initialize ÖNCESİ.
  /// Crashlytics error handlers AppBootstrap hatalarını yakalar (set sırası doğru).
  ///
  /// 3-faz strateji: phase 1 (initializeApp) **fatal** — fail'de early return,
  /// `_initialized=false`. Phase 2 (collection flags) **best-effort** — fail
  /// loglanır ama init çökertmez (Firebase native kayıtlı kalır, sonraki
  /// launch'ta `duplicate app` hatası önlenir). Phase 3 (handler register) sync,
  /// throw etmez.
  static Future<void> initialize() async {
    // Phase 1 — fatal init (native Firebase app binding)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] initializeApp failed, telemetry disabled: $e\n$st',
      );
      return; // _initialized false kalır
    }

    // Phase 2 — best-effort data transmission gate (native init tamamlandı;
    // flag set'i başarısız olsa bile Firebase.instance canlı kalır)
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(!kDebugMode);
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] collection flag set failed (non-fatal): $e\n$st',
      );
      // Devam — Firebase platform default'larıyla çalışır.
    }

    // Phase 3 — sync handler register (exception atmaz)
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    _initialized = true;
  }
}
```

**Phase 1 fail semantics:** `initializeApp` fail'de early return → `isInitialized=false` → logger gate `DebugLogger`'a düşer, error handler'lar register edilmez (default Flutter handler çalışır). Uygulama Firebase'siz normal boot eder.

**Phase 2 fail semantics:** Platform'a özel collection flag set hatası (nadir — corrupted Firebase state veya platform plugin bug). Firebase default'larıyla çalışır; `kDebugMode=true` debug build'de bile Analytics collection Firebase default'u aktif olabilir → dashboard kirlenmesi minor risk. Mitigation yeterli: phase 2 fail log'da görünür, developer müdahale edebilir.

**Phase 3 fail:** Yok — handler atama sync field assignment.

### 3.2 main() sequence

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();   // YENİ
  final boot = await AppBootstrap.initialize();
  await boot.container
      .read(onboardingPrefsProvider.notifier)
      .ensureLoaded();
  runApp(
    UncontrolledProviderScope(
      container: boot.container,
      child: const AppLifecycleGate(child: CrumbsApp()),
    ),
  );
}
```

**Sıra kritik:** FirebaseBootstrap önce → Crashlytics handlers AppBootstrap exception'larını yakalar (SaveRepository fail, path_provider hata gibi). AppBootstrap içindeki `setUserIdentifier` fire-and-forget Firebase init tamamlandıktan sonra çalışır.

### 3.3 telemetryLoggerProvider 3-state gate

```dart
// telemetry_providers.dart — MODIFIED
final telemetryLoggerProvider = Provider<TelemetryLogger>((ref) {
  if (kDebugMode || !FirebaseBootstrap.isInitialized) {
    return DebugLogger();
  }
  return FirebaseAnalyticsLogger(FirebaseAnalytics.instance);
});
```

**3-state semantics:**
- `kDebugMode` → dev build'de DebugLogger (debugPrint flow görünür; release bypass için override yok)
- `!isInitialized` → Firebase init fail'de silent fallback (prod'da Firebase down olursa app telemetry'siz çalışmaya devam)
- Else → FirebaseAnalyticsLogger

Test override pattern B2'den değişmez (`ProviderScope(overrides: [telemetryLoggerProvider.overrideWithValue(FakeLogger())])`).

### 3.4 FirebaseAnalyticsLogger

```dart
class FirebaseAnalyticsLogger implements TelemetryLogger {
  FirebaseAnalyticsLogger(this._analytics);
  final FirebaseAnalytics _analytics;

  /// Fire-and-forget — `unawaited(logEvent)` UI latency optimize eder.
  /// Hızlı ardışık event'lerde Firebase SDK emission sırası GARANTİLİ
  /// DEĞİL (platform channel queueing). B3 event cadence saatlik/session
  /// seviyesinde; ordering issue yok. Daha sıkı ordering gerekirse
  /// Completer chain'i future sprint'te eklenir.
  @override
  void log(TelemetryEvent event) {
    final params = <String, Object>{};
    for (final entry in event.payload.entries) {
      final value = entry.value;
      if (value == null) continue; // null drop
      params[entry.key] = value is bool ? (value ? 1 : 0) : value;
    }
    unawaited(
      _analytics.logEvent(name: event.eventName, parameters: params),
    );
  }

  /// Firebase Analytics otomatik session tracking yapar (engagement time).
  /// Manual session API yok — no-op.
  @override
  void beginSession() {}

  @override
  void endSession() {}
}
```

### 3.5 Firebase Analytics compliance

**Event name kuralları:**
- Regex: `^[a-zA-Z][a-zA-Z0-9_]{0,39}$`
- Max 40 char
- Reserved prefixes YASAK: `firebase_`, `google_`, `ga_`

**Bizim event'lerimiz:**
| eventName | Length | Compliant? |
|---|---|---|
| app_install | 11 | ✓ |
| session_start | 13 | ✓ |
| session_end | 11 | ✓ |
| tutorial_started | 16 | ✓ |
| tutorial_completed | 18 | ✓ |

**Param kuralları:** Max 25 per event, max 40 char key, max 100 char String value. Değerlerimiz: UUID v4 (36 char), platform (ios/android), int (duration_ms, age_ms). Hepsi limit'lerde.

**Regression test (T4):** parameterize 5 event + compile-time regex assertion:
```dart
const _eventNameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
const _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

for (final event in <TelemetryEvent>[
  const AppInstall(installId: 'x', platform: 'ios'),
  const SessionStart(installId: 'x', sessionId: 'y', installIdAgeMs: 0),
  const SessionEnd(installId: 'x', sessionId: 'y', durationMs: 0),
  const TutorialStarted(installId: 'x'),
  const TutorialCompleted(installId: 'x', skipped: false, durationMs: 0),
]) {
  expect(_eventNameRegex.hasMatch(event.eventName), isTrue);
  expect(_reservedPrefixes.any(event.eventName.startsWith), isFalse);
}
```

Yeni event eklendikçe bu test compile-time invariant gibi korur.

---

## 4. install_id_age_ms + InstallIdNotifier extension

### 4.1 Semantic karar

`install_id_age_ms` **yalnız `SessionStart`'ta** emit edilir:
- `AppInstall` fresh install'da fire → age her zaman ~0ms, analytics değeri yok
- `SessionStart` her session'da fire → age grows zamanla → **cohort retention analytics (day-1/day-7/day-30)**

### 4.2 InstallIdNotifier extension

```dart
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKeyId = 'crumbs.install_id';
  static const _prefKeyCreatedAt = 'crumbs.install_created_at'; // YENİ
  static const kNotLoadedSentinel = '<not-loaded>';
  static const int kAgeNotLoaded = -1; // YENİ — B2 pattern-aligned sentinel

  DateTime? _createdAt; // YENİ — session state, disk'e yazılmaz (pref kullanır)

  @override
  String? build() => null;

  /// Install creation timestamp (device-local — cross-device save restore'da
  /// bu device'ın ilk boot'unda yazılır). [ensureLoaded] sonrası güvenilir.
  DateTime? get installCreatedAt => _createdAt;

  /// `_createdAt`'den `DateTime.now()`'a ms. Pre-ensureLoaded: kAgeNotLoaded (-1).
  /// Clock-backward (user cihaz saatini geri aldı) → 0 clamp (negative
  /// dashboard aggregation'ı kirletir).
  int get installIdAgeMs {
    final c = _createdAt;
    if (c == null) return kAgeNotLoaded;
    final diff = DateTime.now().difference(c).inMilliseconds;
    return diff < 0 ? 0 : diff;
  }

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKeyId);

    final createdAtStr = prefs.getString(_prefKeyCreatedAt);
    if (createdAtStr != null) {
      _createdAt = DateTime.tryParse(createdAtStr);
      if (_createdAt == null) {
        // Pref mevcut ama parse edilemedi — corruption forensic log
        debugPrint(
          '[InstallIdNotifier] install_created_at parse failed '
          '(value: "$createdAtStr") — resetting to now. '
          'Install appears new in telemetry.',
        );
      }
    }
    if (_createdAt == null) {
      // İlk boot OR corruption recovery
      _createdAt = DateTime.now();
      await prefs.setString(
        _prefKeyCreatedAt,
        _createdAt!.toIso8601String(),
      );
    }
  }

  Future<void> adoptFromGameState(String savedInstallId) async {
    // Existing GameState-wins logic — değişmedi
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKeyId);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKeyId, savedInstallId);
    }
    state = savedInstallId;
  }
}
```

### 4.3 SessionStart shape update

```dart
class SessionStart extends TelemetryEvent {
  const SessionStart({
    required this.installId,
    required this.sessionId,
    required this.installIdAgeMs, // YENİ
  });

  final String installId;
  final String sessionId;
  final int installIdAgeMs;

  @override
  String get eventName => 'session_start';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'install_id_age_ms': installIdAgeMs,
      };
}
```

### 4.4 SessionController wiring

```dart
void _startNewSession(String installId) {
  _currentSessionId = const Uuid().v4();
  _sessionStartedAt = DateTime.now();
  _logger.beginSession();
  _logger.log(SessionStart(
    installId: installId,
    sessionId: _currentSessionId!,
    installIdAgeMs: _ref.read(installIdProvider.notifier).installIdAgeMs,
  ));
}
```

**No fallback** (`?? 0` yok): ensureLoaded AppBootstrap step b'de garanti edilir. Bypass edilirse `-1` sentinel telemetry'ye gider, integration test reddeder (invariant [I15]).

---

## 5. Crashlytics — user identity + manual verification

### 5.1 AppBootstrap step d (user identity)

```dart
// app_bootstrap.dart — MODIFIED
await container
    .read(installIdProvider.notifier)
    .adoptFromGameState(gs.meta.installId);

// Crashlytics user identity — B3 YENİ
if (FirebaseBootstrap.isInitialized) {
  unawaited(
    FirebaseCrashlytics.instance.setUserIdentifier(gs.meta.installId),
  );
}
```

**fire-and-forget:** Firebase platform channel roundtrip ~50-200ms boot'u bloklar. Crashlytics crash upload zaten ikinci launch'ta (async by design), identity attach timing kritik değil. Guard: `isInitialized` false'sa setUserIdentifier skip (hata atmaz ama gereksiz).

### 5.2 Fatal vs non-fatal policy

| Kaynak | Handler | Fatal | Gerekçe |
|---|---|---|---|
| `FlutterError.onError` | `recordFlutterError` | **non-fatal (default)** | Widget build/paint error, overflow warning — app genelde crash olmaz, recovery mümkün |
| `PlatformDispatcher.instance.onError` | `recordError(fatal: true)` | **fatal** | Root-level uncaught async — isolate'e zaten patladı, recover edilemez |
| Manual capture (B4) | `recordError(fatal: false)` | non-fatal | Beklenen exception'lar (SaveRepository fail, network error) — B3 scope dışı |

### 5.3 Manual verification runbook

`docs/firebase-setup.md §5`:

```markdown
## 5. Crashlytics doğrulama (ilk setup)

> ⚠️ **KRİTİK: Bu runbook'un son adımı test button'ı silmek. Skip edersen
> production build'de "Test Crash" butonu ships olur — kullanıcı cihazında
> erişilebilir hard crash.**
>
> Gelecek prevention: B4'te `Settings > Developer` ekranı gelince bu button
> kalıcı `kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST')`
> flag'i arkasında olacak. B3 kapsamında geçici button + manuel silme.

1. `lib/main.dart` `CrumbsApp.build` içine GEÇİCİ butoncuk ekle (örn. Home
   sayfasının üstüne floating):
   ```dart
   ElevatedButton(
     onPressed: () => FirebaseCrashlytics.instance.crash(),
     child: const Text('Test Crash'),
   )
   ```

2. Release build:
   ```bash
   flutter build ios --release
   flutter build apk --release
   ```

3. Cihazda çalıştır, butona bas → app crash olur

4. Uygulamayı YENİDEN AÇ (crash report upload bir sonraki launch gerekli)

5. Firebase Console → Crashlytics → dashboard'da crash görünür (~5 dk gecikme)

6. **Test butonunu `git checkout lib/main.dart` ile sil — BU ADIMI ATLAMA**

7. Doğrula: `git diff HEAD -- lib/main.dart` temiz (no leftover ElevatedButton)

Debug build'de `setCrashlyticsCollectionEnabled(false)` → collection disabled,
bu test release-only çalışır.

**Not:** Physical device önerilir. iOS simülatör / Android emulator Crashlytics
upload yapabilir ama Firebase docs platform-specific uyarıları var; doğrulama
garanti değil. Emülator'de görünmezse fiziksel cihazda yeniden dene.
```

---

## 6. Config management + CI

### 6.1 .gitignore (Q2 (C))

```gitignore
# Firebase — committed: Dart template only; native configs via flutterfire
# configure (dev) OR CI secret decode (PR/main)
lib/firebase_options.dart
ios/Runner/GoogleService-Info.plist
ios/firebase_app_id_file.json
android/app/google-services.json
```

### 6.2 Template policy

**Commit edilen:** `lib/firebase_options.dart.template` — explicit throw

```dart
// ignore_for_file: type=lint
// Template file — flutterfire configure ile üretilen gerçek
// firebase_options.dart gitignored. Setup için: docs/firebase-setup.md

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      'lib/firebase_options.dart missing. '
      'Run `flutterfire configure` or decode CI secret. '
      'See docs/firebase-setup.md for setup instructions.',
    );
  }
}
```

**Native config template'leri DROP edildi:** GoogleService-Info.plist / google-services.json template'leri repo'ya eklenmez. Xcode/Gradle bu dosyalar yoksa natural error fırlatır ("GoogleService-Info.plist not found") → contributor runbook'a yönlenir. Silent template-ile-ships riski ortadan kalkar.

### 6.3 CI workflow decode step

```yaml
# .github/workflows/ci.yml — YENİ step, flutter pub get ÖNCESİ
- name: Decode Firebase config (secrets → files)
  if: ${{ env.FIREBASE_OPTIONS_DART_B64 != '' }}
  env:
    FIREBASE_OPTIONS_DART_B64: ${{ secrets.FIREBASE_OPTIONS_DART_B64 }}
    IOS_GSI_PLIST_B64: ${{ secrets.IOS_GOOGLE_SERVICE_INFO_PLIST_B64 }}
    ANDROID_GSJ_JSON_B64: ${{ secrets.ANDROID_GOOGLE_SERVICES_JSON_B64 }}
  run: |
    set +x  # trace disable — base64 env secret'ın workflow log'una sızmasını engelle
    echo "$FIREBASE_OPTIONS_DART_B64" | base64 -d > lib/firebase_options.dart
    echo "$IOS_GSI_PLIST_B64" | base64 -d > ios/Runner/GoogleService-Info.plist
    echo "$ANDROID_GSJ_JSON_B64" | base64 -d > android/app/google-services.json
```

**Fork PR güvenliği:**
- External fork'ta `secrets` undefined → env empty → step skip
- Template throw'a fallback → `FirebaseBootstrap.initialize` catch'e düşer
- `isInitialized=false` → `telemetryLoggerProvider` DebugLogger döner
- Test'ler DebugLogger path'iyle geçer (B2'den bu pattern zaten var — `FakeLogger` override)

### 6.4 Dev onboarding runbook iskeleti

`docs/firebase-setup.md`:

```markdown
# Firebase Setup Runbook

## 1. Prerequisites
- FlutterFire CLI: `dart pub global activate flutterfire_cli`
- Firebase Console account access (project: crumbs-prod)
- `firebase login` (CLI auth)

## 2. Dev onboarding (fresh clone)
- Run: `flutterfire configure --project=crumbs-prod`
- Select iOS + Android platforms
- Output: lib/firebase_options.dart, ios/Runner/GoogleService-Info.plist,
  android/app/google-services.json
- Verify: `flutter run` launches without UnimplementedError

## 3. Secret management (CI)

### macOS
```bash
base64 -i lib/firebase_options.dart | pbcopy
base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
base64 -i android/app/google-services.json | pbcopy
```

### Linux
```bash
base64 -w 0 lib/firebase_options.dart | xclip -selection clipboard
# Or stdout:
base64 -w 0 lib/firebase_options.dart
```

Paste to GitHub → Settings → Secrets and variables → Actions:
- `FIREBASE_OPTIONS_DART_B64`
- `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`
- `ANDROID_GOOGLE_SERVICES_JSON_B64`

## 4. Privacy
- `install_id` — device-local anonymous UUID (v4). PII değil. GameState.meta'da
  üretilir, cross-device save restore ile taşınır (anonymous identity, kullanıcı
  hesabı değil).
- Crashlytics `setUserIdentifier(install_id)` — anonymous identifier attachment,
  PII attach policy YOK.
- Analytics event payload'ları yalnız install_id + session_id + derived metrics
  (duration_ms, age_ms, skipped). Kullanıcı içerik (username, email, device name)
  toplanmaz.
- Legal privacy policy draft B4 kapsamında.

## 5. Crashlytics verification
(runbook from §5.3 above)

## 6. Troubleshooting
- "UnimplementedError" → flutterfire configure missing (veya CI secret eksik)
- Crashlytics no report → check setCrashlyticsCollectionEnabled, release build,
  5min delay, re-open app after crash (upload gets delayed intentionally)
- Firebase init hang → network offline; try/catch'e zaten düşer, app devam eder
- Platform build fail "GoogleService-Info.plist not found" → runbook §2
```

---

## 7. Lifecycle ordering contract

Bu sözleşme B2'nin onLaunch/onResume/onPause sıralamasını genişletir.

### 7.1 onLaunch (cold start)

```
1. WidgetsFlutterBinding.ensureInitialized()

2. FirebaseBootstrap.initialize() [B3 YENİ — AppBootstrap ÖNCESİ]
   a. try { Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform) }
   b. setAnalyticsCollectionEnabled(!kDebugMode)
   c. setCrashlyticsCollectionEnabled(!kDebugMode)
   d. FlutterError.onError = recordFlutterError (non-fatal)
   e. PlatformDispatcher.onError = recordError(fatal: true)
   f. _initialized = true
   g. catch (e, st) → debugPrint, _initialized = false (silent fallback)

3. AppBootstrap.initialize() (B2'den mevcut, +1 satır)
   a. SharedPreferences.getInstance()
   b. installIdProvider.ensureLoaded() [+ _createdAt load/write — B3]
   c. gameStateNotifierProvider.future
   d. installIdProvider.adoptFromGameState(gs.meta.installId)
   d'. if (FirebaseBootstrap.isInitialized)
          unawaited(FirebaseCrashlytics.setUserIdentifier(gs.meta.installId))
          [B3 YENİ]
   e. tutorialNotifierProvider.future
   f. sessionController.onLaunch(isFirstLaunch: !tutorialState.firstLaunchMarked)
      → SessionStart.installIdAgeMs = installIdNotifier.installIdAgeMs

4. runApp(...)
   → TutorialScaffold postFrame start() (B2 pattern korunur)
```

### 7.2 onResume (hot resume — B2'den değişmez)

```
1. sessionController.onResume() → _closeActiveSession + _startNewSession
   → yeni SessionStart.installIdAgeMs (büyümüş age — cohort relevance)
2. gameStateNotifierProvider.applyResumeDelta + resetTickClock
```

### 7.3 onPause (B2'den değişmez)

```
1. await persistNow() (I6 — persist ÖNCE)
2. sessionController.onPause() → SessionEnd (telemetry SONRA)
```

### 7.4 Invariant tests (regression)

- FirebaseBootstrap.initialize sync exception atmaz (try/catch regression)
- SessionStart.installIdAgeMs ≥ 0 production emission'da (kAgeNotLoaded=-1 sentinel integration test'te reddedilir)
- onPause ordering [I6] korunur (B2'den)

---

## 8. Invariants & DoD

### 8.1 Yeni invariants [I13]-[I17]

- **[I13]** `FirebaseBootstrap.initialize` exception throw ETMEZ — any native Firebase init failure try/catch ile yutulur, `isInitialized=false` olur, app normal flow'a devam eder
- **[I14]** `telemetryLoggerProvider` 3-state gate:
  - `kDebugMode` → `DebugLogger`
  - `!FirebaseBootstrap.isInitialized` → `DebugLogger`
  - Else → `FirebaseAnalyticsLogger`
- **[I15]** `SessionStart.installIdAgeMs ≥ 0` production path'te — `kAgeNotLoaded=-1` sentinel yalnız bootstrap race state'inde görülebilir; integration test sentinel'ı reddeder
- **[I16]** `FirebaseAnalyticsLogger.log` payload'ında bool YOK — coercion layer her bool'u int'e çevirir (`true=1, false=0`)
- **[I17]** `FlutterError.onError` non-fatal, `PlatformDispatcher.onError` fatal — policy docstring'te pin'li, B4 manual capture eklemesinde explicit `fatal:` argümanı zorunlu

### 8.2 B2 invariants korunur

[I1]-[I12] hiç değişmez. B3 sadece ekleme yapar.

### 8.3 Definition of Done

- [ ] `flutter analyze` clean (0 issue)
- [ ] `flutter test -j 1` 100% pass (hedef: +10-15 yeni test, ~210-215 toplam)
- [ ] Fork PR CI yeşil (secret decode skip edilebilir — template throw + FirebaseBootstrap.initialize catch yutması → DebugLogger fallback → test'ler geçer)
- [ ] `docs/firebase-setup.md` complete (6 section)
- [ ] `CLAUDE.md §12` yeni 2 gotcha (FirebaseBootstrap.isInitialized guard, kAgeNotLoaded sentinel)
- [ ] `docs/telemetry.md` SessionStart shape update + I15 invariant
- [ ] Invariants [I13]-[I17] regression test'te assert edilir
- [ ] Manual Crashlytics verification: release build test crash → dashboard görünür (runbook'a göre test + button silindi doğrulandı)
- [ ] Event name regex invariant (T4 test) 5 event için green
- [ ] B3 backlog `§1/1-2-3` done işaretlendi, §2-§5 B4 carryover

---

## 9. Testing strategy

### 9.1 Unit

**FirebaseBootstrap** (mocktail + firebase_core platform interface):
- Success path → isInitialized=true, FlutterError.onError ≠ default
- Firebase.initializeApp throw → catch, isInitialized=false, no uncaught exception
- Handler registration idempotency (initialize called twice → state consistent)

**FirebaseAnalyticsLogger** (mocktail MockFirebaseAnalytics):
- log(AppInstall) → logEvent('app_install', {'install_id': ..., 'platform': ...})
- log(TutorialCompleted) bool skipped=true → coerced to 1
- log(TutorialCompleted) bool skipped=false → coerced to 0
- log(event) with null payload → key absent in logEvent call
- beginSession/endSession → no _analytics method calls
- Event name regex + reserved prefix invariant (parameterize 5 events)

**InstallIdNotifier extension:**
- ensureLoaded fresh disk → _createdAt=now + pref yazıldı
- ensureLoaded existing valid ISO8601 → _createdAt parse
- ensureLoaded corrupted string → debugPrint (overridePrint capture) + reset
- installIdAgeMs fresh → 0 ≤ value < 100 (fast path)
- installIdAgeMs pre-ensureLoaded → kAgeNotLoaded (-1)
- installIdAgeMs with _createdAt in future (clock-backward) → 0 (clamp)

**SessionController:** regression — SessionStart payload contains installIdAgeMs

### 9.2 Widget

None. B3 no UI surface.

### 9.3 Integration

`integration_test/tutorial_telemetry_integration_test.dart` güncelleme:
- SessionStart events loop → `e.installIdAgeMs >= 0` AND `e.installIdAgeMs != InstallIdNotifier.kAgeNotLoaded`
- Hem fresh install hem returning user senaryolarında (cold start 2 senaryo var B2'den)

### 9.4 Manual

Firebase-side verification (no automation):
- Release build test crash → dashboard crash entry (runbook §5)
- Release build normal session → Analytics dashboard'da app_install + session_start + session_end (~30 dk gecikme)
- debugPrint'lerin debug'da görünür olması (`[TELEMETRY] ...` + `[FirebaseBootstrap] ...` varsa)

### 9.5 Test doubles

**`MockFirebaseAnalytics extends Mock implements FirebaseAnalytics`** — mocktail pattern. `FirebaseAnalyticsPlatform` platform interface mock'u gerekirse `firebase_analytics_platform_interface` paketinden.

**`MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics`** — aynı.

**Not:** Gerçek Firebase Analytics/Crashlytics platform channel çağrıları test'te YOK — tümü mocktail ile kesilir. Integration test de sim-level, device runner gerektirmez (B2 pattern korunur).

---

## 10. Task decomposition (15 task)

Etiketler: **(S)** subagent-driven TDD strict, **(C)** controller-direct, **★** critical.

| # | Task | Mode | Critical |
|---|---|---|---|
| T1 | `pubspec.yaml` — firebase_core + firebase_analytics + firebase_crashlytics dependencies | C | |
| T2 | `.gitignore` rules + `lib/firebase_options.dart.template` (throw impl) | C | |
| T3 | `FirebaseBootstrap` class + try/catch + isInitialized flag + handlers + unit test | S | ★ |
| T4 | `FirebaseAnalyticsLogger` + bool→int coercion + null drop + event name regex invariant test + mocktail unit test | S | ★ |
| T5 | `InstallIdNotifier` extension — `_createdAt` + `installIdAgeMs` + corruption log + clock-backward clamp + unit tests (+5 test) | S | ★ |
| T6 | `SessionStart.installIdAgeMs` required field — `telemetry_event.dart` + payload update + existing test update | C | |
| T7 | `SessionController._startNewSession` — installIdAgeMs wiring (no fallback) + regression test update | C | |
| T8 | `telemetryLoggerProvider` routing (3-state gate: kDebugMode + !isInitialized + else) | C | |
| T9 | `main.dart` — FirebaseBootstrap.initialize ilk adım | C | |
| T10 | `AppBootstrap` — setUserIdentifier fire-and-forget (isInitialized guard'lı) + unit test | S | |
| T11 | `.github/workflows/ci.yml` — decode step + env guard | C | |
| T12 | `docs/firebase-setup.md` — 6-section runbook (prereq, onboarding, secrets mgmt macOS+Linux, privacy, crash verify, troubleshooting) | C | |
| T13 | `CLAUDE.md §12` yeni gotcha'lar (FirebaseBootstrap.isInitialized guard pattern, kAgeNotLoaded sentinel) + `docs/telemetry.md` SessionStart shape | C | |
| T14 | `integration_test/tutorial_telemetry_integration_test.dart` — installIdAgeMs invariant assertion | S | ★ |
| T15 | B3 backlog cleanup (`docs/superpowers/backlog/sprint-b3-backlog.md` §1/1-2-3 done) | C | |

**Dağılım:**
- Subagent-driven (5): T3, T4, T5, T10, T14
- Controller-direct (10): T1, T2, T6, T7, T8, T9, T11, T12, T13, T15
- Critical ★ (4): T3, T4, T5, T14

---

## 11. Dependency DAG

```
T1 (pubspec) ──┐
               ├─► T3 (FirebaseBootstrap) ──► T8 (logger routing) ──► T9 (main.dart)
T2 (gitignore) ─┘                                                     │
                                                                       ▼
T1 ──► T4 (FirebaseAnalyticsLogger) ────────────► T8                T10 (AppBootstrap setUserIdentifier)
                                                                       │
T5 (InstallIdNotifier ext.) ──► T6 (SessionStart shape) ──► T7 (SessionController) ─┐
                                                                                     ▼
                                                        T9 + T10 tamamlandıktan sonra: T14 (integration test)
                                                                                     │
                                                                                     ▼
                                                                            T11, T12, T13, T15 (paralel-OK)
```

**Net kurallar:**
- **T1 + T2 paralel** (pubspec dependency vs gitignore/template bağımsız)
- **T3 → T8 → T9**: Provider routing FirebaseAnalyticsLogger constructor'a referans alır (T4 sonrası). T4 önce yazılmazsa T8 compile fail
- **T4 T3'e paralel-uygun** ama her ikisi de T1'e bağlı
- **T5 → T6 → T7 → T14 zinciri kritik:**
  1. T5 — InstallIdNotifier `installIdAgeMs` getter + -1 sentinel
  2. T6 — `SessionStart.installIdAgeMs` required field (B2 test'lerini kırar — T6 içinde mevcut `session_controller_test.dart` update + event şekli test update)
  3. T7 — SessionController `_startNewSession` installIdAgeMs wiring (T6 shape olmadan compile fail) + regression test update
  4. T14 — Integration test `tutorial_telemetry_integration_test.dart` installIdAgeMs invariant [I15] assertion (T6+T7 olmadan emission yok)
  - T6 atomically tamamlanmalı: shape change + test update aynı commit'te yoksa suite kırılı kalır
- **T14 (integration test) SON**: T9 + T10 wiring olmazsa full flow test edilemez
- **T11/T12/T13/T15 paralel-OK**: docs + backlog cleanup

**Subagent dispatch kuralı:** Tek seferde bir task (B2 pattern). T5 + T6 bağımsız görünse de controller-direct akışta sıralı çalıştır.

---

## 12. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Firebase CLI auth expire → flutterfire configure fail | Dev onboarding blocked | Runbook'ta `firebase login` step + token refresh troubleshooting note |
| CI secret leak via PR comment / log | API key exposure | GitHub secret scanning + `if: env != ''` guard skip secret'sız context'lerde + base64 value log'a yazılmasın (run script stderr redirect gerekebilir) |
| Analytics event name typo (reserved prefix veya regex fail) | Silent event drop | T4 parameterize regex invariant test — 5 event compile-time validation |
| Clock-backward → negative age | Dashboard pollution | Getter'da `diff < 0 ? 0 : diff` clamp (§4.2) |
| Manual crash test button ships to production | Hard crash for real users | Runbook bold ⚠️ warning + delete-step explicit checklist; B4 → dev-only flag kalıcı |
| Firebase.initializeApp hang in release (network, config issue) | App startup timeout / splash loop | Try/catch wrapper + `isInitialized=false` fallback (§3.1). `Future.timeout(5s)` eklenebilir ama B3 scope dışı — current try/catch bloklamayı zaten engeller (reject'te async resumes) |
| Firebase.instance.setAnalyticsCollectionEnabled hang | Same as above | Wrapped in outer try/catch — _initialized false kalır, provider DebugLogger'a düşer |
| `_ref.read(installIdProvider.notifier).installIdAgeMs` pre-ensureLoaded race | SessionStart.installIdAgeMs = -1 emission | AppBootstrap step b guarantees ensureLoaded ÖNCE step f (sessionController.onLaunch) — ordering contract §7; integration test -1 reddeder [I15] |
| `unawaited(setUserIdentifier)` fire-before-adopt race | Crashlytics identity=null or old installId | setUserIdentifier step d' SONRA step d (`adoptFromGameState`), sync compute — ordering deterministic |
| mocktail MockFirebaseAnalytics signature drift with firebase_analytics package upgrades | Test compilation fail | pubspec version pin + `flutter_test_analyzer` ile version mismatch check (mevcut CI step'i) |

---

## 13. Rollback plan

B3 PR merge sonrası kritik regresyon (örn. production crash loop):

1. `git revert <merge-commit>` tek komut
2. `pubspec.yaml` firebase_* dependencies otomatik kalkar (revert)
3. `FirebaseBootstrap` dosyası silinir, `main.dart` B2 haline döner
4. `telemetryLoggerProvider` B2 pattern'ine döner (yalnız DebugLogger)
5. `TelemetryLogger` interface + 5 event shape korunur — contract değişmedi
6. `SessionStart.installIdAgeMs` required field kaldırılır (B2 shape)
7. `InstallIdNotifier` B2 haline döner (`_createdAt` field silinir, pref key gitignored data olarak diskte kalabilir — next B3 attempt'te yeniden load edilir)

**Not:** B3 rollback sonrası dashboard'da B3 window'unda toplanan Analytics/Crashlytics data'sı kalır (Firebase silmez). install_id_age_ms data'sı future B3 relaunch'ta continuity sağlar.

---

## 14. Followups (B4 backlog)

B2 backlog'dan carry-over + B3 sırasında not düşülenler:

- [ ] Settings → "Developer" ekranı — kalıcı dev-only flag'li Test Crash button, tutorial replay toggle, debug panel
- [ ] Tutorial replay toggle (`TutorialNotifier.reset()`) — B2 carryover
- [ ] Purchase / Upgrade / ResearchComplete telemetry events — TelemetryEvent catalog extension
- [ ] Crashlytics breadcrumb logging (`FirebaseCrashlytics.log(msg)`) — paralel TelemetryEvent paralel yazım
- [ ] Riverpod ProviderObserver error capture — B1 ErrorScreen pattern'iyle entegre
- [ ] Crashlytics custom keys (`setCustomKey`) — session_id, game_state_version cross-filter
- [ ] Non-fatal manual captures (SaveRepository, network error) — `recordError(fatal: false)`
- [ ] `Firebase.initializeApp().timeout(5s)` — hang prevention
- [ ] Dev/prod Firebase project ayrımı — staging dashboard
- [ ] `AppInstall.installIdAgeMs` (B3'te ~0 redundant olarak drop edildi; B4'te ihtiyaç doğarsa eklenir)
- [ ] Sentry alternative evaluation (Crashlytics alternatifi)
- [ ] Firebase Messaging (push notifications) — ayrı sprint
- [ ] Firebase Remote Config — balance tuning + feature flag
- [ ] Legal privacy policy draft
- [ ] Spec/plan docs drift cleanup (B2 backlog §2 T3)
- [ ] I12 negative contract test (TutorialScaffold non-router mount → throw)
- [ ] **AppInstall trigger source canonical form:** B2/B3 `isFirstLaunch = !tutorialState.firstLaunchMarked` pattern'i tutorialState'i "first device boot" sinyali olarak re-purpose ediyor — semantic drift. Ayrı `firstBootProvider` (SharedPreferences-backed, tutorial state'inden disjoint) veya `installIdAgeMs < 5000` derivation. Hangisi canonical olsun? B4'te karar

---

## 15. Referans

- `cookie_clicker_derivative_prd.md §11 (telemetry)`
- `docs/telemetry.md`
- `docs/superpowers/specs/2026-04-17-sprint-b2-tutorial-telemetry-design.md` (B2 spec, TelemetryEvent/TelemetryLogger/InstallIdNotifier foundation)
- `docs/superpowers/backlog/sprint-b3-backlog.md §1/1-2-3`
- `CLAUDE.md §2 (tech stack), §12 (gotcha'lar)`
- Firebase Flutter docs: https://firebase.flutter.dev/docs/overview
- Firebase Analytics event naming: https://firebase.google.com/docs/analytics/events
- FlutterFire CLI: https://firebase.flutter.dev/docs/cli
