# Sprint B3 — Production Telemetry Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** B2 stub-first telemetry pipeline'ını Firebase Analytics'e bağla, Crashlytics error reporting aktif et, `install_id_age_ms` payload ile SessionStart cohort analytics unlock et. TelemetryLogger interface (B2) değişmez — tek dosya swap noktası (`telemetry_providers.dart`).

**Architecture:** Yeni `FirebaseBootstrap` singleton (3-phase init: fatal initializeApp → best-effort collection flags → sync handler register) main() başında AppBootstrap'tan ÖNCE çağrılır. `FirebaseAnalyticsLogger implements TelemetryLogger` thin adapter — fire-and-forget `unawaited(logEvent)` + `bool→int` coercion + null drop. `InstallIdNotifier` genişletilir — `_createdAt` device-local SharedPreferences-backed, `installIdAgeMs` getter + `-1` sentinel + clock-backward clamp. `SessionStart` payload'a `installIdAgeMs: int` eklenir. Crashlytics `setUserIdentifier` AppBootstrap step d' sonrası fire-and-forget. Firebase config dosyaları gitignored; Dart-only template commit edilir (throws UnimplementedError); CI secret decode step fork-safe `env.FIREBASE_OPTIONS_DART_B64 != ''` guard'lı.

**Tech Stack:** Flutter 3.41.5, Dart 3.11, Riverpod 3.1, freezed 3.0, firebase_core 4.7, firebase_analytics 12.3, firebase_crashlytics 5.x, mocktail (test), shared_preferences 2.3, uuid 4.5. Sprint A + B1 + B2 altyapısı korunur (TelemetryLogger interface, AsyncNotifier pattern, AppLifecycleListener, save race lock).

**Referans:** `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md` (spec — 7 clarifying Q + 4 review fixes applied).

---

## Önkoşullar (plan öncesi)

- **Sprint B2 merge edilmiş:** PR #4 (`sprint/b2-tutorial-telemetry`) main'e merge edilmiş olmalı. B3 branch'i main'den çıkar.
- **B3 branch oluşturuldu:** `sprint/b3-telemetry-activation` (spec commit'i bu branch'te).
- **Flutter 3.41.5 FVM pinned:** `fvm use 3.41.5` veya system flutter pin.
- **Firebase Console access:** `crumbs-prod` (veya equivalent) Firebase project hsnbilici account'ta erişilebilir — `flutterfire configure` bu account'tan auth'la çalışır.
- **FlutterFire CLI kurulu:** `dart pub global activate flutterfire_cli`.
- **Baseline:** `flutter test -j 1` 197 pass (B2 sonrası), `flutter analyze` 0 issue.

```bash
git checkout main
git pull origin main
git checkout sprint/b3-telemetry-activation  # branch zaten mevcut (spec commit'i)
flutter pub get
flutter test -j 1  # 197 pass baseline
flutter analyze  # 0 issue baseline
```

---

## Dependency Chain

```
T1 (pubspec firebase_crashlytics) ─┐
                                    ├─► T3 (FirebaseBootstrap) ─► T8 (logger routing) ─► T9 (main.dart boot)
T2 (.gitignore + Dart template) ───┘           │                                          │
                                               │                                          ▼
              ┌────────────────────────────────┘                                    T10 (AppBootstrap setUserIdentifier)
              ▼                                                                            │
    T4 (FirebaseAnalyticsLogger + event name regex) ─► T8                                 │
                                                                                            │
T5 (InstallIdNotifier ext.) ─► T6 (SessionStart shape) ─► T7 (SessionController) ──────────┤
                                                                                            ▼
                                                                     T14 (integration test — installIdAgeMs invariant)
                                                                                            │
                                                                                            ▼
                                                                     T11, T12, T13, T15 (paralel-OK — docs/CI/backlog)
```

**Kritik kurallar:**
- T1 + T2 paralel OK
- **T5 → T6 → T7 → T14 atomic chain** — T6 shape change B2 test'lerini kırar, aynı commit'te test update zorunlu
- T3 → T8 → T9 sıralı (provider routing'in FirebaseAnalyticsLogger reference'ı T4'te tanımlı)
- T14 (integration test) SON — T9 + T10 wiring olmazsa full flow test edilemez

**Task modu:** `(S)` = subagent-driven TDD strict, `(C)` = controller-direct.

---

## Task 1 (C): pubspec.yaml — firebase_crashlytics dependency

**Amaç:** `firebase_crashlytics` ^5.0.0'ı dependencies'e ekle. `firebase_core` ^4.7.0 + `firebase_analytics` ^12.3.0 zaten mevcut (B2 pubspec'te listeli ama kullanılmıyordu).

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: pubspec.yaml dependencies bölümüne ekle**

`pubspec.yaml`'da `firebase_analytics: ^12.3.0` satırının ardına ekle:

```yaml
  firebase_crashlytics: ^5.0.0
```

- [ ] **Step 2: Dev dependency mocktail ekle (test için)**

`pubspec.yaml` `dev_dependencies:` bölümü altında `mocktail` zaten mevcut olabilir — kontrol et. Yoksa ekle:

```yaml
dev_dependencies:
  # ... mevcut
  mocktail: ^1.0.4
```

`grep mocktail pubspec.yaml` → mevcut ise skip.

- [ ] **Step 3: flutter pub get**

Run: `flutter pub get`
Expected: Resolving dependencies... Got dependencies! (firebase_crashlytics version 5.x.x çözüldü)

- [ ] **Step 4: Verify analyze baseline**

Run: `flutter analyze`
Expected: No issues found. (B3 code değişimi yok; sadece pubspec)

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "sprint-b3(T1): add firebase_crashlytics dependency"
```

---

## Task 2 (C): .gitignore rules + Dart template

**Amaç:** Firebase config dosyalarını gitignore'a ekle, `lib/firebase_options.dart.template` commit et (explicit throw — silent template ships riskini ortadan kaldırır).

**Files:**
- Modify: `.gitignore`
- Create: `lib/firebase_options.dart.template`

- [ ] **Step 1: .gitignore'a Firebase rules ekle**

`.gitignore` sonuna ekle (son satırdan önce):

```
# Firebase — committed: Dart template only; native configs via flutterfire
# configure (dev) OR CI secret decode (PR/main). See docs/firebase-setup.md.
lib/firebase_options.dart
ios/Runner/GoogleService-Info.plist
ios/firebase_app_id_file.json
android/app/google-services.json
```

- [ ] **Step 2: Dart template oluştur**

Create `lib/firebase_options.dart.template`:

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

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/firebase_options.dart.template`
Expected: Template dosyası `.dart` uzantılı değil (`.dart.template`) — analyze bu dosyayı skip eder. 0 issue.

- [ ] **Step 4: Commit**

```bash
git add .gitignore lib/firebase_options.dart.template
git commit -m "sprint-b3(T2): gitignore Firebase configs + Dart throw template"
```

---

## Task 3 (S) ★: FirebaseBootstrap — 3-phase init

**Amaç:** `FirebaseBootstrap` singleton — phase 1 fatal `initializeApp` (fail → early return + `_initialized=false`), phase 2 best-effort collection flags (fail loglanır, native init preserved → no duplicate app on next launch), phase 3 sync handler register (FlutterError non-fatal + PlatformDispatcher fatal).

**Files:**
- Create: `lib/app/boot/firebase_bootstrap.dart`
- Create: `test/app/boot/firebase_bootstrap_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/app/boot/firebase_bootstrap_test.dart`:

```dart
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseBootstrap', () {
    test('initial state — isInitialized false', () {
      expect(FirebaseBootstrap.isInitialized, isFalse);
    });

    test('initialize() does not throw even if Firebase platform unavailable',
        () async {
      // Test environment'ta Firebase platform plugin register edilmemiş —
      // initializeApp exception atar. FirebaseBootstrap.initialize try/catch
      // ile yutmalı ve exception atmamalı.
      await expectLater(
        () => FirebaseBootstrap.initialize(),
        returnsNormally,
      );
      // Sonraki assertions — test env'da phase 1 fail → isInitialized false
      expect(FirebaseBootstrap.isInitialized, isFalse);
    });

    test('isInitialized is static state accessor', () {
      // Public API contract: sync bool getter, exception atmaz
      // ignore: unused_local_variable
      final value = FirebaseBootstrap.isInitialized;
      expect(value, isA<bool>());
    });
  });

  // Not: Phase 2/3 full coverage için Firebase.initializeApp mock gerekir
  // (platform interface override). mocktail + firebase_core_platform_interface
  // entegrasyonu kapsamlı ama B3 scope'ta phase 1 fail → isInitialized=false
  // integration test (T14) ile korunur. Bu test seti "initialize throw etmez"
  // ve "isInitialized state accessor" kontratlarını korur.
}
```

- [ ] **Step 2: Run test — fail**

Run: `flutter test test/app/boot/firebase_bootstrap_test.dart`
Expected: FAIL — `firebase_bootstrap.dart` yok (`uri_does_not_exist`).

- [ ] **Step 3: Implementation**

Create `lib/app/boot/firebase_bootstrap.dart`:

```dart
import 'dart:ui' show PlatformDispatcher;

import 'package:crumbs/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase core bootstrap — main()'de AppBootstrap ÖNCESİ çağrılır.
///
/// 3-phase strateji:
/// - **Phase 1 (fatal):** Firebase.initializeApp — fail'de early return,
///   `_initialized=false`, app Firebase'siz devam eder (telemetry no-op).
/// - **Phase 2 (best-effort):** setAnalyticsCollectionEnabled +
///   setCrashlyticsCollectionEnabled — fail loglanır ama init çökertmez
///   (native Firebase.instance preserved, sonraki launch'ta duplicate app
///   hatası önlenir).
/// - **Phase 3 (sync):** FlutterError.onError + PlatformDispatcher.onError
///   register — exception atmaz.
///
/// `isInitialized` flag telemetry logger gate'i için okur (telemetry_providers
/// 3-state gate). Phase 2/3 tamamlanmadan true olmaz.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    // Phase 1 — fatal init (native Firebase app binding)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] initializeApp failed, '
        'telemetry disabled: $e\n$st',
      );
      return; // _initialized false kalır
    }

    // Phase 2 — best-effort data transmission gate
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(!kDebugMode);
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e, st) {
      debugPrint(
        '[FirebaseBootstrap] collection flag set failed '
        '(non-fatal): $e\n$st',
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

- [ ] **Step 4: firebase_options.dart dev stub oluştur (gitignored)**

Test'lerin `import 'package:crumbs/firebase_options.dart'` compile etmesi için dev stub gerekli. `lib/firebase_options.dart` (gitignored — commit edilmez):

Create `lib/firebase_options.dart`:

```dart
// ignore_for_file: type=lint
// DEV STUB — gitignored. Gerçek değer flutterfire configure ile üretilir.
// Template: lib/firebase_options.dart.template (repo'da).
// Bu stub test ortamında compile eder; runtime'da
// FirebaseBootstrap.initialize try/catch yutar.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      'lib/firebase_options.dart is a dev stub. '
      'Run `flutterfire configure` to generate real values.',
    );
  }
}
```

Verify: `git check-ignore lib/firebase_options.dart` → path shown (gitignored).

- [ ] **Step 5: Run test — pass**

Run: `flutter test test/app/boot/firebase_bootstrap_test.dart`
Expected: PASS (3 test).

Not: Test çıktısında `[FirebaseBootstrap] initializeApp failed, telemetry disabled: ...` debugPrint görünür — expected behavior (test env'da Firebase platform yok).

- [ ] **Step 6: Verify analyze + full suite**

Run:
```bash
flutter analyze
flutter test -j 1
```

Expected: analyze 0 issue; full suite 200 pass (197 baseline + 3 yeni B3 test).

- [ ] **Step 7: Commit**

```bash
git add lib/app/boot/firebase_bootstrap.dart test/app/boot/firebase_bootstrap_test.dart
git commit -m "sprint-b3(T3): FirebaseBootstrap 3-phase init + static isInitialized"
```

**Not:** `lib/firebase_options.dart` gitignored — staged değil. `git status` ile verify et (`lib/firebase_options.dart` untracked ama ignored olarak listelenir veya hiç listelenmez).

---

## Task 4 (S) ★: FirebaseAnalyticsLogger + event name regex invariant

**Amaç:** `FirebaseAnalyticsLogger implements TelemetryLogger` adapter — fire-and-forget + `bool→int` coercion + null drop. Event name Firebase compliance regex invariant test (B3 scope'ta 5 event + gelecek eventler için).

**Files:**
- Create: `lib/core/telemetry/firebase_analytics_logger.dart`
- Create: `test/core/telemetry/firebase_analytics_logger_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/core/telemetry/firebase_analytics_logger_test.dart`:

```dart
import 'package:crumbs/core/telemetry/firebase_analytics_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late _MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsLogger logger;

  setUp(() {
    analytics = _MockFirebaseAnalytics();
    logger = FirebaseAnalyticsLogger(analytics);
    // mocktail default logEvent future — no-op
    when(() => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});
  });

  group('FirebaseAnalyticsLogger — log()', () {
    test('AppInstall → logEvent("app_install", {install_id, platform})', () {
      logger.log(const AppInstall(installId: 'abc', platform: 'ios'));
      verify(() => analytics.logEvent(
            name: 'app_install',
            parameters: {'install_id': 'abc', 'platform': 'ios'},
          )).called(1);
    });

    test('SessionStart payload passes through with installIdAgeMs', () {
      logger.log(const SessionStart(
        installId: 'abc',
        sessionId: 's1',
        installIdAgeMs: 12345,
      ));
      verify(() => analytics.logEvent(
            name: 'session_start',
            parameters: {
              'install_id': 'abc',
              'session_id': 's1',
              'install_id_age_ms': 12345,
            },
          )).called(1);
    });

    test('TutorialCompleted bool skipped=true → coerced to int 1', () {
      logger.log(const TutorialCompleted(
        installId: 'abc',
        skipped: true,
        durationMs: 3000,
      ));
      verify(() => analytics.logEvent(
            name: 'tutorial_completed',
            parameters: {
              'install_id': 'abc',
              'skipped': 1, // bool true → 1
              'duration_ms': 3000,
            },
          )).called(1);
    });

    test('TutorialCompleted bool skipped=false → coerced to int 0', () {
      logger.log(const TutorialCompleted(
        installId: 'abc',
        skipped: false,
        durationMs: 3000,
      ));
      verify(() => analytics.logEvent(
            name: 'tutorial_completed',
            parameters: {
              'install_id': 'abc',
              'skipped': 0, // bool false → 0
              'duration_ms': 3000,
            },
          )).called(1);
    });
  });

  group('FirebaseAnalyticsLogger — beginSession/endSession no-op', () {
    test('beginSession does not call any analytics method', () {
      logger.beginSession();
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });

    test('endSession does not call any analytics method', () {
      logger.endSession();
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });
  });

  group('FirebaseAnalyticsLogger — Firebase compliance invariant', () {
    // Invariant: her TelemetryEvent'in eventName'i Firebase Analytics kuralına
    // uygun. Yeni event eklendiğinde bu test compile-time contract gibi korur.
    final events = <TelemetryEvent>[
      const AppInstall(installId: 'x', platform: 'ios'),
      const SessionStart(installId: 'x', sessionId: 'y', installIdAgeMs: 0),
      const SessionEnd(installId: 'x', sessionId: 'y', durationMs: 0),
      const TutorialStarted(installId: 'x'),
      const TutorialCompleted(installId: 'x', skipped: false, durationMs: 0),
    ];

    final nameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
    const reservedPrefixes = ['firebase_', 'google_', 'ga_'];

    for (final event in events) {
      test('${event.eventName} matches Firebase name regex', () {
        expect(
          nameRegex.hasMatch(event.eventName),
          isTrue,
          reason:
              '${event.eventName} Firebase regex ^[a-zA-Z][a-zA-Z0-9_]{0,39}\$ '
              'ihlal ediyor',
        );
      });

      test('${event.eventName} has no reserved prefix', () {
        for (final prefix in reservedPrefixes) {
          expect(
            event.eventName.startsWith(prefix),
            isFalse,
            reason: '${event.eventName} reserved prefix "$prefix" kullanıyor',
          );
        }
      });
    }
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/firebase_analytics_logger_test.dart`
Expected: FAIL — `firebase_analytics_logger.dart` yok.

- [ ] **Step 3: Implementation**

Create `lib/core/telemetry/firebase_analytics_logger.dart`:

```dart
import 'dart:async';

import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase Analytics'e TelemetryEvent adapter.
///
/// **Payload coercion:** Firebase Analytics `logEvent(parameters)` sadece
/// `String/int/double` kabul eder (bool desteklenmez). `bool → int` çevrilir
/// (true=1, false=0), null değerler drop edilir.
///
/// **Fire-and-forget:** `unawaited(logEvent)` UI latency optimize eder.
/// Hızlı ardışık event'lerde Firebase SDK emission sırası GARANTİLİ DEĞİL
/// (platform channel queueing). B3 event cadence saatlik/session seviyesinde;
/// ordering issue yok. Daha sıkı ordering gerekirse Completer chain B4'te.
///
/// **Session hooks:** Firebase Analytics otomatik session tracking yapar
/// (engagement time). Manual session API yok — beginSession/endSession no-op.
class FirebaseAnalyticsLogger implements TelemetryLogger {
  FirebaseAnalyticsLogger(this._analytics);
  final FirebaseAnalytics _analytics;

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

  @override
  void beginSession() {} // no-op (Firebase auto session)

  @override
  void endSession() {} // no-op
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/telemetry/firebase_analytics_logger_test.dart`
Expected: PASS (4 log tests + 2 no-op tests + 10 compliance tests = 16 test).

- [ ] **Step 5: Verify analyze**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/core/telemetry/firebase_analytics_logger.dart \
        test/core/telemetry/firebase_analytics_logger_test.dart
git commit -m "sprint-b3(T4): FirebaseAnalyticsLogger adapter + event name regex invariant"
```

---

## Task 5 (S) ★: InstallIdNotifier extension — `_createdAt` + `installIdAgeMs`

**Amaç:** `InstallIdNotifier`'a `_prefKeyCreatedAt` + `_createdAt` field + `installIdAgeMs` getter (kAgeNotLoaded=-1 sentinel + clock-backward clamp) ekle. `ensureLoaded` genişlet: pref mevcut+parse OK → load; pref mevcut+corrupt → debugPrint + reset; pref yok → now yaz.

**Files:**
- Modify: `lib/core/telemetry/install_id_notifier.dart`
- Modify: `test/core/telemetry/install_id_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

Mevcut `test/core/telemetry/install_id_notifier_test.dart`'ın main()'inin sonuna yeni group ekle:

```dart
  group('InstallIdNotifier — installIdAgeMs (B3)', () {
    test('pre-ensureLoaded → kAgeNotLoaded (-1)', () {
      final c = buildContainer();
      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, InstallIdNotifier.kAgeNotLoaded);
      expect(InstallIdNotifier.kAgeNotLoaded, -1);
    });

    test('fresh disk → _createdAt=now + pref yazıldı + age in [0, 100ms]',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final notifier = c.read(installIdProvider.notifier);
      final age = notifier.installIdAgeMs;
      expect(age, greaterThanOrEqualTo(0));
      expect(age, lessThan(5000),
          reason: 'fresh _createdAt just wrote; age well under 5s');

      final prefs = await SharedPreferences.getInstance();
      final createdAtStr = prefs.getString('crumbs.install_created_at');
      expect(createdAtStr, isNotNull);
      expect(DateTime.tryParse(createdAtStr!), isNotNull);
    });

    test('existing valid pref → _createdAt parse → age > 0', () async {
      final oneMinuteAgo =
          DateTime.now().subtract(const Duration(minutes: 1));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': oneMinuteAgo.toIso8601String(),
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, greaterThanOrEqualTo(60000)); // ≥ 1 min in ms
      expect(age, lessThan(120000)); // < 2 min (generous upper)
    });

    test('corrupted pref → debugPrint + reset to now', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': 'not-a-valid-iso-8601',
      });

      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) logs.add(msg);
      };

      try {
        final c = buildContainer();
        await c.read(installIdProvider.notifier).ensureLoaded();

        // Corruption log emitted
        expect(
          logs.any((l) =>
              l.contains('install_created_at parse failed') &&
              l.contains('not-a-valid-iso-8601')),
          isTrue,
          reason: 'corruption debugPrint forensic log bekleniyor',
        );

        // Pref reset edildi — fresh now
        final prefs = await SharedPreferences.getInstance();
        final reset = prefs.getString('crumbs.install_created_at');
        expect(reset, isNotNull);
        expect(DateTime.tryParse(reset!), isNotNull);

        // Age artık fresh
        final age = c.read(installIdProvider.notifier).installIdAgeMs;
        expect(age, greaterThanOrEqualTo(0));
        expect(age, lessThan(5000));
      } finally {
        debugPrint = originalDebugPrint;
      }
    });

    test('clock-backward (_createdAt in future) → 0 clamp', () async {
      final oneHourFuture =
          DateTime.now().add(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'crumbs.install_created_at': oneHourFuture.toIso8601String(),
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();

      final age = c.read(installIdProvider.notifier).installIdAgeMs;
      expect(age, 0,
          reason: 'negative diff (user clock moved backward) → clamp to 0');
    });
  });
```

**Import gerekli (test dosyasının başına):** zaten mevcut import'lar + `package:flutter/foundation.dart` for `debugPrint`:

Test dosyasının başındaki import bloğunda kontrol et, eksikse ekle:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/install_id_notifier_test.dart`
Expected: FAIL — `installIdAgeMs` getter, `_prefKeyCreatedAt`, `kAgeNotLoaded` yok.

- [ ] **Step 3: Implementation**

`lib/core/telemetry/install_id_notifier.dart`'ı güncelle. Mevcut class:

```dart
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKey = 'crumbs.install_id';
  static const kNotLoadedSentinel = '<not-loaded>';
```

Genişlet (yeni sabitler + field + getter ekle + ensureLoaded genişlet):

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Install ID'nin tek kaynağı (SharedPreferences).
/// Boot: ensureLoaded() → adoptFromGameState(gs.meta.installId)
/// (GameState-wins: GameState'teki değer authoritative, disk farklıysa
/// overwrite edilir).
/// Telemetry payload için:
///   `resolveInstallIdForTelemetry(ref.read(installIdProvider))`
/// şeklinde çağır — null ise `<not-loaded>` sentinel döner (invariant I1).
///
/// B3 genişlemesi: `_createdAt` (SharedPreferences-backed, device-local) +
/// `installIdAgeMs` getter. SessionStart payload `install_id_age_ms` için
/// kullanılır (invariant [I15]).
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKeyId = 'crumbs.install_id';
  static const _prefKeyCreatedAt = 'crumbs.install_created_at';
  static const kNotLoadedSentinel = '<not-loaded>';
  static const int kAgeNotLoaded = -1;

  DateTime? _createdAt;

  @override
  String? build() => null;

  /// Install creation timestamp — device-local (SharedPreferences).
  /// Cross-device save restore'da bu device'ın ilk boot'unda yazılır.
  /// [ensureLoaded] sonrası güvenilir.
  DateTime? get installCreatedAt => _createdAt;

  /// `_createdAt`'den `DateTime.now()`'a ms. Pre-ensureLoaded: [kAgeNotLoaded]
  /// (-1). Clock-backward (user cihaz saatini geri aldı) → 0 clamp (negative
  /// dashboard aggregation'ı kirletir).
  int get installIdAgeMs {
    final c = _createdAt;
    if (c == null) return kAgeNotLoaded;
    final diff = DateTime.now().difference(c).inMilliseconds;
    return diff < 0 ? 0 : diff;
  }

  /// Boot sırasında, GameState hydrate'den ÖNCE çağrılır.
  /// State SharedPreferences'taki değerle (veya null ile) doldurulur.
  /// `_createdAt` pref yüklenir; yoksa now yazılır; parse fail'de corruption
  /// debugPrint + reset to now.
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKeyId);

    final createdAtStr = prefs.getString(_prefKeyCreatedAt);
    if (createdAtStr != null) {
      _createdAt = DateTime.tryParse(createdAtStr);
      if (_createdAt == null) {
        debugPrint(
          '[InstallIdNotifier] install_created_at parse failed '
          '(value: "$createdAtStr") — resetting to now. '
          'Install appears new in telemetry.',
        );
      }
    }
    if (_createdAt == null) {
      _createdAt = DateTime.now();
      await prefs.setString(
        _prefKeyCreatedAt,
        _createdAt!.toIso8601String(),
      );
    }
  }

  /// Boot sırasında, GameState hydrate sonrası çağrılır.
  /// GameState-wins: GameState.meta.installId her zaman authoritative;
  /// disk farklıysa disk'teki değer overwrite edilir.
  Future<void> adoptFromGameState(String savedInstallId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKeyId);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKeyId, savedInstallId);
    }
    state = savedInstallId;
  }
}

final installIdProvider =
    NotifierProvider<InstallIdNotifier, String?>(InstallIdNotifier.new);

/// Telemetry invariant guard.
/// Maps a raw install_id value (from `Ref.read(installIdProvider)`,
/// `WidgetRef.read(installIdProvider)`, or
/// `ProviderContainer.read(installIdProvider)`)
/// to either the loaded String or the `<not-loaded>` sentinel.
///
/// Caller is responsible for the `.read()` — this keeps the helper
/// compatible with all three Riverpod 3.1 read contexts.
///
/// Integration test: if this sentinel appears in production emission,
/// test fails (invariant I1).
String resolveInstallIdForTelemetry(String? rawValue) {
  return rawValue ?? InstallIdNotifier.kNotLoadedSentinel;
}
```

**Not:** `_prefKey` → `_prefKeyId` rename (okumayı netleştirir — iki pref key'i var artık). Mevcut B2 kullanımları sadece bu dosyada olduğu için değişim localize (test dosyası da string literal kullanıyor, değişmesine gerek yok).

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/telemetry/install_id_notifier_test.dart`
Expected: PASS — B2 (7 test) + B3 (5 yeni test) = 12 test.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/core/telemetry/install_id_notifier.dart test/core/telemetry/install_id_notifier_test.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/core/telemetry/install_id_notifier.dart \
        test/core/telemetry/install_id_notifier_test.dart
git commit -m "sprint-b3(T5): InstallIdNotifier _createdAt + installIdAgeMs + clamp + corruption log"
```

---

## Task 6 (C): SessionStart.installIdAgeMs required field — shape + event test update

**Amaç:** `SessionStart` freezed-olmayan sealed hierarchy'ye `installIdAgeMs: int` required field ekle. Payload map'e `'install_id_age_ms': installIdAgeMs` ekle. B2 `telemetry_event_test.dart` çağrılarını yeni imzaya update et (atomic — shape + test update aynı commit).

**Files:**
- Modify: `lib/core/telemetry/telemetry_event.dart`
- Modify: `test/core/telemetry/telemetry_event_test.dart`

- [ ] **Step 1: Modify `SessionStart` class**

`lib/core/telemetry/telemetry_event.dart` içinde mevcut `SessionStart`:

```dart
class SessionStart extends TelemetryEvent {
  const SessionStart({required this.installId, required this.sessionId});

  final String installId;
  final String sessionId;

  @override
  String get eventName => 'session_start';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
      };
}
```

Şununla değiştir:

```dart
class SessionStart extends TelemetryEvent {
  const SessionStart({
    required this.installId,
    required this.sessionId,
    required this.installIdAgeMs,
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

- [ ] **Step 2: Test update — telemetry_event_test.dart SessionStart tests**

`test/core/telemetry/telemetry_event_test.dart` içinde mevcut `group('TelemetryEvent — SessionStart', ...)`:

Eski:
```dart
group('TelemetryEvent — SessionStart', () {
  test('eventName is session_start', () {
    const e = SessionStart(installId: 'abc', sessionId: 'sess-1');
    expect(e.eventName, 'session_start');
  });

  test('payload has install_id and session_id', () {
    const e = SessionStart(installId: 'abc', sessionId: 'sess-1');
    expect(e.payload, {'install_id': 'abc', 'session_id': 'sess-1'});
  });
});
```

Şununla değiştir:

```dart
group('TelemetryEvent — SessionStart', () {
  test('eventName is session_start', () {
    const e = SessionStart(
      installId: 'abc',
      sessionId: 'sess-1',
      installIdAgeMs: 0,
    );
    expect(e.eventName, 'session_start');
  });

  test('payload has install_id, session_id, install_id_age_ms', () {
    const e = SessionStart(
      installId: 'abc',
      sessionId: 'sess-1',
      installIdAgeMs: 12345,
    );
    expect(e.payload, {
      'install_id': 'abc',
      'session_id': 'sess-1',
      'install_id_age_ms': 12345,
    });
  });
});
```

Exhaustive pattern-match test'inde SessionStart instance yok (AppInstall kullanıyor) — o dokunulmaz.

- [ ] **Step 3: Run — fail/pass**

Run: `flutter test test/core/telemetry/telemetry_event_test.dart`
Expected: PASS (11 test — shape + payload assertions güncellendi). Önceki tüm test'ler yeşil.

Eğer B2'deki `SessionStart` kullanan başka test dosyaları varsa compile fail ederler. Next step'lerde (T7 + T14) düzelteceğiz, ama şimdi sadece event test'ini doğrula.

- [ ] **Step 4: Run full suite — expect session_controller + integration test compile fail**

Run: `flutter analyze`
Expected: **ERROR** — `test/core/telemetry/session_controller_test.dart` içinde `SessionStart(installId: ..., sessionId: ...)` çağrıları `installIdAgeMs` required parametresi eksik, compile fail.

Benzer şekilde `integration_test/tutorial_telemetry_integration_test.dart` fail eder.

Bu **beklenen** — T7 ve T14 bu compile fail'leri fix eder. Aşağıdaki T7 step'te session_controller_test güncellenir.

**Commit'i T7 sonrasına erteleme yok** — T6'nın atomic unit'ı `telemetry_event.dart` + `telemetry_event_test.dart`. Ama full suite geçmeli. Seçenek:

Opsiyon A (tercih): T6 + T7 + T14 atomically tek commit'te (chain).
Opsiyon B: T6 commit — downstream compile fail'i not düşülür, T7 hemen takip eder.

Plan bu TDD flow'da Opsiyon B tercih ediyor (her task ayrı commit) ama compile red state kabul edilir. T7 çabucak takip eder.

- [ ] **Step 5: Commit (T6 atomic — shape + event test güncel, downstream T7 bekliyor)**

```bash
git add lib/core/telemetry/telemetry_event.dart test/core/telemetry/telemetry_event_test.dart
git commit -m "sprint-b3(T6): SessionStart.installIdAgeMs required field (shape + event test)"
```

**UYARI:** Bu commit'ten sonra `flutter test` full suite FAIL eder — `session_controller_test.dart` compile fail. T7 derhal takip etmeli. Git history bu intermediate state'i gösterir ama normaldir — atomic chain T6→T7→T14 beklenen flow.

---

## Task 7 (C): SessionController._startNewSession — installIdAgeMs wiring + test fix

**Amaç:** `_startNewSession` içinde `installIdAgeMs` parametresini `InstallIdNotifier.installIdAgeMs` getter'ından oku (no `?? 0` fallback — sentinel -1 production'da reddedilir). `session_controller_test.dart`'taki `SessionStart` assertion'larını ve mock setup'ını yeni imzayla update et.

**Files:**
- Modify: `lib/core/telemetry/session_controller.dart`
- Modify: `test/core/telemetry/session_controller_test.dart`

- [ ] **Step 1: Modify _startNewSession**

`lib/core/telemetry/session_controller.dart` içinde `_startNewSession`:

Eski:
```dart
void _startNewSession(String installId) {
  _currentSessionId = const Uuid().v4();
  _sessionStartedAt = DateTime.now();
  _logger.beginSession();
  _logger.log(SessionStart(
    installId: installId,
    sessionId: _currentSessionId!,
  ));
}
```

Şununla değiştir:

```dart
void _startNewSession(String installId) {
  _currentSessionId = const Uuid().v4();
  _sessionStartedAt = DateTime.now();
  _logger.beginSession();
  _logger.log(SessionStart(
    installId: installId,
    sessionId: _currentSessionId!,
    // AppBootstrap step b'de ensureLoaded garanti; kAgeNotLoaded (-1)
    // bypass bug sinyali — integration test [I15] bu sentinel'ı reddeder.
    installIdAgeMs: _ref.read(installIdProvider.notifier).installIdAgeMs,
  ));
}
```

- [ ] **Step 2: Update session_controller_test.dart SessionStart expectations**

`test/core/telemetry/session_controller_test.dart` — her `SessionStart` cast'i `installIdAgeMs` field'i kontrol edecek şekilde genişlet. Mevcut test'leri inspect et ve şu pattern'leri güncelle:

Test 1 — "SessionStart carries non-null install_id":

Mevcut:
```dart
test('SessionStart carries non-null install_id', () async {
  // ... setup
  c.read(sessionControllerProvider).onLaunch(isFirstLaunch: false);

  final start = logger.events.single as SessionStart;
  expect(start.installId, 'test-id');
  expect(start.sessionId, isNotEmpty);
});
```

Değiştir:
```dart
test('SessionStart carries non-null install_id + installIdAgeMs', () async {
  SharedPreferences.setMockInitialValues({
    'crumbs.install_id': 'test-id',
  });
  final logger = _FakeLogger();
  final c = buildContainer(logger);
  await c.read(installIdProvider.notifier).ensureLoaded();
  c.read(sessionControllerProvider).onLaunch(isFirstLaunch: false);

  final start = logger.events.single as SessionStart;
  expect(start.installId, 'test-id');
  expect(start.sessionId, isNotEmpty);
  expect(start.installIdAgeMs, greaterThanOrEqualTo(0));
  expect(start.installIdAgeMs, isNot(InstallIdNotifier.kAgeNotLoaded));
});
```

Test 2 — "emits new SessionStart with new session_id" — shape OK ama `logger.events.whereType<SessionStart>().last.sessionId` patterni kalır. Değişiklik yok. (Compile fail SessionStart constructor'dan gelmiyor — event objesi logger'dan okunuyor.)

Test 3 — double-resume fix test (bug_003 B2'de landed):

Mevcut `closes prior unclosed session on double-resume (bug_003)` test içinde `SessionStart` objesi yeni field'ı taşıyor — yapısal değişiklik yok.

Test 4 — "install_id not loaded sentinel":

Mevcut:
```dart
test('emits <not-loaded> when installIdProvider null', () {
  SharedPreferences.setMockInitialValues({});
  // ...
  c.read(sessionControllerProvider).onLaunch(isFirstLaunch: false);

  final start = logger.events.single as SessionStart;
  expect(start.installId, '<not-loaded>');
});
```

`SharedPreferences.setMockInitialValues({})` ensureLoaded çağrılmazsa installIdAgeMs kAgeNotLoaded döner — bu case defansif. Test'e defensive assertion ekle:

```dart
test('emits <not-loaded> when installIdProvider null (+ age sentinel)', () {
  SharedPreferences.setMockInitialValues({});
  final logger = _FakeLogger();
  final c = ProviderContainer(overrides: [
    telemetryLoggerProvider.overrideWithValue(logger),
  ]);
  addTearDown(c.dispose);
  // ensureLoaded ÇAĞRILMADI — onLaunch bypass bug senaryosunu simüle eder
  c.read(sessionControllerProvider).onLaunch(isFirstLaunch: false);

  final start = logger.events.single as SessionStart;
  expect(start.installId, '<not-loaded>');
  expect(start.installIdAgeMs, InstallIdNotifier.kAgeNotLoaded,
      reason: 'ensureLoaded bypass → -1 sentinel (integration test reddeder)');
});
```

- [ ] **Step 3: Run — pass (both files compile + tests green)**

Run: `flutter test test/core/telemetry/session_controller_test.dart`
Expected: PASS (B2'den 7 test + B3 assertion genişlemesi).

- [ ] **Step 4: Full suite partial check**

Run: `flutter analyze`
Expected: **yalnız integration test compile fail kalır** (`integration_test/tutorial_telemetry_integration_test.dart` — T14'te fix edilir). `lib/` ve `test/` (integration hariç) 0 issue.

Run: `flutter test test/` (integration hariç)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/session_controller.dart \
        test/core/telemetry/session_controller_test.dart
git commit -m "sprint-b3(T7): SessionController installIdAgeMs wiring (no fallback, sentinel-propagated)"
```

---

## Task 8 (C): telemetryLoggerProvider 3-state gate

**Amaç:** `telemetryLoggerProvider`'ı 3-state gate'e genişlet: `kDebugMode || !FirebaseBootstrap.isInitialized` → `DebugLogger`, else → `FirebaseAnalyticsLogger(FirebaseAnalytics.instance)`.

**Files:**
- Modify: `lib/core/telemetry/telemetry_providers.dart`

- [ ] **Step 1: Modify telemetryLoggerProvider factory**

`lib/core/telemetry/telemetry_providers.dart` mevcut:

```dart
final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());
```

Şununla değiştir:

```dart
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:crumbs/core/telemetry/firebase_analytics_logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

// ... mevcut barrel import'lar korunur

/// Default TelemetryLogger — 3-state gate:
/// - [kDebugMode] → [DebugLogger] (debugPrint flow dev'de görünür)
/// - `!FirebaseBootstrap.isInitialized` → [DebugLogger] (Firebase init fail'de
///   silent fallback, telemetry no-op yerine debugPrint devam)
/// - else → [FirebaseAnalyticsLogger] (release + Firebase up path)
///
/// Invariant [I14].
final telemetryLoggerProvider = Provider<TelemetryLogger>((ref) {
  if (kDebugMode || !FirebaseBootstrap.isInitialized) {
    return DebugLogger();
  }
  return FirebaseAnalyticsLogger(FirebaseAnalytics.instance);
});
```

**Not:** Barrel re-export'lar değişmez. Test'lerde `telemetryLoggerProvider.overrideWithValue(_FakeLogger())` pattern'i B2'den devam eder — test context'inde Firebase kullanılmaz, override ile kesilir.

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/core/telemetry/telemetry_providers.dart`
Expected: No issues found (yeni import'lar resolve edildi).

- [ ] **Step 3: Run telemetry tests**

Run: `flutter test test/core/telemetry/`
Expected: PASS (B2 + B3 yeni testler).

- [ ] **Step 4: Commit**

```bash
git add lib/core/telemetry/telemetry_providers.dart
git commit -m "sprint-b3(T8): telemetryLoggerProvider 3-state gate (kDebugMode || !Firebase.init)"
```

---

## Task 9 (C): main.dart — FirebaseBootstrap.initialize ilk adım

**Amaç:** `main()` sırasını güncelle — `WidgetsFlutterBinding.ensureInitialized()` sonrası `FirebaseBootstrap.initialize()` AppBootstrap.initialize'dan ÖNCE çağrılır. Crashlytics error handlers AppBootstrap hatalarını yakalasın.

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Modify main() sequence**

`lib/main.dart` mevcut:

```dart
Future<void> main() async {
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

Şununla değiştir:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize(); // B3 — AppBootstrap ÖNCESİ
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

**Import eklenecek (mevcutlara ek):**
```dart
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
```

- [ ] **Step 2: Verify AppBootstrap.initialize kendi içinde ensureInitialized çağırıyor mu — duplicate risk?**

`lib/app/boot/app_bootstrap.dart` içinde:
```dart
static Future<BootstrapResult> initialize({...}) async {
  WidgetsFlutterBinding.ensureInitialized();  // ← duplicate!
  await SharedPreferences.getInstance();
  ...
}
```

`WidgetsFlutterBinding.ensureInitialized()` idempotent — iki kez çağrılması zararsız. Fakat main.dart'a taşıdık, AppBootstrap'taki kaldırılabilir (YAGNI ama net). **Seçim: main.dart'taki koruyoruz, AppBootstrap'takini de bırakıyoruz** (defensive no-op; AppBootstrap test'ten de çağrılabilir, kendi içinde binding binding guard'ı tutmak mantıklı).

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/main.dart`
Expected: No issues found.

- [ ] **Step 4: Full suite pass**

Run: `flutter test -j 1 test/`
Expected: PASS (integration test hariç — T14'te fix).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "sprint-b3(T9): main.dart — FirebaseBootstrap.initialize before AppBootstrap"
```

---

## Task 10 (S): AppBootstrap — setUserIdentifier fire-and-forget

**Amaç:** `AppBootstrap.initialize` step d (`adoptFromGameState`) sonrası Crashlytics `setUserIdentifier(gs.meta.installId)` fire-and-forget çağrı ekle, `FirebaseBootstrap.isInitialized` guard'lı.

**Files:**
- Modify: `lib/app/boot/app_bootstrap.dart`
- Modify: `test/app/boot/app_bootstrap_test.dart`

- [ ] **Step 1: Write failing test**

Mevcut `test/app/boot/app_bootstrap_test.dart` içinde yeni test ekle (dosyanın sonundaki main() fonksiyonunun sonuna):

```dart
  group('AppBootstrap — Crashlytics user identity', () {
    test('initialize does not throw even when FirebaseBootstrap not init',
        () async {
      // Test env: FirebaseBootstrap.initialize hiç çağrılmadı (test setup'a
      // özgü) → isInitialized=false → setUserIdentifier skip (guarded).
      // Expected: AppBootstrap tamamlanır, exception yok.
      SharedPreferences.setMockInitialValues({});

      await expectLater(
        () async {
          final boot = await AppBootstrap.initialize(
            containerFactory: () => ProviderContainer(overrides: [
              // temp-dir save repo (path_provider hang engeller — B2 pattern)
              saveRepositoryProvider.overrideWithValue(
                _tempDirSaveRepo(),
              ),
            ]),
          );
          addTearDown(boot.container.dispose);
          return boot;
        },
        returnsNormally,
      );
    });
  });
}

// Helper: test-only temp-dir SaveRepository
SaveRepository _tempDirSaveRepo() {
  final dir = Directory.systemTemp.createTempSync('crumbs_test');
  addTearDownForDir(dir);
  return SaveRepository(
    saveDir: () async => dir,
    fileName: 'save.json',
  );
}

void addTearDownForDir(Directory dir) {
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
}
```

**Uyarı:** `_tempDirSaveRepo` helper B2'nin `test/app/boot/app_bootstrap_test.dart`'ında zaten var olabilir — kontrol et, duplicate ekleme. Varsa sadece yeni `group(...)` ekle.

**Import:** `import 'dart:io';` + `import 'package:crumbs/core/save/save_repository.dart';` eksikse ekle.

- [ ] **Step 2: Run — pass (existing behavior)**

Run: `flutter test test/app/boot/app_bootstrap_test.dart`
Expected: PASS — yeni test mevcut behavior'da (setUserIdentifier call yok) geçer, ama bu step test'i yalnız "throw etmez" assertion'ı.

Gerçek implementation test'i T10 Step 3'te impl sonrasında çalıştırılır.

- [ ] **Step 3: Implementation — AppBootstrap.initialize**

`lib/app/boot/app_bootstrap.dart` içinde step d sonrasına ekle:

```dart
// Mevcut step d:
await container
    .read(installIdProvider.notifier)
    .adoptFromGameState(gs.meta.installId);

// B3 YENİ — step d' Crashlytics user identity
if (FirebaseBootstrap.isInitialized) {
  unawaited(
    FirebaseCrashlytics.instance.setUserIdentifier(gs.meta.installId),
  );
}

// Mevcut step e (tutorialNotifierProvider.future) devam eder
final tutorialState =
    await container.read(tutorialNotifierProvider.future);
```

**Import eklenecek:**
```dart
import 'dart:async';
import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
```

`unawaited` `dart:async`'te.

- [ ] **Step 4: Run — pass**

Run: `flutter test test/app/boot/app_bootstrap_test.dart`
Expected: PASS (test env'da `FirebaseBootstrap.isInitialized=false` guard sayesinde setUserIdentifier skip — exception yok).

- [ ] **Step 5: Full suite**

Run: `flutter analyze && flutter test -j 1 test/`
Expected: 0 issue + PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/app/boot/app_bootstrap.dart test/app/boot/app_bootstrap_test.dart
git commit -m "sprint-b3(T10): Crashlytics setUserIdentifier unawaited + isInitialized guard"
```

---

## Task 11 (C): CI workflow — Firebase config decode step

**Amaç:** `.github/workflows/ci.yml` `flutter pub get` öncesi yeni step — Firebase config dosyalarını GitHub secrets'tan base64 decode edip file sistemine yaz. Fork PR güvenlik (`if: env != ''` guard), trace leak prevention (`set +x`).

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Inspect current ci.yml yapısı**

Run: `cat .github/workflows/ci.yml`

Expected: Mevcut workflow adımları listelenir (`flutter pub get`, `flutter analyze`, `flutter test`, `flutter test --coverage` gibi). Decode step bundan öncesine girecek.

- [ ] **Step 2: Modify ci.yml — decode step insert**

`.github/workflows/ci.yml` içinde `- name: Install dependencies` veya `- run: flutter pub get` satırından ÖNCE yeni step ekle:

```yaml
      - name: Decode Firebase config (secrets → files)
        if: ${{ env.FIREBASE_OPTIONS_DART_B64 != '' }}
        env:
          FIREBASE_OPTIONS_DART_B64: ${{ secrets.FIREBASE_OPTIONS_DART_B64 }}
          IOS_GSI_PLIST_B64: ${{ secrets.IOS_GOOGLE_SERVICE_INFO_PLIST_B64 }}
          ANDROID_GSJ_JSON_B64: ${{ secrets.ANDROID_GOOGLE_SERVICES_JSON_B64 }}
        run: |
          set +x  # trace disable — base64 env secret'ın workflow log'una
                  # sızmasını engelle
          echo "$FIREBASE_OPTIONS_DART_B64" | base64 -d > lib/firebase_options.dart
          echo "$IOS_GSI_PLIST_B64" | base64 -d > ios/Runner/GoogleService-Info.plist
          echo "$ANDROID_GSJ_JSON_B64" | base64 -d > android/app/google-services.json
```

**YAML indentation kritik** — mevcut workflow step'lerinin indent'ine uy (2 veya 4 space).

**Note on env-level `if`:** GitHub Actions `${{ env.FOO }}` step-level scope'ta çözer. `env:` bloğu step'te tanımlı olduğu için `if: ${{ env.FIREBASE_OPTIONS_DART_B64 != '' }}` works — secret empty olursa env empty, step skip. Fork PR'larda secrets erişimi yok, step atlanır.

- [ ] **Step 3: Local lint — workflow yaml geçerli mi?**

Run: `yaml validate` veya GitHub Actions'ın ASCII preview'ı (hata olursa manual inspect).

Alternatively: push sonrası GitHub Actions workflow log'unda "Decode Firebase config" step görünecek. Eğer `env` empty ise "Skipped — condition not met" log'lanır.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "sprint-b3(T11): CI decode Firebase configs from secrets (set +x, env guard)"
```

**Post-commit:** GitHub repo → Settings → Secrets ve variables → Actions'a 3 secret eklenmeli (bu task kapsamı dışı — runbook T12'de açıklanır):
- `FIREBASE_OPTIONS_DART_B64`
- `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`
- `ANDROID_GOOGLE_SERVICES_JSON_B64`

Secrets yoksa CI Decode step atlanır → firebase_options.dart.template kalır → FirebaseBootstrap.initialize try/catch yutar → DebugLogger fallback → test'ler geçer.

---

## Task 12 (C): docs/firebase-setup.md — runbook

**Amaç:** Dev onboarding runbook — 6 section (prerequisites, dev onboarding, secret management macOS+Linux, privacy, Crashlytics verification, troubleshooting).

**Files:**
- Create: `docs/firebase-setup.md`

- [ ] **Step 1: Create docs/firebase-setup.md**

Create:

```markdown
# Firebase Setup Runbook

Sprint B3'te eklenen Firebase Analytics + Crashlytics entegrasyonu için dev
onboarding ve CI secret management rehberi.

---

## 1. Prerequisites

- **FlutterFire CLI:**
  ```bash
  dart pub global activate flutterfire_cli
  ```
- **Firebase CLI auth:**
  ```bash
  firebase login
  # veya firebase login:ci (CI token için)
  ```
- **Firebase Console access:** `crumbs-prod` (veya equivalent) project'e
  hsnbilici account'tan editor-level erişim
- **Flutter 3.41.5 FVM pinned** (CLAUDE.md §2)

---

## 2. Dev onboarding (fresh clone)

Yeni developer repo'yu clone ettiğinde:

```bash
cd Crumbs/
flutterfire configure --project=crumbs-prod
# Interactive prompt:
#   - Platform selection: iOS + Android (web/macOS/linux skip)
#   - Firebase project: crumbs-prod
# Generates (hepsi gitignored):
#   lib/firebase_options.dart
#   ios/Runner/GoogleService-Info.plist
#   ios/firebase_app_id_file.json
#   android/app/google-services.json

flutter pub get
flutter run  # Firebase init success → telemetry ready
```

**Doğrulama:** `flutter run` splash'ten ana ekrana geçiyor, `debugPrint`'te
`[FirebaseBootstrap]` init error YOKSA setup başarılı.

**Fail semptomları:**
- `UnimplementedError: lib/firebase_options.dart missing` → flutterfire
  configure hiç çalışmamış
- `firebase_crashlytics` dependency not found → `flutter pub get` eksik
- iOS "GoogleService-Info.plist not found" → flutterfire configure iOS
  seçilmemiş veya Xcode manual file reference eksik

---

## 3. Secret management (CI)

GitHub Actions `.github/workflows/ci.yml` fork-safe decode step kullanır. CI
secrets şu şekilde generate edilir:

### macOS

```bash
base64 -i lib/firebase_options.dart | pbcopy
# clipboard → GitHub Settings → Secrets → FIREBASE_OPTIONS_DART_B64

base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
# → IOS_GOOGLE_SERVICE_INFO_PLIST_B64

base64 -i android/app/google-services.json | pbcopy
# → ANDROID_GOOGLE_SERVICES_JSON_B64
```

### Linux

```bash
base64 -w 0 lib/firebase_options.dart | xclip -selection clipboard
# Or stdout:
base64 -w 0 lib/firebase_options.dart
```

### GitHub secret ekleme

1. Repo → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**
3. Name: `FIREBASE_OPTIONS_DART_B64`, Value: clipboard içeriği yapıştır
4. Tekrarla: `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`,
   `ANDROID_GOOGLE_SERVICES_JSON_B64`

### Fork PR güvenliği

External fork PR'larda `secrets` erişimi yok → decode step
(`if: env.FIREBASE_OPTIONS_DART_B64 != ''`) atlanır → template throw +
`FirebaseBootstrap.initialize` try/catch yutar → `DebugLogger` fallback →
test'ler geçer. Secret fork'a sızmaz.

---

## 4. Privacy

- **`install_id`** — device-local anonymous UUID (v4). PII değil.
  `GameState.meta.installId`'de üretilir, cross-device save restore ile taşınır
  (anonymous identity, kullanıcı hesabı değil).
- **Crashlytics `setUserIdentifier(install_id)`** — anonymous identifier
  attachment, PII attach policy YOK.
- **Analytics event payload'ları** yalnız install_id + session_id + derived
  metrics (duration_ms, age_ms, skipped). Kullanıcı içerik (username, email,
  device name) toplanmaz.
- **Legal privacy policy draft** B4 kapsamında (Sprint C/D öncesi).

---

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

3. **Fiziksel cihazda** çalıştır, butona bas → app crash olur

4. Uygulamayı YENİDEN AÇ (crash report upload bir sonraki launch gerekli)

5. Firebase Console → **Crashlytics** → dashboard'da crash görünür (~5 dk
   gecikme; dashboard ilk 24h "not seen" gösterirse sample Cmd/Ctrl+Shift+R)

6. **Test butonunu `git checkout lib/main.dart` ile sil — BU ADIMI ATLAMA**

7. Doğrula: `git diff HEAD -- lib/main.dart` temiz (no leftover ElevatedButton)

Debug build'de `setCrashlyticsCollectionEnabled(false)` → collection disabled,
bu test release-only çalışır.

**Not:** Physical device önerilir. iOS simülatör / Android emulator
Crashlytics upload yapabilir ama Firebase docs platform-specific uyarıları var;
doğrulama garanti değil. Emülator'de görünmezse fiziksel cihazda yeniden dene.

---

## 6. Troubleshooting

| Sorun | Olası neden | Çözüm |
|---|---|---|
| `UnimplementedError: lib/firebase_options.dart missing` | flutterfire configure eksik veya CI secret decode edilememiş | Dev: `flutterfire configure`. CI: secret ekle + `env.FIREBASE_OPTIONS_DART_B64 != ''` log'da true olsun |
| Crashlytics'te rapor görünmüyor | `setCrashlyticsCollectionEnabled(false)` (debug build) veya ilk 24h propagation | Release build'de test et + 5 dk bekle + sample tekrar yükle |
| Firebase init hang | Network offline / Firebase platform plugin yükleme fail | `try/catch` zaten devreye girer, app devam eder (DebugLogger fallback); network kontrol et |
| iOS build fail "GoogleService-Info.plist not found" | flutterfire configure iOS seçmemiş veya Xcode project'e dosya ref eklememiş | `flutterfire configure --project=... --platforms=ios`; Xcode → Runner target → Build Phases → Copy Bundle Resources'a GoogleService-Info.plist ekle |
| Android build fail "google-services plugin not applied" | `android/app/build.gradle`'da `id "com.google.gms.google-services"` plugin eksik | flutterfire configure bunu otomatik eklemiş olmalı; manual edit gerekirse Firebase docs § "Android setup" |
| `firebase login` CLI auth expire | Firebase CLI token timeout (nadir) | `firebase logout && firebase login` tekrar auth |

---

## Referanslar

- Firebase Flutter docs: https://firebase.flutter.dev/docs/overview
- FlutterFire CLI: https://firebase.flutter.dev/docs/cli
- Firebase Analytics event naming: https://firebase.google.com/docs/analytics/events
- Sprint B3 spec:
  `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md`
```

- [ ] **Step 2: Commit**

```bash
git add docs/firebase-setup.md
git commit -m "sprint-b3(T12): docs/firebase-setup.md runbook (6 sections)"
```

---

## Task 13 (C): CLAUDE.md §12 gotchas + docs/telemetry.md SessionStart update

**Amaç:** CLAUDE.md §12'e 2 yeni gotcha (FirebaseBootstrap.isInitialized guard pattern, kAgeNotLoaded sentinel). `docs/telemetry.md` SessionStart shape'ini `install_id_age_ms` field'iyle güncelle + I15 invariant note.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/telemetry.md`

- [ ] **Step 1: CLAUDE.md §12 — yeni gotcha'lar ekle**

`CLAUDE.md` §12 "Gotcha'lar ve tasarım korumaları" bölümünün SONUNA (son bullet'tan sonra) ekle:

```markdown
- **FirebaseBootstrap isInitialized guard pattern:** `FirebaseBootstrap.initialize` main()'de AppBootstrap'tan ÖNCE çağrılır — 3-phase (fatal initializeApp / best-effort collection flags / sync handler register). Fail path: phase 1 exception'da `_initialized=false` kalır ve app Firebase'siz devam eder. Firebase API'lerine çağrı YAPMADAN ÖNCE `FirebaseBootstrap.isInitialized` guard zorunlu — aksi halde release build'de Firebase init fail'de `FirebaseAnalytics.instance` access exception atar. Örnekler: `telemetryLoggerProvider` gate'i, `setUserIdentifier(...)` call, future Firebase Messaging integration.
- **kAgeNotLoaded (-1) sentinel pattern:** `InstallIdNotifier.installIdAgeMs` getter'ı `_createdAt == null` ise `-1` döner (`kAgeNotLoaded` sabit). Pre-ensureLoaded race state → integration test [I15] bu sentinel'ı production emission'da reddeder. SessionStart payload'a wiring'de `?? 0` fallback YAZMAYIN — bug sinyali olarak `-1` propagate edilir, B2 `<not-loaded>` string sentinel pattern'iyle hizalı. Clock-backward guard: `diff < 0 ? 0 : diff` (negative aggregation dashboard'u kirletir).
```

- [ ] **Step 2: docs/telemetry.md SessionStart shape update**

`docs/telemetry.md` içinde mevcut SessionStart bölümünü bul. B2'de şöyle yazıldı:

```markdown
### session_start
Fired on every cold launch AND every onResume lifecycle event.

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null — `<not-loaded>` sentinel if provider unresolved (invariant I1 — integration test fails on this value in production) |
| session_id | String | UUID v4, unique per session |
```

Güncelle — `install_id_age_ms` row ekle:

```markdown
### session_start
Fired on every cold launch AND every onResume lifecycle event.

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null — `<not-loaded>` sentinel if provider unresolved (invariant I1 — integration test fails on this value in production) |
| session_id | String | UUID v4, unique per session |
| install_id_age_ms | int | Milliseconds since `install_created_at` (SharedPreferences-backed, device-local). Fresh install: ~0. Cohort analytics primary metric (day-1/day-7/day-30 retention). `-1` (kAgeNotLoaded) sentinel = bootstrap race; invariant [I15] reddeder |
```

Aynı dokümanda "Invariants" bölümü altına `[I15]` ekle:

```markdown
### Invariants
- [I1] install_id never null in payload; sentinel `<not-loaded>` reserved for unresolved provider state (integration test rejects this value in production emission)
- [I6] onPause ordering: persist > telemetry (spec §6.3)
- [I15] SessionStart.install_id_age_ms >= 0 in production path; kAgeNotLoaded (-1) sentinel rejected by integration test (bootstrap race state only)
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md docs/telemetry.md
git commit -m "sprint-b3(T13): CLAUDE.md §12 FirebaseBootstrap+kAgeNotLoaded gotchas + telemetry.md SessionStart shape"
```

---

## Task 14 (S) ★: Integration test — installIdAgeMs invariant

**Amaç:** `integration_test/tutorial_telemetry_integration_test.dart` `SessionStart` constructor çağrılarını yeni imzaya update et (installIdAgeMs required). İnvariant [I15] assertion ekle — production path'te kAgeNotLoaded (-1) reddedilir.

**Files:**
- Modify: `integration_test/tutorial_telemetry_integration_test.dart`

- [ ] **Step 1: Identify SessionStart usage sites**

```bash
grep -n "SessionStart\b" integration_test/tutorial_telemetry_integration_test.dart
```

Expected: `SessionStart` constructor çağrısı YOK — integration test sadece `logger.events.whereType<SessionStart>()` pattern'i kullanıyor. Compile fail constructor'dan değil, `SessionStart` oluşturan `SessionController._startNewSession` T7'de güncellendiği için dolaylı.

Ama mevcut `_CaptureLogger` tipik olarak event objesi alır (çağrı tipli değil) — yeni field'ı otomatik taşır. Test compile fail'i yoksa T14 sadece **yeni invariant assertion**'ı ekler.

- [ ] **Step 2: Run full integration test — current state**

Run: `flutter test integration_test/tutorial_telemetry_integration_test.dart`
Expected: Test compile OK (T7 sonrası). Test'ler PASS (B2 coverage).

Eğer compile fail varsa mesaj: `Missing required argument installIdAgeMs`. O zaman SessionStart literal construct site'ı bul ve düzelt.

- [ ] **Step 3: Add installIdAgeMs invariant assertion**

Test dosyasında "cold start emits AppInstall + SessionStart + TutorialStarted" test'inin sonuna, mevcut invariant I1 assertion'ının (install_id sentinel reddi) ALTINA ekle:

```dart
      // Invariant I1: install_id never <not-loaded>
      for (final e in logger.events) {
        final id = e.payload['install_id']! as String;
        expect(id, isNot(InstallIdNotifier.kNotLoadedSentinel));
      }

      // Invariant [I15]: SessionStart.installIdAgeMs >= 0 (kAgeNotLoaded reddedilir)
      for (final e in logger.events.whereType<SessionStart>()) {
        expect(
          e.installIdAgeMs,
          isNot(InstallIdNotifier.kAgeNotLoaded),
          reason: '-1 sentinel production emission\'da görülmemeli',
        );
        expect(e.installIdAgeMs, greaterThanOrEqualTo(0));
      }
```

Aynı pattern "second cold start → no TutorialStarted" test'ine de ekle (bu test'te SessionStart yine emit edilir).

- [ ] **Step 4: Run integration test — pass**

Run: `flutter test integration_test/tutorial_telemetry_integration_test.dart`
Expected: PASS (3 test).

**Not:** Integration test device runner'da Firebase init fail ediyor (flutterfire configure eksik stub). Bu test'ler `ProviderContainer` sim-level — device bağlı değil. `flutter test integration_test/` komutu iOS/Android build tetikleyebilir; Firebase yoksa build fail eder. Bu sorunsa `flutter test test/` full suite'te integration içermediği için CI'da ayrı:

Alternatively skip `flutter test integration_test/...` device build requirement'ı için; CI'da sim-level cover edilir (future infrastructure, B3 scope dışı). Test syntactically valid ve compile eder — bu yeter.

- [ ] **Step 5: Full suite final check**

Run:
```bash
flutter analyze
flutter test -j 1 test/  # integration test hariç
```

Expected: 0 issue; full suite green.

- [ ] **Step 6: Commit**

```bash
git add integration_test/tutorial_telemetry_integration_test.dart
git commit -m "sprint-b3(T14): integration test — installIdAgeMs invariant [I15] assertion"
```

---

## Task 15 (C): B3 backlog cleanup

**Amaç:** `docs/superpowers/backlog/sprint-b3-backlog.md` §1'de "Firebase Analytics wiring", "Crashlytics integration", "install_id_age_ms payload" item'larını **DONE** işaretle ve B3 commit referanslarını ekle.

**Files:**
- Modify: `docs/superpowers/backlog/sprint-b3-backlog.md`

- [ ] **Step 1: Update backlog §1**

`docs/superpowers/backlog/sprint-b3-backlog.md` §1'in başına ekle (section başlığından hemen sonra):

```markdown
> **Sprint B3 (2026-04-18) completion:** §1 item'lar 1, 2, 3 (Firebase Analytics
> wiring, Crashlytics integration, install_id_age_ms payload) landed. Commit'ler
> spec `docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md`
> referans. §1/4-7 + §2+ B4 backlog.
```

İlk 3 item'ın önüne `✅` (done) marker ekle:

```markdown
- ✅ **Firebase Analytics provider implementation** (TelemetryLogger impl) — Sprint B3 T3/T4/T8
- ✅ **Crashlytics integration** (onError handler + recordFatal) — Sprint B3 T3 (phase 3) + T10
- ✅ **`install_id_age_ms` payload property** — install creation timestamp persistence — Sprint B3 T5/T6/T7
- [ ] **Settings → "Tutorial'i tekrar oyna" toggle** ... (B4)
- [ ] **Purchase/Upgrade/ResearchComplete event'leri** ... (B4)
- [ ] **GameState hydration side-effect telemetry** ... (B4)
- [ ] **Step 2 granularity split** ... (B4)
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/backlog/sprint-b3-backlog.md
git commit -m "sprint-b3(T15): backlog cleanup — §1/1-2-3 done, B4 items noted"
```

---

## Final Verification (post-T15)

Plan tamamlandıktan sonra end-to-end smoke + PR hazırlığı:

```bash
# Lint + typecheck
flutter analyze
# Expected: No issues found!

# Full test suite — integration test hariç (device build)
flutter test -j 1 test/
# Expected: ~210-215 tests passing (baseline 197 + B3 yenileri)

# Git log — commit grain
git log --oneline main..HEAD
# Expected: ~15-17 commit (sprint-b3(T1) → sprint-b3(T15))

# Coverage (yeni modüller hedef ≥85%)
flutter test --coverage test/
genhtml coverage/lcov.info -o coverage/html
# Inspect: lib/app/boot/firebase_bootstrap.dart +
#          lib/core/telemetry/firebase_analytics_logger.dart +
#          lib/core/telemetry/install_id_notifier.dart extension coverage ≥85%

# PR hazırlığı
git push -u origin sprint/b3-telemetry-activation
gh pr create --title "Sprint B3 — Production Telemetry Activation" \
  --body "$(cat docs/superpowers/specs/2026-04-18-sprint-b3-telemetry-activation-design.md | head -50)"
```

**DoD checklist (spec §8.3):**
- [ ] `flutter analyze` clean (0 issue)
- [ ] `flutter test -j 1 test/` 100% pass
- [ ] Fork PR CI yeşil (decode step skip olur — template + try/catch fallback path)
- [ ] `docs/firebase-setup.md` complete (6 section)
- [ ] `CLAUDE.md §12` yeni 2 gotcha
- [ ] `docs/telemetry.md` SessionStart shape + I15 invariant update
- [ ] Invariants [I13]-[I17] regression test'te assert edilir
- [ ] Manual Crashlytics verification: release build test crash → dashboard (runbook §5; button silindi doğrulandı)
- [ ] Event name regex invariant (T4 test) 5 event için green
- [ ] B3 backlog `§1/1-2-3` done işaretlendi

---

## Post-plan self-review

**Spec coverage:**
- §1.1 Firebase core bootstrap → T3 ✓
- §1.1 Firebase Analytics wiring → T4 + T8 ✓
- §1.1 Crashlytics integration → T3 (phase 3) + T10 ✓
- §1.1 install_id_age_ms payload → T5 + T6 + T7 ✓
- §1.1 Config management → T2 ✓
- §1.1 CI secret wiring → T11 ✓
- §1.1 Dev onboarding → T12 ✓
- §1.1 Doc updates → T13 ✓
- §2 Architecture (modules new/changed) → T3/T4/T5/T6/T7/T8/T9/T10 dağılımlı ✓
- §3 FirebaseBootstrap 3-phase → T3 ✓
- §3.3 telemetryLoggerProvider 3-state gate → T8 ✓
- §3.4 FirebaseAnalyticsLogger → T4 ✓
- §3.5 Event name regex invariant → T4 ✓
- §4 InstallIdNotifier extension + SessionStart shape → T5 + T6 + T7 ✓
- §5 Crashlytics user identity + runbook → T10 + T12 ✓
- §6 Config + CI → T2 + T11 ✓
- §7 Lifecycle ordering contract → T3 + T9 + T10 ✓
- §8 Invariants [I13]-[I17] → T3 + T4 + T5 + T14 ✓
- §9 Testing strategy → T3/T4/T5/T7/T14 ✓
- §10 Task decomposition → 15 task one-to-one ✓
- §11 DAG → plan başı diagram ✓
- §12 Risks → plan commit notları + risk table ✓
- §13 Rollback → spec'e referans ✓
- §14 Followups → T15 backlog marker ✓

**Placeholder scan:** "TBD", "TODO", "implement later", "fill in details",
"Similar to Task N" — **yok**.

**Type consistency:** `FirebaseBootstrap.isInitialized` (T3), `_prefKeyCreatedAt`
+ `kAgeNotLoaded` (T5), `SessionStart.installIdAgeMs: int` (T6),
`FirebaseAnalyticsLogger(_analytics)` (T4), `telemetryLoggerProvider` gate 3-state
(T8), `setUserIdentifier(gs.meta.installId)` (T10) — tüm task'larda tutarlı.
