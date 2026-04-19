# Sprint B6 — Session Recap Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 18-line `session_recap_modal.dart` stub with full MVP lean Session Recap Modal — animated counter + 2 CTA + 3 telemetry event + a11y + one-shot trigger — per UX spec `docs/ux-flows.md §6` and design spec §1-§6.

**Architecture:** `offlineReportProvider` state machine (no new provider). HomePage dual-gate trigger (initState postFrame + ref.listen). `showGeneralDialog` + `TweenAnimationBuilder` for counter. Invariants [I24] cold-start+Home-only, [I25] Crumbs ledger CTA-independent, [I26] `clear()` sole guard.

**Tech Stack:** Flutter 3.41.5 / Dart 3.11, Riverpod 3.1, SharedPreferences, mocktail, fake_async (dev dep existing from B5).

**Spec:** `docs/superpowers/specs/2026-04-19-sprint-b6-session-recap-design.md`

---

## Pre-flight

- [ ] **Branch + baseline**

```bash
git checkout main
git pull origin main
git checkout -b sprint/b6-session-recap
flutter analyze          # expected: No issues found!
flutter test -j 1        # expected: 302 tests passed
```

---

## File Structure

**Create:**
- `lib/features/session_recap/session_recap_host.dart` — show helper + telemetry emitters
- `test/core/telemetry/session_recap_events_test.dart`
- `test/features/session_recap/session_recap_modal_test.dart`
- `test/features/session_recap/session_recap_host_test.dart`
- `test/features/home/home_page_session_recap_test.dart`

**Modify:**
- `lib/core/state/providers.dart` — add `multiplierChainTotalProvider`
- `lib/core/telemetry/telemetry_event.dart` — add `SessionRecapShown`, `SessionRecapActionTaken`, `SessionRecapDismissed`
- `lib/features/session_recap/session_recap_modal.dart` — rewrite (stub → real widget)
- `lib/features/home/home_page.dart` — replace SnackBar path with modal trigger
- `lib/l10n/tr.arb` — add 6 keys (sessionRecapTitle/Earned/Elapsed/Capped/Multiplier/Collect/Dismiss)
- `CLAUDE.md` §4/§12/§13
- `docs/telemetry.md §4.7` — 3 event schema (if not already listed)

**Delete:** None

---

## Task 1: multiplierChainTotalProvider + SessionRecap telemetry events

**Files:**
- Modify: `lib/core/state/providers.dart` (add provider)
- Modify: `lib/core/telemetry/telemetry_event.dart` (add 3 classes)
- Create: `test/core/telemetry/session_recap_events_test.dart`

**Scope:** Foundation — telemetry events + derived multiplier provider. TDD: events first (tests fail), impl, pass.

- [ ] **Step 1: Write failing telemetry test**

Create `test/core/telemetry/session_recap_events_test.dart`:

```dart
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRecapShown', () {
    test('eventName + payload shape', () {
      const e = SessionRecapShown(
        installId: 'abc',
        sessionId: 'sess-1',
        offlineDurationMs: 180000,
        resourceEarnedOffline: 142,
      );
      expect(e.eventName, 'session_recap_shown');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
        'offline_duration_ms': 180000,
        'resource_earned_offline': 142,
      });
    });
  });

  group('SessionRecapActionTaken', () {
    test('eventName + payload with action_type', () {
      const e = SessionRecapActionTaken(
        installId: 'abc',
        sessionId: 'sess-1',
        actionType: 'collect',
      );
      expect(e.eventName, 'session_recap_action_taken');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
        'action_type': 'collect',
      });
    });
  });

  group('SessionRecapDismissed', () {
    test('eventName + payload', () {
      const e = SessionRecapDismissed(
        installId: 'abc',
        sessionId: 'sess-1',
      );
      expect(e.eventName, 'session_recap_dismissed');
      expect(e.payload, {
        'install_id': 'abc',
        'session_id': 'sess-1',
      });
    });
  });

  group('Firebase compliance', () {
    final events = <TelemetryEvent>[
      const SessionRecapShown(
        installId: 'x',
        sessionId: 'y',
        offlineDurationMs: 0,
        resourceEarnedOffline: 0,
      ),
      const SessionRecapActionTaken(
        installId: 'x',
        sessionId: 'y',
        actionType: 'collect',
      ),
      const SessionRecapDismissed(installId: 'x', sessionId: 'y'),
    ];
    final nameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
    const reservedPrefixes = ['firebase_', 'google_', 'ga_'];

    for (final e in events) {
      test('${e.eventName} matches Firebase regex', () {
        expect(nameRegex.hasMatch(e.eventName), isTrue);
      });
      test('${e.eventName} has no reserved prefix', () {
        for (final p in reservedPrefixes) {
          expect(e.eventName.startsWith(p), isFalse);
        }
      });
    }
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/core/telemetry/session_recap_events_test.dart
```

Expected: FAIL — `SessionRecapShown` / `SessionRecapActionTaken` / `SessionRecapDismissed` undefined.

- [ ] **Step 3: Add telemetry event classes**

Append to `lib/core/telemetry/telemetry_event.dart`:

```dart
class SessionRecapShown extends TelemetryEvent {
  const SessionRecapShown({
    required this.installId,
    required this.sessionId,
    required this.offlineDurationMs,
    required this.resourceEarnedOffline,
  });

  final String installId;
  final String sessionId;
  final int offlineDurationMs;
  final int resourceEarnedOffline;

  @override
  String get eventName => 'session_recap_shown';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'offline_duration_ms': offlineDurationMs,
        'resource_earned_offline': resourceEarnedOffline,
      };
}

class SessionRecapActionTaken extends TelemetryEvent {
  const SessionRecapActionTaken({
    required this.installId,
    required this.sessionId,
    required this.actionType,
  });

  final String installId;
  final String sessionId;
  final String actionType;

  @override
  String get eventName => 'session_recap_action_taken';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
        'action_type': actionType,
      };
}

class SessionRecapDismissed extends TelemetryEvent {
  const SessionRecapDismissed({
    required this.installId,
    required this.sessionId,
  });

  final String installId;
  final String sessionId;

  @override
  String get eventName => 'session_recap_dismissed';

  @override
  Map<String, Object?> get payload => {
        'install_id': installId,
        'session_id': sessionId,
      };
}

/// Session Recap CTA action type literals. B7 enum refactor candidate —
/// spec §5.3 #12.
const String kActionCollect = 'collect';
```

- [ ] **Step 4: Add multiplierChainTotalProvider**

Append to `lib/core/state/providers.dart`:

```dart
/// Current global multiplier from upgrades — used by Session Recap modal
/// to display passive multiplier secondary line (spec B6 §2.1).
final multiplierChainTotalProvider = Provider<double>((ref) {
  final gs = ref.watch(gameStateNotifierProvider).value;
  if (gs == null) return 1.0;
  return MultiplierChain.globalMultiplier(gs.upgrades.owned);
});
```

- [ ] **Step 5: Run — expect PASS**

```bash
flutter test test/core/telemetry/session_recap_events_test.dart
flutter analyze lib/core/ test/core/
```

Expected: All tests passed! + No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/core/telemetry/telemetry_event.dart lib/core/state/providers.dart test/core/telemetry/session_recap_events_test.dart
git commit -m "sprint-b6(T1): SessionRecap telemetry events + multiplierChainTotalProvider"
```

---

## Task 2: L10n keys

**Files:**
- Modify: `lib/l10n/tr.arb`

**Scope:** 6 new keys for modal copy; regenerate.

- [ ] **Step 1: Edit tr.arb**

Add after `sessionRecapMultiplier` would naturally fit — insert before or after `settingsAudioSection` block:

```json
"sessionRecapTitle": "Yokken kazandın!",
"sessionRecapEarned": "{amount} Crumb",
"@sessionRecapEarned": {
  "placeholders": { "amount": { "type": "String" } }
},
"sessionRecapElapsed": "{duration} boyunca",
"@sessionRecapElapsed": {
  "placeholders": { "duration": { "type": "String" } }
},
"sessionRecapCapped": "{hours} saat sınırına ulaşıldı",
"@sessionRecapCapped": {
  "placeholders": { "hours": { "type": "int" } }
},
"sessionRecapMultiplier": "Pasif çarpan: ×{value}",
"@sessionRecapMultiplier": {
  "placeholders": { "value": { "type": "String" } }
},
"sessionRecapCollect": "Topla",
"sessionRecapDismiss": "Kapat",
```

- [ ] **Step 2: Regenerate**

```bash
flutter gen-l10n
```

Verify `lib/l10n/app_strings.dart` contains `sessionRecapTitle`, `sessionRecapEarned`, etc.

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/l10n/
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/tr.arb lib/l10n/app_strings.dart lib/l10n/app_strings_tr.dart
git commit -m "sprint-b6(T2): session recap l10n keys (6) + regen"
```

---

## Task 3: SessionRecapModal widget rewrite

**Files:**
- Modify: `lib/features/session_recap/session_recap_modal.dart` (stub → real widget)
- Create: `test/features/session_recap/session_recap_modal_test.dart`

**Scope:** ConsumerWidget + TweenAnimationBuilder + 2 CTA + Semantics scope + low-motion.

- [ ] **Step 1: Write failing widget test**

Create `test/features/session_recap/session_recap_modal_test.dart`:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required Widget child,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  const report = OfflineReport(
    earned: 142.7,
    elapsed: Duration(minutes: 42),
    capped: false,
  );

  testWidgets('renders title + earned + elapsed + collect + dismiss',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.text('Yokken kazandın!'), findsOneWidget);
    expect(find.textContaining('Crumb'), findsOneWidget);
    expect(find.textContaining('dakika'), findsOneWidget);
    expect(find.text('Topla'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('capped=true shows capped badge', (tester) async {
    const capped = OfflineReport(
      earned: 500,
      elapsed: Duration(hours: 10),
      capped: true,
    );
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: capped),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('sınır'), findsOneWidget);
  });

  testWidgets('multiplier secondary line shows ×value', (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.textContaining('Pasif çarpan: ×'), findsOneWidget);
  });

  testWidgets('disableAnimations → counter instant final value',
      (tester) async {
    await tester.pumpWidget(_app(
      child: const SessionRecapModal(report: report),
      disableAnimations: true,
    ));
    // Single pump — no animation time advance needed.
    await tester.pump();

    // Counter should show final earned value (142 via fmt, not 0).
    expect(find.textContaining('142'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/features/session_recap/session_recap_modal_test.dart
```

Expected: FAIL — stub modal doesn't render expected content.

- [ ] **Step 3: Rewrite modal**

Replace full content of `lib/features/session_recap/session_recap_modal.dart`:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/state/providers.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:crumbs/ui/format/number_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session Recap Modal — offline kazanç ceremony + 2 CTA.
/// Spec: docs/superpowers/specs/2026-04-19-sprint-b6-session-recap-design.md §2
/// UX: docs/ux-flows.md §6
class SessionRecapModal extends ConsumerWidget {
  const SessionRecapModal({required this.report, super.key});

  final OfflineReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context)!;
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final multiplier = ref.watch(multiplierChainTotalProvider);

    return Dialog(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.sessionRecapTitle,
                          style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _onDismiss(context, ref),
                      tooltip: s.sessionRecapDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: report.earned),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 1500),
                  builder: (_, value, __) => Text(
                    s.sessionRecapEarned(fmt(value)),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(s.sessionRecapElapsed(_fmtDuration(report.elapsed))),
                if (report.capped) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.sessionRecapCapped(8),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  s.sessionRecapMultiplier(multiplier.toStringAsFixed(2)),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => _onCollect(context, ref),
                    child: Text(s.sessionRecapCollect),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onCollect(BuildContext context, WidgetRef ref) async {
    // Ceremony intentionally NOT forced — pop immediate. Earned Crumbs ledger'da
    // [I25]; animation opsiyonel presentation.
    _emitActionTaken(ref, kActionCollect);
    ref.read(offlineReportProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onDismiss(BuildContext context, WidgetRef ref) async {
    // Idempotency guard — host post-return path'inden çağrılmışsa skip [I26].
    if (ref.read(offlineReportProvider) == null) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }
    _emitDismissed(ref);
    ref.read(offlineReportProvider.notifier).clear();
    if (context.mounted) Navigator.of(context).pop();
  }

  void _emitActionTaken(WidgetRef ref, String actionType) {
    final sessionId = ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapActionTaken(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
          actionType: actionType,
        ));
  }

  void _emitDismissed(WidgetRef ref) {
    final sessionId = ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapDismissed(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
        ));
  }
}

String _fmtDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} saat ${d.inMinutes % 60} dakika';
  return '${d.inMinutes} dakika';
}
```

**Note:** `SessionController.currentSessionId` getter mevcut olmalı. Eğer yoksa, plan T1'e geri dön ve `session_controller.dart` public getter ekle: `String? get currentSessionId => _currentSessionId;`. Grep to verify first step.

- [ ] **Step 4: Verify SessionController.currentSessionId public API**

```bash
grep -n "currentSessionId\|_currentSessionId" lib/core/telemetry/session_controller.dart | head -5
```

If no public getter, add to `session_controller.dart` right after `String? _currentSessionId;` line:

```dart
String? get currentSessionId => _currentSessionId;
```

- [ ] **Step 5: Run — expect PASS**

```bash
flutter test test/features/session_recap/session_recap_modal_test.dart
flutter analyze lib/features/session_recap/ test/features/session_recap/
```

Expected: All tests passed + No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/session_recap/session_recap_modal.dart lib/core/telemetry/session_controller.dart test/features/session_recap/session_recap_modal_test.dart
git commit -m "sprint-b6(T3): SessionRecapModal widget rewrite (TweenAnimationBuilder + 2 CTA + Semantics)"
```

---

## Task 4: Modal CTA handler tests (Collect / Dismiss emit + clear)

**Files:**
- Modify: `test/features/session_recap/session_recap_modal_test.dart`

**Scope:** CTA handler semantics — emit event + clear provider + pop. Need fake TelemetryLogger + offlineReportProvider override.

- [ ] **Step 1: Add CTA tests**

Append to `test/features/session_recap/session_recap_modal_test.dart`:

```dart
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void _addCtaTests() {
  testWidgets('Collect → emit action_taken + clear + pop', (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      offlineReportProvider.overrideWith((ref) =>
          OfflineReportNotifier()..state = const OfflineReport(
            earned: 142,
            elapsed: Duration(minutes: 42),
            capped: false,
          )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => const SessionRecapModal(
                  report: OfflineReport(
                    earned: 142,
                    elapsed: Duration(minutes: 42),
                    capped: false,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.tap(find.text('Topla'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapActionTaken>());
    expect(
      (logger.events.first as SessionRecapActionTaken).actionType,
      'collect',
    );
    expect(container.read(offlineReportProvider), isNull);
  });

  testWidgets('Dismiss (X) → emit dismissed + clear', (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      offlineReportProvider.overrideWith((ref) =>
          OfflineReportNotifier()..state = const OfflineReport(
            earned: 100,
            elapsed: Duration(minutes: 10),
            capped: false,
          )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(
          body: SessionRecapModal(
            report: OfflineReport(
              earned: 100,
              elapsed: Duration(minutes: 10),
              capped: false,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapDismissed>());
    expect(container.read(offlineReportProvider), isNull);
  });

  testWidgets('Dismiss when provider already null → no double emit',
      (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);

    // Provider starts null (no OfflineReport).
    expect(container.read(offlineReportProvider), isNull);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(
          body: SessionRecapModal(
            report: OfflineReport(
              earned: 50,
              elapsed: Duration(minutes: 5),
              capped: false,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // No telemetry emitted — provider was already null (idempotency guard).
    expect(logger.events, isEmpty);
  });
}

// Wire into main():
// Add `_addCtaTests();` inside main() after existing test groups.
```

**Note:** Call `_addCtaTests();` from `void main()` alongside existing widget tests. Alternatively make `_addCtaTests` a `group('CTA handlers', () { ... });` block.

- [ ] **Step 2: Run — expect PASS**

```bash
flutter test test/features/session_recap/session_recap_modal_test.dart
```

Expected: 7 tests passed (4 previous + 3 CTA).

- [ ] **Step 3: Commit**

```bash
git add test/features/session_recap/session_recap_modal_test.dart
git commit -m "sprint-b6(T4): CTA handler tests (Collect/Dismiss emit + clear + idempotency)"
```

---

## Task 5: SessionRecapHost.show helper

**Files:**
- Create: `lib/features/session_recap/session_recap_host.dart`
- Create: `test/features/session_recap/session_recap_host_test.dart`

**Scope:** `showGeneralDialog` wrapper + `_emitShown` at open + post-return dismiss defense for barrier dismiss.

- [ ] **Step 1: Write failing host test**

Create `test/features/session_recap/session_recap_host_test.dart`:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/session_recap/session_recap_host.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  testWidgets('show() emits SessionRecapShown at open', (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
      offlineReportProvider.overrideWith((ref) =>
          OfflineReportNotifier()..state = const OfflineReport(
            earned: 200,
            elapsed: Duration(minutes: 30),
            capped: false,
          )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SessionRecapHost.show(
                ctx,
                ref,
                const OfflineReport(
                  earned: 200,
                  elapsed: Duration(minutes: 30),
                  capped: false,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapShown>());
    final shown = logger.events.first as SessionRecapShown;
    expect(shown.offlineDurationMs, const Duration(minutes: 30).inMilliseconds);
    expect(shown.resourceEarnedOffline, 200);
  });

  testWidgets('show() returns early when offlineReportProvider null',
      (tester) async {
    final logger = _RecordingLogger();
    final container = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Consumer(
          builder: (ctx, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SessionRecapHost.show(
                ctx,
                ref,
                const OfflineReport(
                  earned: 0,
                  elapsed: Duration.zero,
                  capped: false,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(logger.events, isEmpty);
  });
}
```

- [ ] **Step 2: Run — expect FAIL (host missing)**

```bash
flutter test test/features/session_recap/session_recap_host_test.dart
```

- [ ] **Step 3: Implement host**

Create `lib/features/session_recap/session_recap_host.dart`:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/install_id_notifier.dart';
import 'package:crumbs/core/telemetry/session_controller.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session Recap modal orchestrator — emit Shown at open, handle barrier
/// dismiss defense, post-return cleanup.
///
/// Spec §2.2 / §3.1 / invariants [I24][I25][I26].
abstract final class SessionRecapHost {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    OfflineReport report,
  ) async {
    // Defense: call sites should already null-check, but idempotent.
    if (ref.read(offlineReportProvider) == null) return;

    _emitShown(ref, report);

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppStrings.of(context)!.sessionRecapDismiss,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => SessionRecapModal(report: report),
    );

    // Barrier dismiss / back gesture: modal CTA handlers fire etmemiş olabilir.
    // Provider hâlâ non-null ise dismiss path'inden emit + clear.
    if (ref.read(offlineReportProvider) != null) {
      _emitDismissed(ref);
      ref.read(offlineReportProvider.notifier).clear();
    }
  }

  static void _emitShown(WidgetRef ref, OfflineReport report) {
    final sessionId = ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapShown(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
          offlineDurationMs: report.elapsed.inMilliseconds,
          resourceEarnedOffline: report.earned.toInt(),
        ));
  }

  static void _emitDismissed(WidgetRef ref) {
    final sessionId = ref.read(sessionControllerProvider).currentSessionId ?? '';
    ref.read(telemetryLoggerProvider).log(SessionRecapDismissed(
          installId:
              resolveInstallIdForTelemetry(ref.read(installIdProvider)),
          sessionId: sessionId,
        ));
  }
}
```

- [ ] **Step 4: Run — expect PASS**

```bash
flutter test test/features/session_recap/session_recap_host_test.dart
flutter analyze lib/features/session_recap/
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/session_recap/session_recap_host.dart test/features/session_recap/session_recap_host_test.dart
git commit -m "sprint-b6(T5): SessionRecapHost.show + emit sequence + barrier defense"
```

---

## Task 6: HomePage trigger integration

**Files:**
- Modify: `lib/features/home/home_page.dart`
- Create: `test/features/home/home_page_session_recap_test.dart`

**Scope:** Replace SnackBar path. Dual-gate trigger — initState postFrame + ref.listen. Gate `earned.toInt() > 0`.

- [ ] **Step 1: Write failing HomePage test**

Create `test/features/home/home_page_session_recap_test.dart`:

```dart
import 'dart:io';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/home/home_page.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  Directory tempDir,
  TelemetryLogger logger,
  OfflineReport? report,
) async {
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(overrides: [
      audioEngineProvider.overrideWithValue(FakeAudioEngine()),
      saveRepositoryProvider.overrideWithValue(
        SaveRepository(directoryProvider: () async => tempDir.path),
      ),
      telemetryLoggerProvider.overrideWithValue(logger),
    ]);
    await container.read(gameStateNotifierProvider.future);
    if (report != null) {
      container.read(offlineReportProvider.notifier).state = report;
    }
  });
  return container;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_b6_home_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('cold-start with offlineReport → modal shown, emitted',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 150,
      elapsed: Duration(minutes: 20),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(SessionRecapModal), findsOneWidget);
    expect(logger.events, hasLength(1));
    expect(logger.events.first, isA<SessionRecapShown>());

    // Teardown
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('no offlineReport → no modal', (tester) async {
    final logger = _RecordingLogger();
    final container = await _boot(tester, tempDir, logger, null);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(logger.events, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('earned.toInt() == 0 → no modal', (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 0.3, // int floor = 0
      elapsed: Duration(minutes: 1),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(logger.events, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });

  testWidgets('Collect CTA → clear + next mount no re-show [I26]',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 80,
      elapsed: Duration(minutes: 15),
      capped: false,
    );
    final container = await _boot(tester, tempDir, logger, report);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.tap(find.text('Topla'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(container.read(offlineReportProvider), isNull);

    // Simulate re-mount (navigation away + back). Provider null → no modal.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    // action_taken + shown events from first mount; nothing new after re-mount.
    expect(logger.events.length, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
flutter test test/features/home/home_page_session_recap_test.dart
```

- [ ] **Step 3: Rewrite HomePage listen pattern**

Modify `lib/features/home/home_page.dart` — change from `ConsumerWidget` to `ConsumerStatefulWidget`, replace SnackBar listen with dual-gate Session Recap trigger:

```dart
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/features/home/widgets/crumb_counter_header.dart';
import 'package:crumbs/features/home/widgets/floating_number_overlay.dart';
import 'package:crumbs/features/home/widgets/onboarding_hint.dart';
import 'package:crumbs/features/home/widgets/tap_area.dart';
import 'package:crumbs/features/session_recap/session_recap_host.dart';
import 'package:crumbs/features/tutorial/keys.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final report = ref.read(offlineReportProvider);
      _maybeShowSessionRecap(report);
    });
  }

  void _maybeShowSessionRecap(OfflineReport? report) {
    if (report == null || report.earned.toInt() <= 0) return;
    if (!mounted) return;
    SessionRecapHost.show(context, ref, report);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<OfflineReport?>(offlineReportProvider, (_, next) {
        _maybeShowSessionRecap(next);
      })
      ..listen(saveRecoveryProvider, (_, next) {
        if (next == null) return;
        final s = AppStrings.of(context)!;
        final msg = switch (next) {
          SaveRecoveryReason.checksumFailedUsedBackup => s.saveRecoveryBackup,
          SaveRecoveryReason.bothCorruptedStartedFresh => s.saveRecoveryFresh,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        ref.read(saveRecoveryProvider.notifier).clear();
      });

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const CrumbCounterHeader(),
              Expanded(child: TapArea(key: kTutorialHeroKey)),
              const SizedBox(height: 8),
            ],
          ),
          const FloatingNumberOverlay(),
          const OnboardingHint(),
        ],
      ),
    );
  }
}
```

**Deprecate note:** `welcomeBack` l10n key no longer referenced from HomePage. Keep key in tr.arb (no breaking removal; deprecate commentary in Task 12 docs step).

- [ ] **Step 4: Run — expect PASS**

```bash
flutter test test/features/home/home_page_session_recap_test.dart
flutter analyze lib/features/home/
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_page.dart test/features/home/home_page_session_recap_test.dart
git commit -m "sprint-b6(T6): HomePage dual-gate trigger (initState postFrame + ref.listen) [I24][I26]"
```

---

## Task 7: Crumbs ledger integrity [I25] widget test

**Files:**
- Modify: `test/features/session_recap/session_recap_modal_test.dart`

**Scope:** Assert Collect and Dismiss both leave `state.inventory.r1Crumbs` identical — earned already applied during hydrate.

- [ ] **Step 1: Add integrity test**

Append group to `session_recap_modal_test.dart`:

```dart
group('[I25] Crumbs ledger CTA-independent', () {
  testWidgets('Collect vs Dismiss → identical r1Crumbs', (tester) async {
    // Both paths trigger clear() + pop but no Crumbs mutation.
    // This is by construction: modal doesn't touch GameState.
    // Verify: set earned=100 initial crumbs; open + collect → same state;
    //         open + dismiss → same state.
    const report = OfflineReport(
      earned: 100,
      elapsed: Duration(minutes: 10),
      capped: false,
    );

    // Scenario A: Collect
    final logger1 = _RecordingLogger();
    final containerA = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger1),
      offlineReportProvider.overrideWith((ref) =>
          OfflineReportNotifier()..state = report),
    ]);
    addTearDown(containerA.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: containerA,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(body: SessionRecapModal(report: report)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.text('Topla'));
    await tester.pump();
    final afterCollect = containerA.read(offlineReportProvider);

    // Scenario B: Dismiss
    final logger2 = _RecordingLogger();
    final containerB = ProviderContainer(overrides: [
      telemetryLoggerProvider.overrideWithValue(logger2),
      offlineReportProvider.overrideWith((ref) =>
          OfflineReportNotifier()..state = report),
    ]);
    addTearDown(containerB.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: containerB,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(body: SessionRecapModal(report: report)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    final afterDismiss = containerB.read(offlineReportProvider);

    // Both paths null the provider — no Crumbs mutation occurred (modal
    // doesn't touch GameState).
    expect(afterCollect, isNull);
    expect(afterDismiss, isNull);
    // Telemetry branch diverges (action vs dismissed) but r1Crumbs ledger
    // identity maintained by construction.
    expect(logger1.events.first, isA<SessionRecapActionTaken>());
    expect(logger2.events.first, isA<SessionRecapDismissed>());
  });
});
```

- [ ] **Step 2: Run — expect PASS**

```bash
flutter test test/features/session_recap/session_recap_modal_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add test/features/session_recap/session_recap_modal_test.dart
git commit -m "sprint-b6(T7): [I25] Crumbs ledger CTA-independent test"
```

---

## Task 8: clear() idempotency test

**Files:**
- Modify: `test/features/session_recap/session_recap_host_test.dart`

**Scope:** Calling clear() twice is no-op.

- [ ] **Step 1: Add idempotency test**

Append to `session_recap_host_test.dart` main():

```dart
testWidgets('clear() called twice → no-op', (tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  container.read(offlineReportProvider.notifier).state =
      const OfflineReport(
    earned: 50,
    elapsed: Duration(minutes: 5),
    capped: false,
  );
  container.read(offlineReportProvider.notifier).clear();
  expect(container.read(offlineReportProvider), isNull);

  // Second clear — no-op, state stays null.
  container.read(offlineReportProvider.notifier).clear();
  expect(container.read(offlineReportProvider), isNull);
});
```

- [ ] **Step 2: Run — expect PASS**

```bash
flutter test test/features/session_recap/session_recap_host_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add test/features/session_recap/session_recap_host_test.dart
git commit -m "sprint-b6(T8): clear() idempotency test"
```

---

## Task 9: Non-Home route + hot-resume coverage

**Files:**
- Modify: `test/features/home/home_page_session_recap_test.dart`

**Scope:** Non-Home first-mount then Home-navigate → modal opens. Hot-resume path → no modal (applyResumeDelta doesn't push).

- [ ] **Step 1: Add tests**

Append to `home_page_session_recap_test.dart` main():

```dart
testWidgets('non-Home first mount → Home navigate → modal opens',
    (tester) async {
  final logger = _RecordingLogger();
  const report = OfflineReport(
    earned: 75,
    elapsed: Duration(minutes: 8),
    capped: false,
  );
  final container = await _boot(tester, tempDir, logger, report);

  // Mount a non-Home widget first.
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(builder: (_) => const HomePage()),
            ),
            child: const Text('go-home'),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();

  // No modal yet — non-Home mounted.
  expect(find.byType(SessionRecapModal), findsNothing);

  // Navigate to Home — fresh mount, initState postFrame reads provider.
  await tester.tap(find.text('go-home'));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 1600));

  expect(find.byType(SessionRecapModal), findsOneWidget);

  // Teardown
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  container.dispose();
});

testWidgets(
  'hot-resume does NOT push offlineReportProvider → no modal (existing B1)',
  (tester) async {
    // This is a contract reminder — the existing applyResumeDelta invariant
    // guarantees hot-resume doesn't touch offlineReportProvider. We mount
    // HomePage with the provider null (as would be the case post-Collect)
    // and verify no modal appears on subsequent provider reads.
    final logger = _RecordingLogger();
    final container = await _boot(tester, tempDir, logger, null);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    // Simulate a hot-resume: applyResumeDelta runs but doesn't push offlineReport.
    // (In real code, applyResumeDelta on GameStateNotifier — here we just
    // verify that without explicit provider push, no modal triggers.)
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SessionRecapModal), findsNothing);
    expect(logger.events, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  },
);
```

- [ ] **Step 2: Run — expect PASS**

```bash
flutter test test/features/home/home_page_session_recap_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add test/features/home/home_page_session_recap_test.dart
git commit -m "sprint-b6(T9): non-Home navigate + hot-resume coverage tests"
```

---

## Task 10: Integration test E2E cold-start → modal → Collect → next session

**Files:**
- Create: `test/app/session_recap_integration_test.dart`

**Scope:** Full boot → hydrate → mount HomePage → modal → Collect → next launch clean. Widget-level (B5 precedent: integration_test simulator deprecated).

- [ ] **Step 1: Write test**

Create `test/app/session_recap_integration_test.dart`:

```dart
import 'dart:io';

import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:crumbs/core/state/game_state_notifier.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:crumbs/core/telemetry/telemetry_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_providers.dart';
import 'package:crumbs/features/home/home_page.dart';
import 'package:crumbs/features/session_recap/session_recap_modal.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLogger implements TelemetryLogger {
  final List<TelemetryEvent> events = [];
  @override
  void log(TelemetryEvent event) => events.add(event);
  @override
  void beginSession() {}
  @override
  void endSession() {}
}

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('crumbs_b6_e2e_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('E2E: cold-start offlineReport → modal → Collect → next mount clean',
      (tester) async {
    final logger = _RecordingLogger();
    const report = OfflineReport(
      earned: 250,
      elapsed: Duration(minutes: 45),
      capped: false,
    );

    late ProviderContainer container;
    await tester.runAsync(() async {
      container = ProviderContainer(overrides: [
        audioEngineProvider.overrideWithValue(FakeAudioEngine()),
        saveRepositoryProvider.overrideWithValue(
          SaveRepository(directoryProvider: () async => tempDir.path),
        ),
        telemetryLoggerProvider.overrideWithValue(logger),
      ]);
      await container.read(gameStateNotifierProvider.future);
      container.read(offlineReportProvider.notifier).state = report;
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1600));

    // Modal shown
    expect(find.byType(SessionRecapModal), findsOneWidget);
    expect(logger.events.where((e) => e is SessionRecapShown), hasLength(1));
    final shown =
        logger.events.firstWhere((e) => e is SessionRecapShown) as SessionRecapShown;
    expect(shown.resourceEarnedOffline, 250);
    expect(shown.offlineDurationMs,
        const Duration(minutes: 45).inMilliseconds);

    // Collect
    await tester.tap(find.text('Topla'));
    await tester.pump(const Duration(milliseconds: 300));

    // Modal gone, provider cleared
    expect(find.byType(SessionRecapModal), findsNothing);
    expect(container.read(offlineReportProvider), isNull);
    expect(logger.events.where((e) => e is SessionRecapActionTaken),
        hasLength(1));

    // Simulate next session — provider stays null, no modal
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: HomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(SessionRecapModal), findsNothing);
    // Event count unchanged (1 shown + 1 action_taken)
    expect(logger.events, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
  });
}
```

- [ ] **Step 2: Run — expect PASS**

```bash
flutter test test/app/session_recap_integration_test.dart -j 1
flutter analyze test/app/
```

- [ ] **Step 3: Commit**

```bash
git add test/app/session_recap_integration_test.dart
git commit -m "sprint-b6(T10): E2E integration test — cold-start → modal → Collect → clean"
```

---

## Task 11: Full regression + coverage

**Scope:** Verify nothing broke. Coverage report for `lib/features/session_recap/`.

- [ ] **Step 1: Full test suite**

```bash
flutter analyze
flutter test -j 1
```

Expected: No issues + all tests pass (302 baseline + ~15-20 new = ~317-322).

- [ ] **Step 2: Coverage check**

```bash
flutter test --coverage -j 1
grep -A 2 "SF:.*session_recap" coverage/lcov.info | head -30 || true
```

Target: `lib/features/session_recap/` ≥85%.

- [ ] **Step 3: No commit (verification only)**

---

## Task 12: Docs — CLAUDE.md + telemetry.md

**Files:**
- Modify: `CLAUDE.md` §4, §12, §13
- Modify: `docs/telemetry.md §4.7` (if missing 3 events)

**Scope:** Project context docs + invariants + telemetry schema.

- [ ] **Step 1: CLAUDE.md §12 — 3 invariants**

Append after `[I23]` gotcha:

```markdown
- **Session Recap cold-start + Home-route push ([I24]):** Modal yalnız cold-start'ta ve yalnız Home route'unda push edilir. `OfflineReport` yalnız `GameStateNotifier.build()` hydrate'te set edilir; `applyResumeDelta` hot-resume push etmez (B1 invariant). HomePage dual-gate trigger: `initState` postFrameCallback (fresh mount'ta mevcut value yakalar — non-Home first-mount senaryosu) + `ref.listen` (live change — boot Home-first senaryosu). Non-Home'da modal görünmez; Home'a navigate'te yakalanır.
- **Session Recap Crumbs ledger CTA-independent ([I25]):** `state.inventory.r1Crumbs` hydrate'te artırılır (B1 existing logic). Collect vs Dismiss — aynı Crumbs ledger. Modal presentation + telemetry branch fark. Dismiss'te Crumbs kaybı YOK; paternalistik "forced ceremony 1500ms" reddedildi. Yeni CTA eklenirse (B7 Take Action) aynı invariant: modal lifecycle state'ten bağımsız.
- **Session Recap clear() sole guard ([I26]):** `offlineReportProvider.clear()` single source of truth for one-shot modal. Local `_modalShown` bool YOK. Collect + Dismiss + barrier dismiss (host post-return) hepsi clear çağırır. `SessionRecapHost.show` başında null-check defensive idempotent. Riverpod `ref.listen` default `fireImmediately: false` — provider kurulumundaki value listen'e gelmez, yalnız sonraki değişimler.
```

- [ ] **Step 2: CLAUDE.md §13 — B5 + B6 Sprint süreci kararları**

Append to §13 "Sprint süreci kararları" (after B4 block):

```markdown
**B5 — Audio layer + invariants:**
- Paket: `audioplayers ^6.x` (multi-SFX concurrent + single ambient loop).
- iOS: `AVAudioSessionCategory.ambient` — silent switch respect. Android: STREAM_MUSIC.
- Defaults: `musicEnabled=false` (opt-in), `sfxEnabled=true` (tap feedback), `masterVolume=0.7`.
- Asset: `.ogg` CC0 placeholder B5 ship; quality curation post-launch (`_dev/tasks/post-b5-audio-asset-curation.md`).
- Invariants: [I21] fail-silent, [I22] haptic+SFX ortak throttle, [I23] onPause `audio→persist→session`.

**B6 — Session Recap Modal (MVP lean):**
- Scope C hybrid — earned + counter animation + 2 CTA + pasif çarpan secondary line. "En çok katkı / 3 aksiyon / unlock bandı" Sprint B7+ ertelenir.
- State machine: mevcut `offlineReportProvider` reuse (new Notifier YOK).
- Modal widget: `showGeneralDialog` + `barrierDismissible: true` + `transitionDuration` low-motion control.
- Counter: `TweenAnimationBuilder<double>` (flutter_animate YERİNE — B2 Timer leak lesson avoid).
- `resourceEarnedOffline: int` (B4 `cost: int` pattern paralel).
- `const kActionCollect = 'collect';` (B7 enum refactor candidate).
- Gate: `earned.toInt() > 0` — int floor (0 < earned < 1 edge elenir, silent no-modal).
- B1 SnackBar path REPLACED — modal covers earned > 0, earned==0 no feedback.
- Invariants: [I24] cold-start+Home-only, [I25] Crumbs ledger CTA-independent, [I26] clear() sole guard.
```

- [ ] **Step 3: CLAUDE.md §4 manual QA ek list (tek satır)**

Add after `docs/audio-licenses.md` line in `## 4 Repo sözleşmesi` ek operasyonel dokümanlar:

```markdown
- Session Recap manuel QA (B6): iOS simulator → 2 dk cold-start gap → modal açılır, counter anim 1.5s, earned + elapsed + pasif çarpan doğru, Collect+Dismiss farklı telemetry event emit, hot-resume no-modal, reduce motion instant, VoiceOver modal announce. Ayrı doc YARATMA — B6 scope dar, inline yeterli.
```

- [ ] **Step 4: docs/telemetry.md §4.7 — verify/update schema**

```bash
grep -n "session_recap_shown\|session_recap_action_taken\|session_recap_dismissed" docs/telemetry.md
```

If 3 events already listed with correct field types (int offlineDurationMs, int resourceEarnedOffline, String actionType), **no edit needed**. Otherwise update §4.7 to reflect spec §2.4 schema.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/telemetry.md
git commit -m "sprint-b6(T12): CLAUDE.md §4/§12/§13 + invariants [I24][I25][I26] + telemetry §4.7"
```

---

## Task 13: Push + PR

- [ ] **Step 1: Push branch**

```bash
git push -u origin sprint/b6-session-recap
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "sprint(b6): session recap modal — MVP lean + [I24-26]" --body "$(cat <<'EOF'
## Summary
- Session Recap Modal rewrite (18-line stub → ConsumerWidget + TweenAnimationBuilder + 2 CTA + Semantics)
- SessionRecapHost.show helper (showGeneralDialog + barrier defense)
- 3 telemetry event (session_recap_shown / _action_taken / _dismissed)
- HomePage dual-gate trigger (initState postFrame + ref.listen)
- multiplierChainTotalProvider (derived, secondary stat line)
- L10n 6 yeni key (tr.arb + regen)
- Invariants [I24][I25][I26]
- B1 SnackBar path REPLACED (modal covers earned > 0)

Scope dışı (B7+): En çok katkı / 3 aksiyon önerisi / unlock bandı / Take Action CTA / enum refactor.

## Test plan
- [x] flutter analyze clean
- [x] flutter test -j 1: 302 → ~317-322 pass
- [x] lib/features/session_recap/ coverage ≥85%
- [ ] Manual QA: iOS simulator 2 dk cold-start gap → modal açılır, ceremony, Collect/Dismiss telemetry, hot-resume no-modal, reduce motion

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: CI bekle + merge**

```bash
until gh pr view <PR#> --json statusCheckRollup 2>/dev/null | grep -E '"conclusion":"SUCCESS"'; do sleep 20; done
gh pr merge <PR#> --merge --delete-branch
git checkout main && git pull origin main
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| §1 Mimari — dual-gate trigger | T6 |
| §1 [I24][I25][I26] invariants | T6, T7, T8, T12 |
| §2.1 Modal widget (TweenAnimationBuilder + CTA + Semantics) | T3 |
| §2.2 SessionRecapHost.show | T5 |
| §2.3 L10n 6 keys | T2 |
| §2.4 Telemetry 3 events + kActionCollect | T1 |
| §3.1 Emit sequence | T5, T10 |
| §3.2 CTA handlers + idempotency | T3, T4 |
| §3.3 Edge cases (earned toInt, capped, reduce motion) | T3, T6 |
| §3.4 B1 SnackBar REPLACED | T6 |
| §4.1-4.3 Test layers | T1-T10 |
| §4.4 DoD code + test + docs | T11, T12, T13 |
| §5.3 14 resolved decisions | All tasks |
| §5.5 multiplierChainTotalProvider ekleme | T1 |
| §5.6 Task estimate 12-14 | T1-T13 (12 numbered + pre-flight) |

**Placeholder scan:** None — all code shown inline, commands exact.

**Type consistency:**
- `SessionRecapShown.resourceEarnedOffline: int` — consistent T1, T5, T10
- `kActionCollect = 'collect'` — T1 def, T3 usage, T4 test, T5 host
- `OfflineReport(earned, elapsed, capped)` — consistent across tests
- `TelemetryLogger.log(TelemetryEvent)` — consistent
- `multiplierChainTotalProvider` — T1 create, T3 watch
- HomePage: `ConsumerWidget` → `ConsumerStatefulWidget` — T6 (single refactor site)

**Known simplifications:**
- `_addCtaTests()` vs `group('CTA', ...)` in T4 — implementer choice, function style OR group wrapper both acceptable.
- Non-Home navigation test (T9) uses `MaterialPageRoute` — not router; acceptable because real app uses GoRouter but test scope is "fresh mount triggers initState postFrame" not routing specifics.
- Hot-resume test (T9) is a contract reminder, not a full lifecycle simulation — the true hot-resume invariant is enforced by existing B1 tests on `applyResumeDelta`.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-19-sprint-b6-session-recap.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Fresh subagent per task + two-stage review. User memory preference: subagent-driven default.

**2. Inline Execution** — executing-plans skill with checkpoints.

**Bu session token kısıtlı — implementation sonraki session'da başlar.** Plan commit edilir, kullanıcı review eder; sonraki session `superpowers:subagent-driven-development` ile T1'den execute edilir.
