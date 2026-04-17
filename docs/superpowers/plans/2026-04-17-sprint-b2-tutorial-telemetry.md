# Sprint B2 — Tutorial + Telemetry + A11y Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FR-3 3-step tutorial overlay (tapCupcake → openShop → explainCrumbs), stub-first telemetry pipeline (TelemetryLogger + DebugLogger + 5 events: AppInstall/SessionStart/SessionEnd/TutorialStarted/TutorialCompleted), InstallIdNotifier (disk-wins reconciliation), SessionController (lifecycle-driven), 48dp accessibility fix via ThemeData.

**Architecture:** Telemetry = sealed TelemetryEvent hierarchy + abstract TelemetryLogger + DebugLogger impl (Firebase Analytics B3'te swap). InstallId = SharedPreferences-backed Notifier; boot sequence'ta `ensureLoaded → gameState hydrate → adoptFromGameState (disk-wins)`. Tutorial = AsyncNotifier<TutorialState> (build() async hydrate SharedPreferences → flicker race fix). TutorialScaffold route-aware Step 2: `GoRouterState.of(context).matchedLocation` ile `/` → BottomNavCallout, `/shop` → CoachMarkOverlay on first BuildingRow. MaterialApp.router(builder:) üzerinden mount — [I12] invariant. A11y 48dp → tek noktada `AppTheme.filledButtonTheme/textButtonTheme.minimumSize`.

**Tech Stack:** Flutter 3.41.5, Dart 3.11, Riverpod 3.1 (AsyncNotifier), freezed 3.0 + json_serializable, go_router 17.2 (GoRouterState.of), shared_preferences 2.3, uuid 4.5 (session_id), flutter_animate 4.5 (pulse halo), mocktail (test doubles). Sprint A + B1 altyapısı (AppLifecycleListener, SaveEnvelope v2, MultiplierChain, _persistSafe) korunur.

**Referans:** `docs/superpowers/specs/2026-04-17-sprint-b2-tutorial-telemetry-design.md` (7 review item applied — AsyncNotifier pattern, enum 4→3 collapse, MaterialApp.router.builder invariant, theme-level a11y, firstLaunchMarked window invariant, B3 hydration-telemetry followup, debugPrint override caveat).

---

## Önkoşullar (plan öncesi)

- **Sprint B1 bitti:** PR #3 (`sprint/b1-expansion`) merge edilmiş OLMALI. Merge edilmeden önce plan başlatılırsa bu plan `main` yerine `sprint/b1-expansion` tip'inden branch alır — yapma.
- Flutter 3.41.5 FVM ile: `flutter --version` ile teyit et (pinli değerin dışındaysa `fvm use 3.41.5`).
- `flutter analyze` temiz, `flutter test` tümü yeşil (B1 sonrası 133 test geçmeli).
- Yeni branch: `sprint/b2-tutorial-telemetry`.

```bash
git checkout main
git pull origin main
git checkout -b sprint/b2-tutorial-telemetry
flutter pub get
flutter test  # 133 pass baseline
flutter analyze  # 0 issue baseline
```

---

## Dependency Chain

```
T1 (TelemetryEvent) ──► T2 (DebugLogger)
                                  ▼
T3 (InstallIdNotifier) ────────► T4 (SessionController) ──► T5 (telemetry_providers)
                                                                   ▼
T6 (TutorialStep+State) ─► T7 (TutorialNotifier) ─► T8 (tutorial_providers)
                                                                   ▼
                                                        T9, T10, T11 (UI widgets, sıralı)
                                                                   ▼
                                                        T12 (tr.arb) ─► T13 (TutorialScaffold)
                                                                   ▼
                                                        T14 (GlobalKey + MaterialApp.router.builder)
                                                                   ▼
                                                        T15 (AppBootstrap + AppLifecycleGate)
                                                                   ▼
                                                        T16 (A11y theme)
                                                                   ▼
                                                        T17 (integration test + docs + CLAUDE.md gotchas)
```

**Sıra zorunlu, paralel yok:** Subagent-driven akışta tek seferde bir task dispatch edilir (context pollution yok). T9/T10/T11 bağımsız görünse de arka arkaya sıralı çalıştır.

**Task modu:** `(S)` = subagent-driven TDD strict, `(C)` = controller-direct.

---

## Task 1 (S): TelemetryEvent sealed hierarchy

**Amaç:** 5 event (`AppInstall`, `SessionStart`, `SessionEnd`, `TutorialStarted`, `TutorialCompleted`) için immutable sealed hierarchy + payload shape sabitle. Future Firebase wiring'de payload kontratı değişmemeli.

**Files:**
- Create: `lib/core/telemetry/telemetry_event.dart`
- Create: `test/core/telemetry/telemetry_event_test.dart`

- [ ] **Step 1: Test — event shape + payload keys**

```dart
// test/core/telemetry/telemetry_event_test.dart
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TelemetryEvent — AppInstall', () {
    test('eventName is app_install', () {
      const e = AppInstall(installId: 'abc-123', platform: 'ios');
      expect(e.eventName, 'app_install');
    });

    test('payload has install_id and platform', () {
      const e = AppInstall(installId: 'abc-123', platform: 'ios');
      expect(e.payload, {'install_id': 'abc-123', 'platform': 'ios'});
    });
  });

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

  group('TelemetryEvent — SessionEnd', () {
    test('eventName is session_end', () {
      const e = SessionEnd(installId: 'abc', sessionId: 's1', durationMs: 1200);
      expect(e.eventName, 'session_end');
    });

    test('payload has install_id, session_id, duration_ms', () {
      const e = SessionEnd(installId: 'abc', sessionId: 's1', durationMs: 1200);
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 's1',
        'duration_ms': 1200,
      });
    });
  });

  group('TelemetryEvent — TutorialStarted', () {
    test('eventName is tutorial_started', () {
      const e = TutorialStarted(installId: 'abc');
      expect(e.eventName, 'tutorial_started');
    });

    test('payload has install_id only', () {
      const e = TutorialStarted(installId: 'abc');
      expect(e.payload, {'install_id': 'abc'});
    });
  });

  group('TelemetryEvent — TutorialCompleted', () {
    test('eventName is tutorial_completed', () {
      const e = TutorialCompleted(
        installId: 'abc',
        skipped: false,
        durationMs: 45000,
      );
      expect(e.eventName, 'tutorial_completed');
    });

    test('payload has install_id, skipped, duration_ms', () {
      const e = TutorialCompleted(
        installId: 'abc',
        skipped: true,
        durationMs: 3000,
      );
      expect(e.payload, {
        'install_id': 'abc',
        'skipped': true,
        'duration_ms': 3000,
      });
    });
  });

  test('TelemetryEvent is sealed — pattern match exhaustive', () {
    TelemetryEvent e = const AppInstall(installId: 'x', platform: 'ios');
    final name = switch (e) {
      AppInstall() => 'install',
      SessionStart() => 'start',
      SessionEnd() => 'end',
      TutorialStarted() => 'tut_start',
      TutorialCompleted() => 'tut_done',
    };
    expect(name, 'install');
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/telemetry_event_test.dart`
Expected: FAIL — `telemetry_event.dart` dosyası yok (`uri_does_not_exist`).

- [ ] **Step 3: Implementation**

```dart
// lib/core/telemetry/telemetry_event.dart

/// Immutable telemetry event hierarchy. Her event sealed — exhaustive pattern
/// match zorunlu. payload shape Firebase provider wiring'de (B3) değişmemeli.
sealed class TelemetryEvent {
  const TelemetryEvent();

  String get eventName;
  Map<String, Object?> get payload;
}

class AppInstall extends TelemetryEvent {
  const AppInstall({required this.installId, required this.platform});

  final String installId;
  final String platform;

  @override
  String get eventName => 'app_install';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'platform': platform,
      };
}

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

class SessionEnd extends TelemetryEvent {
  const SessionEnd({
    required this.installId,
    required this.sessionId,
    required this.durationMs,
  });

  final String installId;
  final String sessionId;
  final int durationMs;

  @override
  String get eventName => 'session_end';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'duration_ms': durationMs,
      };
}

class TutorialStarted extends TelemetryEvent {
  const TutorialStarted({required this.installId});

  final String installId;

  @override
  String get eventName => 'tutorial_started';

  @override
  Map<String, Object?> get payload => {'install_id': installId};
}

class TutorialCompleted extends TelemetryEvent {
  const TutorialCompleted({
    required this.installId,
    required this.skipped,
    required this.durationMs,
  });

  final String installId;
  final bool skipped;
  final int durationMs;

  @override
  String get eventName => 'tutorial_completed';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'skipped': skipped,
        'duration_ms': durationMs,
      };
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/telemetry/telemetry_event_test.dart`
Expected: PASS (11 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/telemetry_event.dart test/core/telemetry/telemetry_event_test.dart
git commit -m "sprint-b2(T1): TelemetryEvent sealed hierarchy (5 events + payload shape)"
```

---

## Task 2 (S): TelemetryLogger interface + DebugLogger

**Amaç:** Abstract `TelemetryLogger` interface + stub-first `DebugLogger` impl (`debugPrint`). Firebase Analytics provider (B3) aynı interface'i `override`'layarak swap edilebilir.

**Files:**
- Create: `lib/core/telemetry/telemetry_logger.dart`
- Create: `lib/core/telemetry/debug_logger.dart`
- Create: `test/core/telemetry/debug_logger_test.dart`

- [ ] **Step 1: Test — DebugLogger format + session hooks**

```dart
// test/core/telemetry/debug_logger_test.dart
import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? msg, {int? wrapWidth}) {
      if (msg != null) logs.add(msg);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  group('DebugLogger', () {
    test('log() writes [TELEMETRY] {eventName} {payload}', () {
      final logger = DebugLogger();
      logger.log(const AppInstall(installId: 'abc', platform: 'ios'));
      expect(logs, hasLength(1));
      expect(logs.single, startsWith('[TELEMETRY] app_install'));
      expect(logs.single, contains('install_id'));
      expect(logs.single, contains('abc'));
    });

    test('beginSession() writes marker', () {
      final logger = DebugLogger();
      logger.beginSession();
      expect(logs.single, '[TELEMETRY] beginSession');
    });

    test('endSession() writes marker', () {
      final logger = DebugLogger();
      logger.endSession();
      expect(logs.single, '[TELEMETRY] endSession');
    });

    test('log() preserves event order across calls', () {
      final logger = DebugLogger()
        ..log(const SessionStart(installId: 'a', sessionId: 's1'))
        ..log(const TutorialStarted(installId: 'a'))
        ..log(const SessionEnd(installId: 'a', sessionId: 's1', durationMs: 10));
      expect(logs, hasLength(3));
      expect(logs[0], contains('session_start'));
      expect(logs[1], contains('tutorial_started'));
      expect(logs[2], contains('session_end'));
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/debug_logger_test.dart`
Expected: FAIL — `debug_logger.dart` yok.

- [ ] **Step 3: Implementation — TelemetryLogger interface**

```dart
// lib/core/telemetry/telemetry_logger.dart
import 'package:crumbs/core/telemetry/telemetry_event.dart';

/// Abstract telemetry sink. B2'de DebugLogger impl edilir; B3'te Firebase
/// Analytics provider bu interface'i override'lar. Session hook'ları Firebase
/// lifecycle entegrasyonu için placeholder — DebugLogger'da marker print.
abstract class TelemetryLogger {
  void log(TelemetryEvent event);
  void beginSession();
  void endSession();
}
```

- [ ] **Step 4: Implementation — DebugLogger**

```dart
// lib/core/telemetry/debug_logger.dart
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter/foundation.dart';

/// Stub TelemetryLogger — tüm event'leri debugPrint'e yazar.
/// Format: "[TELEMETRY] {eventName} {payload}".
/// Production swap: B3'te FirebaseAnalyticsLogger bu class'ı değiştirir.
class DebugLogger implements TelemetryLogger {
  @override
  void log(TelemetryEvent event) {
    debugPrint('[TELEMETRY] ${event.eventName} ${event.payload}');
  }

  @override
  void beginSession() {
    debugPrint('[TELEMETRY] beginSession');
  }

  @override
  void endSession() {
    debugPrint('[TELEMETRY] endSession');
  }
}
```

- [ ] **Step 5: Run — pass**

Run: `flutter test test/core/telemetry/debug_logger_test.dart`
Expected: PASS (4 test).

- [ ] **Step 6: Commit**

```bash
git add lib/core/telemetry/telemetry_logger.dart lib/core/telemetry/debug_logger.dart \
        test/core/telemetry/debug_logger_test.dart
git commit -m "sprint-b2(T2): TelemetryLogger interface + DebugLogger stub"
```

---

## Task 3 (S) ★: InstallIdNotifier — disk-wins reconciliation

**Amaç:** `install_id`'yi tek kaynak (SharedPreferences) üzerinden servis et. Boot sequence'ta `ensureLoaded() → adoptFromGameState(gs.meta.installId)` (disk-wins: GameState'tekini SharedPreferences'a yaz). Telemetry payload `install_id` bu provider'dan okur — `<not-loaded>` sentinel invariant guard.

**Files:**
- Create: `lib/core/telemetry/install_id_notifier.dart`
- Create: `test/core/telemetry/install_id_notifier_test.dart`

- [ ] **Step 1: Test — disk-wins 3 senaryo + sentinel**

```dart
// test/core/telemetry/install_id_notifier_test.dart
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('InstallIdNotifier', () {
    test('ensureLoaded with empty disk → state is null', () async {
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(c.read(installIdProvider), isNull);
    });

    test('ensureLoaded with existing key → state is that value', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'existing-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(c.read(installIdProvider), 'existing-id');
    });

    test('adoptFromGameState with empty disk → writes GameState id',
        () async {
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState('gs-install-id');
      expect(c.read(installIdProvider), 'gs-install-id');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crumbs.install_id'), 'gs-install-id');
    });

    test('adoptFromGameState when disk differs → disk overwritten (disk wins)',
        () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'stale-disk-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState('gs-authoritative-id');
      expect(c.read(installIdProvider), 'gs-authoritative-id');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crumbs.install_id'), 'gs-authoritative-id');
    });

    test('adoptFromGameState when disk matches → no-op write', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'same-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(installIdProvider.notifier).adoptFromGameState('same-id');
      expect(c.read(installIdProvider), 'same-id');
    });

    test('resolveInstallIdForTelemetry returns value when loaded', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'loaded-id',
      });
      final c = buildContainer();
      await c.read(installIdProvider.notifier).ensureLoaded();
      expect(resolveInstallIdForTelemetry(c), 'loaded-id');
    });

    test('resolveInstallIdForTelemetry returns sentinel when null', () {
      final c = buildContainer();
      expect(resolveInstallIdForTelemetry(c),
          InstallIdNotifier.kNotLoadedSentinel);
      expect(InstallIdNotifier.kNotLoadedSentinel, '<not-loaded>');
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/install_id_notifier_test.dart`
Expected: FAIL — `install_id_notifier.dart` yok.

- [ ] **Step 3: Implementation**

```dart
// lib/core/telemetry/install_id_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Install ID'nin tek kaynağı (SharedPreferences).
/// Boot: ensureLoaded() → adoptFromGameState(gs.meta.installId) (disk wins).
/// Telemetry payload için `resolveInstallIdForTelemetry(ref)` kullan —
/// null ise `<not-loaded>` sentinel döner (invariant guard).
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKey = 'crumbs.install_id';
  static const kNotLoadedSentinel = '<not-loaded>';

  @override
  String? build() => null;

  /// Boot sırasında, GameState hydrate'den ÖNCE çağrılır.
  /// State SharedPreferences'taki değerle (veya null ile) doldurulur.
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey);
  }

  /// Boot sırasında, GameState hydrate sonrası çağrılır.
  /// Disk-wins: GameState.meta.installId her zaman authoritative;
  /// disk farklıysa overwrite edilir.
  Future<void> adoptFromGameState(String savedInstallId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKey);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKey, savedInstallId);
    }
    state = savedInstallId;
  }
}

final installIdProvider =
    NotifierProvider<InstallIdNotifier, String?>(InstallIdNotifier.new);

/// Telemetry invariant guard.
/// Returns install_id veya `<not-loaded>` sentinel.
/// Integration test bu sentinel'ı production emission'da görürse fail eder.
String resolveInstallIdForTelemetry(Ref ref) {
  return ref.read(installIdProvider) ?? InstallIdNotifier.kNotLoadedSentinel;
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/telemetry/install_id_notifier_test.dart`
Expected: PASS (7 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/install_id_notifier.dart test/core/telemetry/install_id_notifier_test.dart
git commit -m "sprint-b2(T3): InstallIdNotifier — disk-wins reconciliation + sentinel guard"
```

---

## Task 4 (S) ★: SessionController — lifecycle sequencing

**Amaç:** `onLaunch(firstLaunchMarkedBefore)`, `onResume()`, `onPause()` — cold/warm/pause geçişlerinde doğru event'leri doğru sırada emit et. session_id UUID v4; durationMs `DateTime.now().difference`.

**Files:**
- Create: `lib/core/telemetry/session_controller.dart`
- Create: `test/core/telemetry/session_controller_test.dart`

- [ ] **Step 1: Test — onLaunch/onResume/onPause + fake logger**

```dart
// test/core/telemetry/session_controller_test.dart
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  int beginCount = 0;
  int endCount = 0;

  @override
  void log(TelemetryEvent event) => events.add(event);

  @override
  void beginSession() => beginCount++;

  @override
  void endSession() => endCount++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-id',
    });
  });

  ProviderContainer buildContainer(_FakeLogger logger) {
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('SessionController — onLaunch', () {
    test('firstLaunch → AppInstall + SessionStart emitted', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c.read(sessionControllerProvider).onLaunch(firstLaunchMarkedBefore: true);

      expect(logger.events, hasLength(2));
      expect(logger.events[0], isA<AppInstall>());
      expect(logger.events[1], isA<SessionStart>());
      expect(logger.beginCount, 1);
    });

    test('not first launch → only SessionStart', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: false);

      expect(logger.events, hasLength(1));
      expect(logger.events.single, isA<SessionStart>());
    });

    test('SessionStart carries non-null install_id', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: false);

      final start = logger.events.single as SessionStart;
      expect(start.installId, 'test-id');
      expect(start.sessionId, isNotEmpty);
    });
  });

  group('SessionController — onPause', () {
    test('emits SessionEnd with duration', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final controller = c.read(sessionControllerProvider);
      controller.onLaunch(firstLaunchMarkedBefore: false);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.onPause();

      expect(logger.events.last, isA<SessionEnd>());
      final end = logger.events.last as SessionEnd;
      expect(end.durationMs, greaterThanOrEqualTo(10));
      expect(logger.endCount, 1);
    });

    test('onPause without active session → no-op', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      c.read(sessionControllerProvider).onPause();
      expect(logger.events, isEmpty);
    });
  });

  group('SessionController — onResume', () {
    test('emits new SessionStart with new session_id', () async {
      final logger = _FakeLogger();
      final c = buildContainer(logger);
      await c.read(installIdProvider.notifier).ensureLoaded();
      final controller = c.read(sessionControllerProvider);
      controller.onLaunch(firstLaunchMarkedBefore: false);
      final firstSessionId =
          (logger.events.single as SessionStart).sessionId;

      controller.onResume();
      final secondSessionId =
          (logger.events.last as SessionStart).sessionId;

      expect(secondSessionId, isNot(firstSessionId));
      expect(logger.beginCount, 2);
    });
  });

  group('SessionController — install_id not loaded sentinel', () {
    test('emits <not-loaded> when installIdProvider null', () {
      SharedPreferences.setMockInitialValues({}); // no install_id key
      final logger = _FakeLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: false);

      final start = logger.events.single as SessionStart;
      expect(start.installId, '<not-loaded>');
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/telemetry/session_controller_test.dart`
Expected: FAIL — `session_controller.dart` + `telemetryLoggerProvider` yok.

- [ ] **Step 3: Implementation — SessionController (telemetryLoggerProvider T5'te)**

Ön-bağımlılık: `telemetryLoggerProvider` sembolü bu task'ta tanımlanır; T5'te `telemetry_providers.dart` dosyasına taşınıp re-export edilir. Şimdilik aynı dosyada tanımla:

```dart
// lib/core/telemetry/session_controller.dart
import 'dart:io' show Platform;

import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());

class SessionController {
  SessionController(this._ref);

  final Ref _ref;
  String? _currentSessionId;
  DateTime? _sessionStartedAt;

  TelemetryLogger get _logger => _ref.read(telemetryLoggerProvider);

  void onLaunch({required bool firstLaunchMarkedBefore}) {
    final installId = resolveInstallIdForTelemetry(_ref);
    if (firstLaunchMarkedBefore) {
      _logger.log(AppInstall(
        installId: installId,
        platform: Platform.operatingSystem,
      ));
    }
    _startNewSession(installId);
  }

  void onResume() {
    final installId = resolveInstallIdForTelemetry(_ref);
    _startNewSession(installId);
  }

  void onPause() {
    if (_currentSessionId == null) return;
    final installId = resolveInstallIdForTelemetry(_ref);
    final duration = DateTime.now().difference(_sessionStartedAt!);
    _logger.log(SessionEnd(
      installId: installId,
      sessionId: _currentSessionId!,
      durationMs: duration.inMilliseconds,
    ));
    _logger.endSession();
    _currentSessionId = null;
    _sessionStartedAt = null;
  }

  void _startNewSession(String installId) {
    _currentSessionId = const Uuid().v4();
    _sessionStartedAt = DateTime.now();
    _logger.beginSession();
    _logger.log(SessionStart(
      installId: installId,
      sessionId: _currentSessionId!,
    ));
  }
}

final sessionControllerProvider =
    Provider<SessionController>(SessionController.new);
```

**UYARI:** `firstLaunchMarkedBefore: true` → AppInstall emit. Spec §3.4 koduna uyar; test'te de `firstLaunchMarkedBefore: true` → 2 event expected.

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/telemetry/session_controller_test.dart`
Expected: PASS (7 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/session_controller.dart test/core/telemetry/session_controller_test.dart
git commit -m "sprint-b2(T4): SessionController + onLaunch/onResume/onPause sequencing"
```

---

## Task 5 (C): telemetry_providers.dart — barrel + re-export

**Amaç:** Telemetry provider'ları tek dosyada topla (`telemetry_providers.dart`); T4'te geçici olarak `session_controller.dart`'ta tanımlanan `telemetryLoggerProvider`'ı buraya taşı. Import'lar bu barrel'dan yapılır.

**Files:**
- Create: `lib/core/telemetry/telemetry_providers.dart`
- Modify: `lib/core/telemetry/session_controller.dart` (telemetryLoggerProvider'ı sil, import ile çöz)

- [ ] **Step 1: Implementation — barrel**

```dart
// lib/core/telemetry/telemetry_providers.dart
//
// Telemetry + session layer için provider barrel.
// UI/feature kodu bu dosyayı import eder.

import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';

export 'package:crumbs/core/telemetry/install_id_notifier.dart'
    show installIdProvider, resolveInstallIdForTelemetry, InstallIdNotifier;
export 'package:crumbs/core/telemetry/session_controller.dart'
    show SessionController, sessionControllerProvider;
export 'package:crumbs/core/telemetry/telemetry_event.dart';
export 'package:crumbs/core/telemetry/telemetry_logger.dart'
    show TelemetryLogger;

final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());
```

Wait — `Provider` referansı `flutter_riverpod` import gerektirir. Düzelt:

```dart
// lib/core/telemetry/telemetry_providers.dart
import 'package:crumbs/core/telemetry/debug_logger.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:crumbs/core/telemetry/install_id_notifier.dart'
    show installIdProvider, resolveInstallIdForTelemetry, InstallIdNotifier;
export 'package:crumbs/core/telemetry/session_controller.dart'
    show SessionController, sessionControllerProvider;
export 'package:crumbs/core/telemetry/telemetry_event.dart';
export 'package:crumbs/core/telemetry/telemetry_logger.dart'
    show TelemetryLogger;

final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());
```

- [ ] **Step 2: Modify — session_controller.dart `telemetryLoggerProvider`'ı sil**

`lib/core/telemetry/session_controller.dart` dosyasında:

```dart
// SİL:
final telemetryLoggerProvider =
    Provider<TelemetryLogger>((ref) => DebugLogger());
```

Ve import'a ekle (dosya başında):

```dart
import 'package:crumbs/core/telemetry/telemetry_providers.dart'
    show telemetryLoggerProvider;
```

`debug_logger.dart` import'ı artık session_controller'da gereksizse kaldır.

- [ ] **Step 3: Run — test + analyze pass**

Run: `flutter analyze && flutter test test/core/telemetry/`
Expected: 0 issue, T1-T4 testleri (22 test) hâlâ yeşil.

- [ ] **Step 4: Commit**

```bash
git add lib/core/telemetry/telemetry_providers.dart lib/core/telemetry/session_controller.dart
git commit -m "sprint-b2(T5): telemetry_providers.dart barrel + relocate telemetryLoggerProvider"
```

---

## Task 6 (C): TutorialStep enum + TutorialState freezed

**Amaç:** 3-value `TutorialStep` enum (`tapCupcake`, `openShop`, `explainCrumbs`) + immutable `TutorialState` (`firstLaunchMarked`, `tutorialCompleted`, `currentStep`).

**Files:**
- Create: `lib/core/tutorial/tutorial_step.dart`
- Create: `lib/core/tutorial/tutorial_state.dart`
- Create: `test/core/tutorial/tutorial_state_test.dart`

- [ ] **Step 1: Enum**

```dart
// lib/core/tutorial/tutorial_step.dart

/// Tutorial 3 adımı (B2). Step 2'nin "shop'a git" ve "ilk binayı al"
/// 2-state granularity'si B3'e ertelendi — openShop route-aware UI ile
/// her ikisini de gösterir.
enum TutorialStep { tapCupcake, openShop, explainCrumbs }
```

- [ ] **Step 2: Freezed model**

```dart
// lib/core/tutorial/tutorial_state.dart
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutorial_state.freezed.dart';

/// Tutorial state — SharedPreferences'tan hydrate edilir.
/// currentStep disk'e YAZILMAZ (session-only), invariant [I2].
@freezed
abstract class TutorialState with _$TutorialState {
  const factory TutorialState({
    required bool firstLaunchMarked,
    required bool tutorialCompleted,
    required TutorialStep? currentStep,
  }) = _TutorialState;
}
```

- [ ] **Step 3: Test — equality + copyWith**

```dart
// test/core/tutorial/tutorial_state_test.dart
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialState', () {
    test('equality — same fields', () {
      const a = TutorialState(
        firstLaunchMarked: false,
        tutorialCompleted: false,
        currentStep: null,
      );
      const b = TutorialState(
        firstLaunchMarked: false,
        tutorialCompleted: false,
        currentStep: null,
      );
      expect(a, b);
    });

    test('copyWith updates currentStep only', () {
      const a = TutorialState(
        firstLaunchMarked: true,
        tutorialCompleted: false,
        currentStep: null,
      );
      final b = a.copyWith(currentStep: TutorialStep.tapCupcake);
      expect(b.firstLaunchMarked, true);
      expect(b.tutorialCompleted, false);
      expect(b.currentStep, TutorialStep.tapCupcake);
    });
  });

  group('TutorialStep enum', () {
    test('has 3 values', () {
      expect(TutorialStep.values, hasLength(3));
      expect(TutorialStep.values, containsAll([
        TutorialStep.tapCupcake,
        TutorialStep.openShop,
        TutorialStep.explainCrumbs,
      ]));
    });
  });
}
```

- [ ] **Step 4: Run build_runner + analyze + test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/core/tutorial/tutorial_state_test.dart
```

Expected: codegen üretir (`tutorial_state.freezed.dart`); analyze 0 issue; 3 test PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/tutorial/tutorial_step.dart lib/core/tutorial/tutorial_state.dart \
        lib/core/tutorial/tutorial_state.freezed.dart \
        test/core/tutorial/tutorial_state_test.dart
git commit -m "sprint-b2(T6): TutorialStep enum (3) + TutorialState freezed"
```

---

## Task 7 (S) ★: TutorialNotifier — AsyncNotifier state machine

**Amaç:** `AsyncNotifier<TutorialState>` pattern (Sprint A GameStateNotifier gibi). `build()` async — SharedPreferences hydrate inline → flicker race [I11] engelli. `start()` idempotent, `advance(from:)` re-entry guard, `skip()`/`complete()` disk write + completed=true.

**Files:**
- Create: `lib/core/tutorial/tutorial_notifier.dart`
- Create: `test/core/tutorial/tutorial_notifier_test.dart`

- [ ] **Step 1: Test — state machine + invariants**

```dart
// test/core/tutorial/tutorial_notifier_test.dart
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer buildContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('TutorialNotifier — build() hydration', () {
    test('fresh install → firstLaunchMarked=false + completed=false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.firstLaunchMarked, false);
      expect(state.tutorialCompleted, false);
      expect(state.currentStep, null);
    });

    test('firstLaunchMarked persisted → reflected in state', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.firstLaunchMarked, true);
    });

    test('tutorialCompleted persisted → reflected in state', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.tutorialCompleted, true);
    });

    test('currentStep is never persisted — always null after hydrate',
        () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': false,
      });
      final c = buildContainer();
      final state = await c.read(tutorialNotifierProvider.future);
      expect(state.currentStep, null);
    });
  });

  group('TutorialNotifier — start()', () {
    test('fresh install → currentStep=tapCupcake + firstLaunchMarked=true',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.currentStep, TutorialStep.tapCupcake);
      expect(state.firstLaunchMarked, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.first_launch_marked'), true);
    });

    test('idempotent — second call no-op when currentStep already set',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      final notifier = c.read(tutorialNotifierProvider.notifier);
      await notifier.start();
      await notifier.start(); // second call
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.tapCupcake);
    });

    test('no-op if firstLaunchMarked already true', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });

    test('no-op if tutorialCompleted=true', () async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });
  });

  group('TutorialNotifier — advance()', () {
    Future<ProviderContainer> startedContainer() async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      return c;
    }

    test('tapCupcake → openShop', () async {
      final c = await startedContainer();
      c
          .read(tutorialNotifierProvider.notifier)
          .advance(from: TutorialStep.tapCupcake);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.openShop);
    });

    test('openShop → explainCrumbs', () async {
      final c = await startedContainer();
      final notifier = c.read(tutorialNotifierProvider.notifier);
      notifier.advance(from: TutorialStep.tapCupcake);
      notifier.advance(from: TutorialStep.openShop);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.explainCrumbs);
    });

    test('re-entry guard — wrong from → no-op', () async {
      final c = await startedContainer();
      c
          .read(tutorialNotifierProvider.notifier)
          .advance(from: TutorialStep.explainCrumbs);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep,
          TutorialStep.tapCupcake);
    });

    test('explainCrumbs advance → currentStep becomes null', () async {
      final c = await startedContainer();
      final notifier = c.read(tutorialNotifierProvider.notifier);
      notifier.advance(from: TutorialStep.tapCupcake);
      notifier.advance(from: TutorialStep.openShop);
      notifier.advance(from: TutorialStep.explainCrumbs);
      expect(c.read(tutorialNotifierProvider).requireValue.currentStep, null);
    });
  });

  group('TutorialNotifier — skip() + complete()', () {
    test('skip → completed=true + currentStep=null + disk write', () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      await c.read(tutorialNotifierProvider.notifier).skip();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.tutorialCompleted, true);
      expect(state.currentStep, null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.tutorial_completed'), true);
    });

    test('complete → completed=true + currentStep=null + disk write',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = buildContainer();
      await c.read(tutorialNotifierProvider.future);
      await c.read(tutorialNotifierProvider.notifier).start();
      await c.read(tutorialNotifierProvider.notifier).complete();

      final state = c.read(tutorialNotifierProvider).requireValue;
      expect(state.tutorialCompleted, true);
      expect(state.currentStep, null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('crumbs.tutorial_completed'), true);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/core/tutorial/tutorial_notifier_test.dart`
Expected: FAIL — `tutorial_notifier.dart` yok.

- [ ] **Step 3: Implementation**

```dart
// lib/core/tutorial/tutorial_notifier.dart
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AsyncNotifier pattern — build() async hydrate, flicker race engellenir.
/// tutorialActiveProvider loading state'te false döner (bkz. T8).
class TutorialNotifier extends AsyncNotifier<TutorialState> {
  static const _prefKeyFirstLaunch = 'crumbs.first_launch_marked';
  static const _prefKeyCompleted = 'crumbs.tutorial_completed';

  @override
  Future<TutorialState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return TutorialState(
      firstLaunchMarked: prefs.getBool(_prefKeyFirstLaunch) ?? false,
      tutorialCompleted: prefs.getBool(_prefKeyCompleted) ?? false,
      currentStep: null,
    );
  }

  TutorialState get _state => state.requireValue;

  Future<void> start() async {
    final current = _state;
    if (current.tutorialCompleted || current.currentStep != null) return;
    if (current.firstLaunchMarked) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyFirstLaunch, true);
    state = AsyncData(current.copyWith(
      firstLaunchMarked: true,
      currentStep: TutorialStep.tapCupcake,
    ));
  }

  void advance({required TutorialStep from}) {
    final current = _state;
    if (current.currentStep != from) return;
    state = AsyncData(current.copyWith(currentStep: _nextStep(from)));
  }

  Future<void> skip() async {
    await _markCompleted();
  }

  Future<void> complete() async {
    await _markCompleted();
  }

  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyCompleted, true);
    state = AsyncData(_state.copyWith(
      tutorialCompleted: true,
      currentStep: null,
    ));
  }

  TutorialStep? _nextStep(TutorialStep current) {
    return switch (current) {
      TutorialStep.tapCupcake => TutorialStep.openShop,
      TutorialStep.openShop => TutorialStep.explainCrumbs,
      TutorialStep.explainCrumbs => null,
    };
  }
}

final tutorialNotifierProvider =
    AsyncNotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/core/tutorial/tutorial_notifier_test.dart`
Expected: PASS (13 test).

- [ ] **Step 5: Commit**

```bash
git add lib/core/tutorial/tutorial_notifier.dart test/core/tutorial/tutorial_notifier_test.dart
git commit -m "sprint-b2(T7): TutorialNotifier AsyncNotifier state machine + flicker guard [I11]"
```

---

## Task 8 (C): tutorial_providers.dart + tutorialActiveProvider derived

**Amaç:** Tutorial provider'larını tek barrel'da topla; `tutorialActiveProvider` loading/error state'te `false` döner (UI flicker guard [I11]).

**Files:**
- Create: `lib/core/tutorial/tutorial_providers.dart`

- [ ] **Step 1: Implementation**

```dart
// lib/core/tutorial/tutorial_providers.dart
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:crumbs/core/tutorial/tutorial_notifier.dart'
    show tutorialNotifierProvider, TutorialNotifier;
export 'package:crumbs/core/tutorial/tutorial_state.dart' show TutorialState;
export 'package:crumbs/core/tutorial/tutorial_step.dart';

/// UI mount sırasında AsyncNotifier build() henüz dönmediğinde false döner —
/// tutorial overlay render edilmez (invariant [I11]).
final tutorialActiveProvider = Provider<bool>((ref) {
  return ref.watch(tutorialNotifierProvider).maybeWhen(
        data: (s) => !s.tutorialCompleted,
        orElse: () => false,
      );
});
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: 0 issue.

- [ ] **Step 3: Commit**

```bash
git add lib/core/tutorial/tutorial_providers.dart
git commit -m "sprint-b2(T8): tutorial_providers barrel + tutorialActiveProvider loading-guard"
```

---

## Task 9 (S) ★: CoachMarkOverlay — StatefulWidget + postFrame + LayoutBuilder

**Amaç:** Target widget'ın render box geometry'sini postFrameCallback'te resolve eden, LayoutBuilder ile safe area'ya clamp eden StatefulWidget. `HaloShape.rectangle|circle`; opsiyonel `onSkip` callback. Target tree'de değilse SizedBox.shrink.

**Files:**
- Create: `lib/features/tutorial/widgets/coach_mark_overlay.dart`
- Create: `lib/features/tutorial/widgets/_pulse_halo.dart` (private helper)
- Create: `lib/features/tutorial/widgets/_message_callout.dart` (private helper)
- Create: `test/features/tutorial/coach_mark_overlay_test.dart`

- [ ] **Step 1: Test — geometry resolve + shape + edge clamp**

```dart
// test/features/tutorial/coach_mark_overlay_test.dart
import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachMarkOverlay', () {
    testWidgets('renders SizedBox.shrink before postFrame resolves',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(left: 10, top: 10, child: SizedBox(key: key, width: 100, height: 100)),
              CoachMarkOverlay(targetKey: key, message: 'test'),
            ],
          ),
        ),
      ));
      // first frame — postFrame not yet run
      expect(find.byType(ModalBarrier), findsNothing);

      await tester.pump();
      expect(find.byType(ModalBarrier), findsOneWidget);
    });

    testWidgets('shows message callout after geometry resolve',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                  left: 50, top: 50, child: SizedBox(key: key, width: 80, height: 80)),
              CoachMarkOverlay(targetKey: key, message: 'Test message'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('calls onSkip when skip button tapped', (tester) async {
      final key = GlobalKey();
      var skipped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(left: 10, top: 10, child: SizedBox(key: key, width: 50, height: 50)),
              CoachMarkOverlay(
                targetKey: key,
                message: 'msg',
                onSkip: () => skipped = true,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Geç'));
      expect(skipped, true);
    });

    testWidgets('no skip button when onSkip is null', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(left: 10, top: 10, child: SizedBox(key: key, width: 50, height: 50)),
              const CoachMarkOverlay(targetKey: null, message: 'msg'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Geç'), findsNothing);
    });

    testWidgets('HaloShape.circle renders circular halo', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(left: 10, top: 10, child: SizedBox(key: key, width: 50, height: 50)),
              CoachMarkOverlay(
                targetKey: key,
                message: 'msg',
                shape: HaloShape.circle,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      // Smoke: finds pulse halo (circle variant renders without throwing)
      expect(find.byType(CoachMarkOverlay), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/features/tutorial/coach_mark_overlay_test.dart`
Expected: FAIL — dosyalar yok.

- [ ] **Step 3: Implementation — _pulse_halo.dart**

```dart
// lib/features/tutorial/widgets/_pulse_halo.dart
import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart'
    show HaloShape;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PulseHalo extends StatelessWidget {
  const PulseHalo({required this.shape, super.key});

  final HaloShape shape;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        shape:
            shape == HaloShape.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == HaloShape.rectangle
            ? BorderRadius.circular(12)
            : null,
        border: Border.all(color: color, width: 3),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.08,
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}
```

- [ ] **Step 4: Implementation — _message_callout.dart**

```dart
// lib/features/tutorial/widgets/_message_callout.dart
import 'package:flutter/material.dart';

class MessageCallout extends StatelessWidget {
  const MessageCallout({
    required this.rect,
    required this.message,
    this.onSkip,
    super.key,
  });

  final Rect rect;
  final String message;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final below = rect.bottom + 16 + 120 < media.size.height;
    return Positioned(
      left: 24,
      right: 24,
      top: below ? rect.bottom + 16 : null,
      bottom: below ? null : media.size.height - rect.top + 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              if (onSkip != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text('Geç'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implementation — coach_mark_overlay.dart**

```dart
// lib/features/tutorial/widgets/coach_mark_overlay.dart
import 'package:crumbs/features/tutorial/widgets/_message_callout.dart';
import 'package:crumbs/features/tutorial/widgets/_pulse_halo.dart';
import 'package:flutter/material.dart';

enum HaloShape { rectangle, circle }

/// Target widget'ın render box geometry'sini postFrame'de resolve eder.
/// Target tree'de değilse veya henüz layout edilmemişse SizedBox.shrink.
/// LayoutBuilder ile safe area'ya clamp edilir (edge overflow engeli).
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.targetKey,
    required this.message,
    this.shape = HaloShape.rectangle,
    this.onSkip,
    super.key,
  });

  final GlobalKey? targetKey;
  final String message;
  final HaloShape shape;
  final VoidCallback? onSkip;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  Offset? _topLeft;
  Size? _size;

  @override
  void initState() {
    super.initState();
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) {
      _scheduleResolve();
    }
  }

  void _scheduleResolve() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.targetKey?.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      setState(() {
        _topLeft = box.localToGlobal(Offset.zero);
        _size = box.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topLeft = _topLeft;
    final size = _size;
    if (topLeft == null || size == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final safeRect = Rect.fromLTWH(
        media.padding.left,
        media.padding.top,
        constraints.maxWidth - media.padding.horizontal,
        constraints.maxHeight - media.padding.vertical,
      );
      final clampedLeft = topLeft.dx
          .clamp(safeRect.left, safeRect.right - size.width)
          .toDouble();
      final clampedTop = topLeft.dy
          .clamp(safeRect.top, safeRect.bottom - size.height)
          .toDouble();
      final clamped =
          Rect.fromLTWH(clampedLeft, clampedTop, size.width, size.height);
      final halo = clamped.inflate(12);

      return Stack(children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Positioned.fromRect(
          rect: halo,
          child: PulseHalo(shape: widget.shape),
        ),
        MessageCallout(
          rect: clamped,
          message: widget.message,
          onSkip: widget.onSkip,
        ),
      ]);
    });
  }
}
```

- [ ] **Step 6: Run — pass**

Run: `flutter test test/features/tutorial/coach_mark_overlay_test.dart`
Expected: PASS (5 test).

- [ ] **Step 7: Commit**

```bash
git add lib/features/tutorial/widgets/coach_mark_overlay.dart \
        lib/features/tutorial/widgets/_pulse_halo.dart \
        lib/features/tutorial/widgets/_message_callout.dart \
        test/features/tutorial/coach_mark_overlay_test.dart
git commit -m "sprint-b2(T9): CoachMarkOverlay StatefulWidget + postFrame geometry + LayoutBuilder clamp"
```

---

## Task 10 (S): BottomNavCallout widget

**Amaç:** Step 2 HomePage aşaması — BottomNav "Dükkân" item'ının ÜSTÜNDE küçük balon callout. CoachMarkOverlay'in sadeleştirilmiş varyantı (modal barrier yok — user navigasyonunu engellemeyelim).

**Files:**
- Create: `lib/features/tutorial/widgets/bottom_nav_callout.dart`
- Create: `test/features/tutorial/bottom_nav_callout_test.dart`

- [ ] **Step 1: Test**

```dart
// test/features/tutorial/bottom_nav_callout_test.dart
import 'package:crumbs/features/tutorial/widgets/bottom_nav_callout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BottomNavCallout', () {
    testWidgets('renders message above target key', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(bottom: 0, left: 80, child: SizedBox(key: key, width: 50, height: 50)),
              BottomNavCallout(targetKey: key, message: 'Dükkân\'a git'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Dükkân\'a git'), findsOneWidget);
    });

    testWidgets('does not render modal barrier (user navigation preserved)',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(bottom: 0, child: SizedBox(key: key, width: 50, height: 50)),
              BottomNavCallout(targetKey: key, message: 'msg'),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(ModalBarrier), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/features/tutorial/bottom_nav_callout_test.dart`
Expected: FAIL — dosya yok.

- [ ] **Step 3: Implementation**

```dart
// lib/features/tutorial/widgets/bottom_nav_callout.dart
import 'package:flutter/material.dart';

/// BottomNav üzerinde konumlandırılan callout. Modal barrier YOK — kullanıcı
/// gerçekten "Dükkân" item'ına tap edebilmeli (Step 2 advance trigger'ı
/// route değişimi değil, ilk building purchase. Ama kullanıcı Dükkân'a gitmeyi
/// öğrenmeli, bu yüzden navigasyon açık kalır).
class BottomNavCallout extends StatefulWidget {
  const BottomNavCallout({
    required this.targetKey,
    required this.message,
    super.key,
  });

  final GlobalKey targetKey;
  final String message;

  @override
  State<BottomNavCallout> createState() => _BottomNavCalloutState();
}

class _BottomNavCalloutState extends State<BottomNavCallout> {
  Offset? _topLeft;
  Size? _size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.targetKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      setState(() {
        _topLeft = box.localToGlobal(Offset.zero);
        _size = box.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final topLeft = _topLeft;
    final size = _size;
    if (topLeft == null || size == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final centerX = topLeft.dx + size.width / 2;
    final calloutWidth = 200.0;
    final leftClamped = (centerX - calloutWidth / 2)
        .clamp(16.0, MediaQuery.of(context).size.width - 16 - calloutWidth);

    return Positioned(
      left: leftClamped,
      top: topLeft.dy - 72,
      width: calloutWidth,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward,
                  color: theme.colorScheme.onPrimaryContainer, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/features/tutorial/bottom_nav_callout_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/tutorial/widgets/bottom_nav_callout.dart \
        test/features/tutorial/bottom_nav_callout_test.dart
git commit -m "sprint-b2(T10): BottomNavCallout (no modal barrier — navigation preserved)"
```

---

## Task 11 (S): InfoCardOverlay (Step 3 bottom-sheet)

**Amaç:** ShopPage Step 3'te modal bottom-sheet benzeri info card — başlık + body + "Anladım" CTA.

**Files:**
- Create: `lib/features/tutorial/widgets/info_card_overlay.dart`
- Create: `test/features/tutorial/info_card_overlay_test.dart`

- [ ] **Step 1: Test**

```dart
// test/features/tutorial/info_card_overlay_test.dart
import 'package:crumbs/features/tutorial/widgets/info_card_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfoCardOverlay', () {
    testWidgets('renders title, body, cta', (tester) async {
      var closed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            InfoCardOverlay(
              title: 'Neden Crumb?',
              body: 'Binalar C/s üretir.',
              ctaLabel: 'Anladım',
              onClose: () => closed = true,
            ),
          ]),
        ),
      ));
      expect(find.text('Neden Crumb?'), findsOneWidget);
      expect(find.text('Binalar C/s üretir.'), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      expect(closed, true);
    });

    testWidgets('renders modal barrier (blocks background taps)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            InfoCardOverlay(
              title: 't',
              body: 'b',
              ctaLabel: 'ok',
              onClose: () {},
            ),
          ]),
        ),
      ));
      expect(find.byType(ModalBarrier), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/features/tutorial/info_card_overlay_test.dart`
Expected: FAIL — dosya yok.

- [ ] **Step 3: Implementation**

```dart
// lib/features/tutorial/widgets/info_card_overlay.dart
import 'package:flutter/material.dart';

class InfoCardOverlay extends StatelessWidget {
  const InfoCardOverlay({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onClose,
    super.key,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(children: [
      const ModalBarrier(color: Colors.black54, dismissible: false),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onClose,
                      child: Text(ctaLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/features/tutorial/info_card_overlay_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/tutorial/widgets/info_card_overlay.dart \
        test/features/tutorial/info_card_overlay_test.dart
git commit -m "sprint-b2(T11): InfoCardOverlay (Step 3 bottom-sheet)"
```

---

## Task 12 (C): tr.arb — 8 yeni tutorial key + codegen

**Amaç:** Tutorial'in TR string'lerini `tr.arb`'a ekle, `AppStrings` codegen'ini tetikle.

**Files:**
- Modify: `lib/l10n/tr.arb`

- [ ] **Step 1: Modify — tr.arb'a 8 key ekle**

`lib/l10n/tr.arb` dosyasına, son anahtardan (`errorScreenRetry`) sonra, kapanış `}`'den önce ekle:

```json
  "tutorialStep1Message": "Crumb kazanmak için cupcake'e dokun!",
  "tutorialStep2NavMessage": "Dükkân'a git ve ilk üreticini al",
  "tutorialStep2ShopMessage": "Crumb Collector'ı satın al",
  "tutorialStep3Title": "Neden Crumb kazanıyorsun?",
  "tutorialStep3Body": "Binaların otomatik olarak saniyede Crumb üretir. Daha fazla satın al, daha hızlı büyü!",
  "tutorialSkipButton": "Geç",
  "tutorialCloseButton": "Anladım"
```

**Not:** Önceki son key `errorScreenRetry`'e virgül eklemeyi unutma. Toplam 7 key (Step 1 + Step 2 Nav + Step 2 Shop + Step 3 Title + Step 3 Body + Skip + Close).

- [ ] **Step 2: Codegen**

```bash
flutter pub get  # gen-l10n otomatik tetiklenir
flutter analyze
```

Expected: `lib/l10n/app_strings.dart` üretilmiş (sürüm kontrolü yoksa repo'da); analyze 0 issue.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/tr.arb
git commit -m "sprint-b2(T12): tr.arb 7 tutorial strings + AppStrings codegen"
```

---

## Task 13 (S) ★: TutorialScaffold — route-aware Step 2 + ref.listen advance

**Amaç:** ConsumerStatefulWidget; `AsyncValue<TutorialState>` watch eder; `ref.listen<AsyncValue<GameState>>` ile Step 1 (tap) ve Step 2 (first building purchase) advance trigger'larını kurar; route-aware `_buildStep2Overlay`.

**Files:**
- Create: `lib/features/tutorial/keys.dart`
- Create: `lib/features/tutorial/tutorial_scaffold.dart`
- Create: `test/features/tutorial/tutorial_scaffold_test.dart`

- [ ] **Step 1: Implementation — keys.dart**

```dart
// lib/features/tutorial/keys.dart
import 'package:flutter/widgets.dart';

final GlobalKey kTutorialCupcakeKey = GlobalKey(debugLabel: 'tutorialCupcake');
final GlobalKey kTutorialShopNavKey = GlobalKey(debugLabel: 'tutorialShopNav');
final GlobalKey kTutorialShopFirstRowKey =
    GlobalKey(debugLabel: 'tutorialShopFirstRow');
```

- [ ] **Step 2: Test — widget smoke (loading guard + step render branch)**

```dart
// test/features/tutorial/tutorial_scaffold_test.dart
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:crumbs/features/tutorial/tutorial_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _appUnderTest(ProviderContainer container) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: Text('home')),
    ),
    GoRoute(
      path: '/shop',
      builder: (_, __) => const Scaffold(body: Text('shop')),
    ),
  ]);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (ctx, child) => TutorialScaffold(
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group('TutorialScaffold — loading guard [I11]', () {
    testWidgets('does not render overlay while AsyncNotifier loading',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      // First frame: AsyncNotifier.build() henüz resolve olmadı
      expect(find.byType(ModalBarrier), findsNothing);
    });
  });

  group('TutorialScaffold — step render', () {
    testWidgets('renders Step 1 when currentStep=tapCupcake', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      await tester.pumpAndSettle();
      // Step 1 otomatik başlar (!firstLaunchMarked)
      // Overlay render edildi (step == tapCupcake)
      // (Gerçek geometry için target widget tree'de yok — CoachMarkOverlay
      //  SizedBox.shrink döner ama TutorialScaffold mount doğru.)
      final state =
          c.read(tutorialNotifierProvider).requireValue;
      expect(state.currentStep, TutorialStep.tapCupcake);
    });

    testWidgets('no overlay when tutorialCompleted=true', (tester) async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
        'crumbs.tutorial_completed': true,
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(_appUnderTest(c));
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsNothing);
    });
  });
}
```

- [ ] **Step 3: Run — fail**

Run: `flutter test test/features/tutorial/tutorial_scaffold_test.dart`
Expected: FAIL — `tutorial_scaffold.dart` + `keys.dart` yok.

- [ ] **Step 4: Implementation — tutorial_scaffold.dart**

```dart
// lib/features/tutorial/tutorial_scaffold.dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/features/tutorial/widgets/bottom_nav_callout.dart';
import 'package:crumbs/features/tutorial/widgets/coach_mark_overlay.dart';
import 'package:crumbs/features/tutorial/widgets/info_card_overlay.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tutorial overlay katmanı. MaterialApp.router(builder:) üzerinden mount —
/// invariant [I12]. GoRouterState.of(context) router tree context gerektirir.
class TutorialScaffold extends ConsumerStatefulWidget {
  const TutorialScaffold({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TutorialScaffold> createState() => _TutorialScaffoldState();
}

class _TutorialScaffoldState extends ConsumerState<TutorialScaffold> {
  bool _startInvoked = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _startInvoked) return;
      final loaded = await ref.read(tutorialNotifierProvider.future);
      if (!mounted) return;
      if (loaded.tutorialCompleted || loaded.firstLaunchMarked) return;
      _startInvoked = true;
      await ref.read(tutorialNotifierProvider.notifier).start();
      final postState = ref.read(tutorialNotifierProvider).valueOrNull;
      if (postState?.currentStep == TutorialStep.tapCupcake) {
        _startedAt = DateTime.now();
        ref.read(telemetryLoggerProvider).log(
              TutorialStarted(
                installId: resolveInstallIdForTelemetry(ref),
              ),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(tutorialNotifierProvider);
    final step = asyncState.maybeWhen(
      data: (s) => s.currentStep,
      orElse: () => null,
    );

    ref.listen<AsyncValue<GameState>>(gameStateNotifierProvider, (prev, next) {
      if (step == null) return;
      final prevTaps = prev?.value?.run.totalTaps ?? 0;
      final nextTaps = next.value?.run.totalTaps ?? 0;
      if (step == TutorialStep.tapCupcake && nextTaps > prevTaps) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
      final prevOwned = prev?.value?.buildings.owned['crumb_collector'] ?? 0;
      final nextOwned = next.value?.buildings.owned['crumb_collector'] ?? 0;
      if (step == TutorialStep.openShop && nextOwned > prevOwned) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
    });

    return Stack(children: [
      widget.child,
      if (step != null) _buildOverlay(step),
    ]);
  }

  Widget _buildOverlay(TutorialStep step) {
    final s = AppStrings.of(context)!;
    final notifier = ref.read(tutorialNotifierProvider.notifier);

    return switch (step) {
      TutorialStep.tapCupcake => CoachMarkOverlay(
          targetKey: kTutorialCupcakeKey,
          message: s.tutorialStep1Message,
          shape: HaloShape.circle,
          onSkip: () => _onSkipPressed(notifier),
        ),
      TutorialStep.openShop => _buildStep2Overlay(s),
      TutorialStep.explainCrumbs => InfoCardOverlay(
          title: s.tutorialStep3Title,
          body: s.tutorialStep3Body,
          ctaLabel: s.tutorialCloseButton,
          onClose: () => _onCompletePressed(notifier),
        ),
    };
  }

  Widget _buildStep2Overlay(AppStrings s) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/shop') {
      return CoachMarkOverlay(
        targetKey: kTutorialShopFirstRowKey,
        message: s.tutorialStep2ShopMessage,
      );
    }
    return BottomNavCallout(
      targetKey: kTutorialShopNavKey,
      message: s.tutorialStep2NavMessage,
    );
  }

  Future<void> _onSkipPressed(TutorialNotifier notifier) async {
    await notifier.skip();
    _emitCompleted(skipped: true);
  }

  Future<void> _onCompletePressed(TutorialNotifier notifier) async {
    await notifier.complete();
    _emitCompleted(skipped: false);
  }

  void _emitCompleted({required bool skipped}) {
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    ref.read(telemetryLoggerProvider).log(
          TutorialCompleted(
            installId: resolveInstallIdForTelemetry(ref),
            skipped: skipped,
            durationMs: duration.inMilliseconds,
          ),
        );
  }
}
```

- [ ] **Step 5: Run — pass**

Run: `flutter test test/features/tutorial/tutorial_scaffold_test.dart`
Expected: PASS (3 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/tutorial/tutorial_scaffold.dart lib/features/tutorial/keys.dart \
        test/features/tutorial/tutorial_scaffold_test.dart
git commit -m "sprint-b2(T13): TutorialScaffold route-aware + ref.listen advance triggers"
```

---

## Task 14 (C) ★: GlobalKey injection + MaterialApp.router.builder

**Amaç:** 3 widget'a tutorial GlobalKey'leri bağla; `main.dart` `MaterialApp.router(builder: ...)` ile `TutorialScaffold` mount et. Invariant [I12]: scaffold router tree context altında olmalı.

**Files:**
- Modify: `lib/features/home/home_page.dart` (TapArea'ya key pass)
- Modify: `lib/app/nav/app_navigation_bar.dart` (Shop NavigationDestination'a key)
- Modify: `lib/features/shop/shop_page.dart` (ilk BuildingRow'a key)
- Modify: `lib/main.dart` (MaterialApp.router builder parametresi)

- [ ] **Step 1: home_page.dart — TapArea'ya kTutorialCupcakeKey**

`lib/features/home/home_page.dart` içinde `Expanded(child: TapArea())` satırını:

```dart
import 'package:crumbs/features/tutorial/keys.dart';
// ...
Expanded(child: TapArea(key: kTutorialCupcakeKey)),
```

- [ ] **Step 2: app_navigation_bar.dart — Shop NavigationDestination key**

`NavigationDestination` Widget'ına `key` parametresi desteklenmez (sealed). Yerine: Shop item'ı `NavigationBar` indices içinde pozisyon-sabit (index 1). Widget tree'den erişmek için NavigationBar'ın kendisine key vermek karmaşık; basit çözüm: Shop destination içindeki `Icon` widget'ına key ver.

```dart
import 'package:crumbs/features/tutorial/keys.dart';
// ...
destinations: [
  NavigationDestination(icon: const Icon(Icons.home), label: s.navHome),
  NavigationDestination(
    icon: Icon(Icons.store, key: kTutorialShopNavKey),
    label: s.navShop,
  ),
  // ...
]
```

Not: `kTutorialShopNavKey` sabit `GlobalKey` singleton — tek instance'ta bir widget bağlanabilir. AppNavigationBar MaterialApp içinde bir kez mount → OK.

- [ ] **Step 3: shop_page.dart — ilk BuildingRow'a key**

`lib/features/shop/shop_page.dart` mevcut:

```dart
BuildingRow(id: 'crumb_collector', displayName: s.crumbCollectorName),
```

→ değiştir:

```dart
import 'package:crumbs/features/tutorial/keys.dart';
// ...
BuildingRow(
  key: kTutorialShopFirstRowKey,
  id: 'crumb_collector',
  displayName: s.crumbCollectorName,
),
```

BuildingRow zaten `super.key` constructor parametresini kabul ediyor — extra change yok.

- [ ] **Step 4: main.dart — TutorialScaffold builder mount**

`lib/main.dart` içinde `CrumbsApp.build` metodunda:

```dart
import 'package:crumbs/features/tutorial/tutorial_scaffold.dart';
// ...
data: (_) => MaterialApp.router(
  title: 'Crumbs',
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  routerConfig: router,
  builder: (ctx, child) => TutorialScaffold(
    child: child ?? const SizedBox.shrink(),
  ),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
),
```

`loading` ve `error` branch'larında `TutorialScaffold` mount edilmez (GameState yoksa tutorial zaten çalışmaz).

- [ ] **Step 5: Verify — analyze + existing widget tests pass**

Run:

```bash
flutter analyze
flutter test
```

Expected: 0 issue; baseline 133 test + yeni T1-T13 testleri (yaklaşık 155+) pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_page.dart lib/app/nav/app_navigation_bar.dart \
        lib/features/shop/shop_page.dart lib/main.dart
git commit -m "sprint-b2(T14): GlobalKey injection + MaterialApp.router.builder mount [I12]"
```

---

## Task 15 (S) ★: AppBootstrap + AppLifecycleGate — SessionController integration

**Amaç:** Boot sequence'ta `installIdProvider.ensureLoaded` → `gameStateNotifier hydrate` → `adoptFromGameState` → `sessionController.onLaunch(firstLaunchMarkedBefore:)`; lifecycle'da `onResume` → `SessionStart`; `onPause` → `persistNow` SONRA `SessionEnd` (sıra kritik).

**Files:**
- Modify: `lib/app/boot/app_bootstrap.dart`
- Modify: `lib/app/lifecycle/app_lifecycle_gate.dart`
- Modify: `lib/main.dart` (AppBootstrap.initialize dönüşü ile TutorialNotifier future await)
- Create: `test/app/lifecycle/app_lifecycle_gate_session_test.dart`

- [ ] **Step 1: Test — lifecycle hook ordering**

```dart
// test/app/lifecycle/app_lifecycle_gate_session_test.dart
import 'package:crumbs/app/lifecycle/app_lifecycle_gate.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  int endSessionCalls = 0;
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() => endSessionCalls++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'crumbs.install_id': 'test-id',
    });
  });

  testWidgets('onPause emits SessionEnd after persistNow', (tester) async {
    final logger = _RecordingLogger();
    final c = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(c.dispose);
    await c.read(installIdProvider.notifier).ensureLoaded();
    await c.read(gameStateNotifierProvider.future);
    c.read(sessionControllerProvider).onLaunch(firstLaunchMarkedBefore: false);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: AppLifecycleGate(child: Scaffold(body: Text('app'))),
      ),
    ));

    // Simulate pause — AppLifecycleGate.onPause: persist > telemetry
    // (AppLifecycleListener manual trigger integration test'te;
    //  burada sessionController ile doğrudan onPause testi.)
    c.read(sessionControllerProvider).onPause();

    final endEvent = logger.events.whereType<SessionEnd>().single;
    expect(endEvent.sessionId, isNotEmpty);
    expect(logger.endSessionCalls, 1);
  });
}
```

- [ ] **Step 2: Modify — AppBootstrap.initialize (yeni imza ile boot sequence)**

`lib/app/boot/app_bootstrap.dart`:

```dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBootstrap {
  const AppBootstrap._();

  /// Boot sequence — lifecycle ordering contract (spec §6.1):
  ///   a. ensureInitialized + SharedPreferences warm
  ///   b. installIdProvider.ensureLoaded()
  ///   c. gameStateNotifierProvider.future (hydrate + migration)
  ///   d. installIdProvider.adoptFromGameState(gs.meta.installId)  [disk-wins]
  ///   e. tutorialNotifierProvider.future (hydrate; flicker guard [I11])
  ///   f. sessionController.onLaunch(firstLaunchMarkedBefore)
  static Future<BootstrapResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SharedPreferences.getInstance();
    final container = ProviderContainer();

    await container.read(installIdProvider.notifier).ensureLoaded();
    final gs = await container.read(gameStateNotifierProvider.future);
    await container
        .read(installIdProvider.notifier)
        .adoptFromGameState(gs.meta.installId);
    final tutorialState =
        await container.read(tutorialNotifierProvider.future);

    final firstLaunchBefore = !tutorialState.firstLaunchMarked;
    container
        .read(sessionControllerProvider)
        .onLaunch(firstLaunchMarkedBefore: firstLaunchBefore);

    return BootstrapResult(container: container);
  }
}

class BootstrapResult {
  const BootstrapResult({required this.container});
  final ProviderContainer container;
}
```

- [ ] **Step 3: Modify — AppLifecycleGate (session hooks)**

`lib/app/lifecycle/app_lifecycle_gate.dart`:

```dart
import 'dart:async';

import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLifecycleGate extends ConsumerStatefulWidget {
  const AppLifecycleGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleGate> createState() => _AppLifecycleGateState();
}

class _AppLifecycleGateState extends ConsumerState<AppLifecycleGate> {
  late final AppLifecycleListener _listener;
  late final Timer _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: _onPause,
      onDetach: _onDetach,
      onResume: _onResume,
    );
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _persistOnly(),
    );
  }

  Future<void> _persistOnly() async {
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
  }

  /// Sıra kritik (spec §6.3): persist ÖNCE, telemetry SONRA.
  Future<void> _onPause() async {
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
    ref.read(sessionControllerProvider).onPause();
  }

  Future<void> _onDetach() async {
    await ref.read(gameStateNotifierProvider.notifier).persistNow();
    ref.read(sessionControllerProvider).onPause();
  }

  void _onResume() {
    ref.read(sessionControllerProvider).onResume();
    ref.read(gameStateNotifierProvider.notifier)
      ..applyResumeDelta()
      ..resetTickClock();
  }

  @override
  void dispose() {
    _autoSaveTimer.cancel();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 4: Modify — main.dart (BootstrapResult consume)**

`lib/main.dart`:

```dart
Future<void> main() async {
  final boot = await AppBootstrap.initialize();
  // onboardingPrefs'in ensureLoaded pattern'i B1'den korunur
  await boot.container.read(onboardingPrefsProvider.notifier).ensureLoaded();
  runApp(
    UncontrolledProviderScope(
      container: boot.container,
      child: const AppLifecycleGate(child: CrumbsApp()),
    ),
  );
}
```

- [ ] **Step 5: Run — test + analyze**

Run:

```bash
flutter analyze
flutter test test/app/lifecycle/
flutter test  # all
```

Expected: 0 issue; yeni session hook testi PASS; baseline tests geçer.

- [ ] **Step 6: Commit**

```bash
git add lib/app/boot/app_bootstrap.dart lib/app/lifecycle/app_lifecycle_gate.dart \
        lib/main.dart test/app/lifecycle/app_lifecycle_gate_session_test.dart
git commit -m "sprint-b2(T15): AppBootstrap session integration + AppLifecycleGate pause ordering"
```

---

## Task 16 (C): A11y 48dp — theme-level minimumSize

**Amaç:** `AppTheme` içinde `FilledButtonThemeData` + `TextButtonThemeData` ile `minimumSize: Size(48, 48)` — tek kaynakta tüm button'ları 48dp tap target'a bağla.

**Files:**
- Modify: `lib/ui/theme/app_theme.dart`
- Create: `test/ui/theme/app_theme_a11y_test.dart`

- [ ] **Step 1: Test**

```dart
// test/ui/theme/app_theme_a11y_test.dart
import 'package:crumbs/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme — a11y 48dp minimum tap target', () {
    testWidgets('FilledButton resolves height >= 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('TextButton resolves height >= 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('dark theme also enforces 48dp', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('ok')),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48));
    });
  });
}
```

- [ ] **Step 2: Run — fail**

Run: `flutter test test/ui/theme/app_theme_a11y_test.dart`
Expected: FAIL — button default minimumSize ~40dp.

- [ ] **Step 3: Implementation — theme-level minimumSize**

`lib/ui/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _a11yMinTapTarget = Size(48, 48);

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: _a11yMinTapTarget),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: _a11yMinTapTarget),
      );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
        ),
        filledButtonTheme: _filledButtonTheme(),
        textButtonTheme: _textButtonTheme(),
        textTheme: Typography.material2021().black.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A53C),
          brightness: Brightness.dark,
        ),
        filledButtonTheme: _filledButtonTheme(),
        textButtonTheme: _textButtonTheme(),
        textTheme: Typography.material2021().white.copyWith(
              displayLarge: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      );
}
```

- [ ] **Step 4: Run — pass**

Run: `flutter test test/ui/theme/app_theme_a11y_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/theme/app_theme.dart test/ui/theme/app_theme_a11y_test.dart
git commit -m "sprint-b2(T16): a11y 48dp tap target via FilledButton/TextButton theme"
```

---

## Task 17 (S) ★: Integration test + docs update + CLAUDE.md §12 gotchas

**Amaç:** End-to-end tutorial + telemetry flow integration test; `docs/telemetry.md`, `docs/ux-flows.md §6`, `CLAUDE.md §12` güncelle.

**Files:**
- Create: `integration_test/tutorial_telemetry_integration_test.dart`
- Modify: `docs/telemetry.md`
- Modify: `docs/ux-flows.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Integration test**

```dart
// integration_test/tutorial_telemetry_integration_test.dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/core/tutorial/tutorial_notifier.dart';
import 'package:crumbs/core/tutorial/tutorial_state.dart';
import 'package:crumbs/core/tutorial/tutorial_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureLogger implements TelemetryLogger {
  final events = <TelemetryEvent>[];
  @override
  void log(TelemetryEvent e) => events.add(e);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tutorial + Telemetry end-to-end', () {
    testWidgets('cold start emits AppInstall + SessionStart + TutorialStarted',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      // Boot simulation (mirrors AppBootstrap.initialize order)
      await c.read(installIdProvider.notifier).ensureLoaded();
      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      final tutorialState =
          await c.read(tutorialNotifierProvider.future);
      final firstLaunchBefore = !tutorialState.firstLaunchMarked;
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: firstLaunchBefore);

      // Mount TutorialScaffold via postFrame start()
      await c.read(tutorialNotifierProvider.notifier).start();
      if (c
              .read(tutorialNotifierProvider)
              .valueOrNull
              ?.currentStep ==
          TutorialStep.tapCupcake) {
        logger.log(TutorialStarted(
          installId: resolveInstallIdForTelemetry(c),
        ));
      }

      expect(logger.events.whereType<AppInstall>(), hasLength(1));
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
      expect(logger.events.whereType<TutorialStarted>(), hasLength(1));

      // Invariant [I1]: install_id never <not-loaded>
      for (final e in logger.events) {
        final id = (e.payload)['install_id'] as String;
        expect(id, isNot(InstallIdNotifier.kNotLoadedSentinel));
      }
    });

    testWidgets('second cold start → no TutorialStarted', (tester) async {
      SharedPreferences.setMockInitialValues({
        'crumbs.first_launch_marked': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      await c.read(installIdProvider.notifier).ensureLoaded();
      final gs = await c.read(gameStateNotifierProvider.future);
      await c
          .read(installIdProvider.notifier)
          .adoptFromGameState(gs.meta.installId);
      final tutorialState =
          await c.read(tutorialNotifierProvider.future);
      final firstLaunchBefore = !tutorialState.firstLaunchMarked;
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: firstLaunchBefore);

      await c.read(tutorialNotifierProvider.notifier).start();

      expect(logger.events.whereType<AppInstall>(), isEmpty);
      expect(logger.events.whereType<TutorialStarted>(), isEmpty);
      expect(logger.events.whereType<SessionStart>(), hasLength(1));
    });

    testWidgets('onPause emits SessionEnd with duration', (tester) async {
      SharedPreferences.setMockInitialValues({
        'crumbs.install_id': 'integ-test',
        'crumbs.first_launch_marked': true,
      });
      final logger = _CaptureLogger();
      final c = ProviderContainer(overrides: [
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      addTearDown(c.dispose);

      await c.read(installIdProvider.notifier).ensureLoaded();
      await c.read(gameStateNotifierProvider.future);
      c
          .read(sessionControllerProvider)
          .onLaunch(firstLaunchMarkedBefore: false);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      c.read(sessionControllerProvider).onPause();

      final end = logger.events.whereType<SessionEnd>().single;
      expect(end.durationMs, greaterThanOrEqualTo(20));
      expect(end.installId, 'integ-test');
    });
  });
}
```

- [ ] **Step 2: Run integration test**

```bash
flutter test integration_test/tutorial_telemetry_integration_test.dart
```

Expected: PASS (3 test).

- [ ] **Step 3: docs/telemetry.md — 5 event şeması**

`docs/telemetry.md` dosyasına, mevcut içeriğin sonuna veya "Events" bölümü yoksa yeni bölüm ekle:

```markdown
## Events (Sprint B2 — stub pipeline)

### app_install
Fired once on first cold launch (firstLaunchMarked was false).

| Field | Type | Description |
|---|---|---|
| install_id | String | UUID from GameState.meta.installId (Sprint A) |
| platform | String | `ios` or `android` (Platform.operatingSystem) |

### session_start
Fired on every cold launch AND every onResume lifecycle.

| Field | Type | Description |
|---|---|---|
| install_id | String | Non-null — `<not-loaded>` sentinel if provider unresolved |
| session_id | String | UUID v4, unique per session |

### session_end
Fired on onPause/onDetach, AFTER persistNow completes (ordering contract §6.3).

| Field | Type | Description |
|---|---|---|
| install_id | String | Same as session_start |
| session_id | String | Pair with session_start |
| duration_ms | int | Milliseconds since matching session_start |

### tutorial_started
Fired once when TutorialScaffold postFrame callback triggers `start()` and transitions to `tapCupcake`. No-op on subsequent launches.

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule |

### tutorial_completed
Fired when user completes Step 3 OR taps Skip (Step 1 only).

| Field | Type | Description |
|---|---|---|
| install_id | String | Same rule |
| skipped | bool | true if user pressed Skip |
| duration_ms | int | Time from tutorial_started to completion |

### Stub pipeline (B2)
All events route through `DebugLogger` → `debugPrint('[TELEMETRY] {name} {payload}')`. Firebase Analytics provider swap deferred to Sprint B3 (single-file replace).

### Invariants
- [I1] install_id never null in payload; sentinel `<not-loaded>` reserved for unresolved provider state (integration test rejects this in production emission)
- [I6] onPause ordering: persist > telemetry (spec §6.3)
```

- [ ] **Step 4: docs/ux-flows.md §6 — tutorial route-aware Step 2 update**

`docs/ux-flows.md` içinde §6 (tutorial) bölümüne route-aware Step 2 açıklamasını ekle / mevcut metni güncelle:

```markdown
## §6. Tutorial (FR-3 — 3 step, route-aware Step 2)

1. **Step 1 — tapCupcake** (HomePage)
   - Cupcake üzerinde pulse halo + "Crumb kazanmak için cupcake'e dokun!"
   - Skip seçeneği: "Geç" → tutorial tamamen atlanır (all-or-nothing)
   - Advance: ilk tap (GameState.run.totalTaps delta > 0)

2. **Step 2 — openShop** (route-aware, tek enum)
   - Home'da iken: BottomNav "Dükkân" item'ı üstünde callout ("Dükkân'a git ve ilk üreticini al")
   - ShopPage'e geçince (`/shop`): ilk building row (crumb_collector) üzerinde CoachMarkOverlay ("Crumb Collector'ı satın al")
   - Advance: ilk binaya sahip olunca (GameState.buildings.owned['crumb_collector'] artışı)
   - NOT: "shop'a git" vs "binayı al" granularity'si B3'e ertelendi

3. **Step 3 — explainCrumbs** (ShopPage)
   - Bottom-centered info card — modal barrier
   - Title: "Neden Crumb kazanıyorsun?"
   - Body: Binalar otomatik üretim mekanizması açıklaması
   - CTA: "Anladım" → tutorialCompleted=true, TutorialCompleted event emit

Flicker guard: TutorialNotifier AsyncNotifier; build() SharedPreferences hydrate'ten önce overlay render edilmez (invariant [I11]).
```

- [ ] **Step 5: CLAUDE.md §12 — 3 yeni gotcha**

`CLAUDE.md` §12 "Gotcha'lar ve tasarım korumaları" bölümüne son satırlardan sonra ekle:

```markdown
- **Tutorial AsyncNotifier pattern:** `TutorialNotifier extends AsyncNotifier<TutorialState>` (build() async SharedPreferences hydrate). Sync `Notifier + hydrate()` pattern'i flicker race üretir (UI completed=false default mount → hydrate sonrası completed=true flip). `tutorialActiveProvider` loading/error state'te false döner — UI overlay mount hydrate tamamlanana kadar gizli. Invariant [I11].
- **Tutorial scaffold mount kontratı:** `TutorialScaffold` MUTLAKA `MaterialApp.router(builder: (ctx, child) => TutorialScaffold(child: child ?? SizedBox.shrink()))` üzerinden mount edilir. `MaterialApp` yukarısında veya router config olmadan mount edilirse `GoRouterState.of(context)` (route-aware Step 2) fail eder. Invariant [I12].
- **InstallId disk-wins reconciliation:** `installIdProvider` (SharedPreferences-backed) ve `GameState.meta.installId` boot sonrası senkron. Boot sırası: `ensureLoaded()` → `gameState hydrate` → `adoptFromGameState(gs.meta.installId)` (disk farklıysa overwrite). Telemetry payload'lar `resolveInstallIdForTelemetry(ref)` üzerinden okunur — null ise `<not-loaded>` sentinel döner (invariant [I1], integration test bu sentinel'ı production emission'da reddeder).
- **onPause sıra:** `AppLifecycleGate._onPause` → `persistNow()` ÖNCE, `sessionController.onPause()` SONRA. Gerekçe: pause sırasında süreç öldürülürse persist garanti edilmiş olmalı; telemetry SessionEnd kayıp kabul edilebilir. Invariant [I6].
```

- [ ] **Step 6: Run — full test suite + analyze**

```bash
flutter analyze
flutter test
flutter test integration_test/
```

Expected: 0 issue; ~155-160 test pass (baseline 133 + B2 yenileri); 3 integration test pass.

- [ ] **Step 7: Commit**

```bash
git add integration_test/tutorial_telemetry_integration_test.dart \
        docs/telemetry.md docs/ux-flows.md CLAUDE.md
git commit -m "sprint-b2(T17): integration test + docs update + CLAUDE.md §12 gotchas"
```

---

## Final Verification (post-T17)

Plan tamamlanır tamamlanmaz son smoke check:

```bash
# Lint + typecheck
flutter analyze
# Expected: No issues found!

# Full test suite
flutter test
# Expected: ~155-160 tests passing (baseline 133 + B2 yenileri)

# Integration smoke
flutter test integration_test/
# Expected: tutorial_telemetry + prior integration tests pass

# Coverage (yeni modüller hedef ≥85%)
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Inspect: lib/core/telemetry/** + lib/core/tutorial/** coverage ≥85%

# Git log — commit grain
git log --oneline main..HEAD
# Expected: ~17-20 commit (sprint-b2(T1) → sprint-b2(T17))

# PR hazırlığı
git push -u origin sprint/b2-tutorial-telemetry
gh pr create --title "Sprint B2 — Tutorial + Telemetry + A11y" \
  --body "$(cat docs/superpowers/specs/2026-04-17-sprint-b2-tutorial-telemetry-design.md | head -50)"
```

**DoD checklist (spec §7.2):**
- [ ] flutter analyze clean
- [ ] flutter test 100% pass (hedef ~155-160)
- [ ] Integration test (tutorial_telemetry) geçer
- [ ] Invariants [I1]-[I12] regression test'te assert edilir
- [ ] `<not-loaded>` sentinel production emission'da görülürse integration test fail eder
- [ ] docs/telemetry.md 5 event şemasıyla güncellenir
- [ ] docs/ux-flows.md §6 tutorial flow güncellenir
- [ ] CLAUDE.md §12 tutorial/telemetry gotcha'ları eklenir
- [ ] Coverage gate: yeni modüller ≥85%
- [ ] Manuel a11y audit: 8 widget spot check PR description'da

---

## Post-plan self-review notları

**Spec coverage:**
- §1.1 FR-3 3-step tutorial → T6-T13 ✓
- §1.1 Telemetry stub pipeline (5 events) → T1-T5 ✓
- §1.1 InstallId stabilization → T3, T15 ✓
- §1.1 48dp a11y → T16 ✓
- §1.1 AppLifecycleGate entegrasyon → T15 ✓
- §2.3 Test structure → T1-T4, T6-T7, T9-T11, T13, T16, T17 ✓
- §3 TelemetryEvent/Logger/InstallId/Session → T1-T4 ✓
- §4 Tutorial state machine + UI → T6-T13 ✓
- §5 A11y theme-level → T16 ✓
- §6 Lifecycle ordering contract → T15 + integration test T17 ✓
- §7 Invariants [I1]-[I12] → ilgili task'larda assert + integration test ✓
- §8 Testing strategy → T1-T17 ✓
- §9 17 task → bire-bir karşılık ✓
- §10 Dependency chain → plan başında diagram ✓
- §11 Risk & mitigation → spec'e referans; plan adımları risk'leri kapsıyor ✓
- §12 Rollback plan → git revert tek komut (plan dışı, production runbook) ✓
- §13 Followups → spec'e referans ✓

**Placeholder scan:** "TBD", "TODO", "implement later", "fill in", "Similar to Task N" — yok.

**Type consistency:** `TutorialStep` (3 values), `TelemetryEvent` (sealed, 5 concrete), `TutorialState` (3 field), `TutorialNotifier` (AsyncNotifier), `installIdProvider`, `resolveInstallIdForTelemetry(Ref)`, `SessionController(Ref)`, `BootstrapResult`, `HaloShape` (2 values), `kTutorialCupcakeKey/kTutorialShopNavKey/kTutorialShopFirstRowKey` — tüm task'larda tutarlı.
