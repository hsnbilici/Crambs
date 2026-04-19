# Sprint B6 — Session Recap Modal Design

**Tarih:** 2026-04-19
**Durum:** Design freeze — writing-plans stage'ine hazır
**Branch (hedef):** `sprint/b6-session-recap` (plan onayından sonra)
**Kaynak:** `docs/ux-flows.md §6` (UX spec), `docs/telemetry.md §4.7` (event schema), PRD §6.9 (Kritik MVP).

---

## Goal

UX spec `docs/ux-flows.md §6` Session Recap Modal'ın MVP lean subset implementation'ı (spec §6.9 "Kritik MVP" kapsamı). Modal iskelet + animated counter + 2 CTA (Collect + Dismiss) + 3 telemetry event + a11y. "En çok katkı / 3 aksiyon önerisi / unlock bandı" Sprint B7+ ertelenir.

**Değer:** Offline kazanç UX feedback'i SnackBar'dan (B1 pattern) Modal'a çıkar — kullanıcının "yokken ne kazandım?" sorusu ceremony + animation ile cevaplanır. Pasif çarpan dahil edilmesi "upgrade'lerim çalışıyor mu?" sorusunu da kapsar. Telemetry cohort analysis (D1/D7 retention vs session_recap_shown rate) için temel.

---

## Architecture (§1)

### Module layout

```
lib/features/session_recap/
  session_recap_modal.dart            # ConsumerWidget — modal UI + animated counter
  session_recap_host.dart             # HomePage'den ayrılmış listen + show logic
```

**No new provider.** Mevcut `offlineReportProvider` state machine olarak kullanılır. Modal lifecycle `offlineReportProvider.clear()` çağrısıyla güdülenir.

### Trigger pattern

**İki gate, tek invariant (clear):**

```dart
// HomePage (HomePage değişmese de session_recap_host.dart'ta olabilir)
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final report = ref.read(offlineReportProvider);
    if (report != null && mounted) {
      SessionRecapHost.show(context, ref, report);
    }
  });
}

@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen<OfflineReport?>(offlineReportProvider, (prev, next) {
    if (next != null && mounted) {
      SessionRecapHost.show(context, ref, next);
    }
  });
  // ...existing home UI
}
```

**Scenario coverage:**
- Cold-start boot → Home first mount → initState postFrame yakalar → modal push → clear
- Cold-start boot → Settings first (non-Home route) → kullanıcı Home'a navigate → Home fresh mount initState postFrame hâlâ provider'da value → modal push
- Hot-resume → `applyResumeDelta` offlineReport push ETMEZ (mevcut B1 invariant) → no modal
- Modal dismissed → clear() → listen next change (yok) no-op

**Riverpod `ref.listen` default `fireImmediately: false`:** provider kurulumundaki initial value listen'e gelmez, yalnız sonraki değişimler. Cold-start'ta value provider kurulumunda set edilir — sonraki change listen'i tetiklemez. initState postFrame tek yakalayıcı. Double-push riski YOK — Riverpod 3.1 davranışı doğrulanır ([I26] test gate).

### Invariants (yeni)

- **[I24]** Session Recap modal yalnız cold-start'ta push edilir (`OfflineReport` yalnız `GameStateNotifier.build()` hydrate path'inde set edilir — `applyResumeDelta` hot-resume push etmez, B1 mevcut invariant). Home route'unda gösterilir (HomePage listen + initState).
- **[I25]** Earned Crumbs hydrate sırasında state'e eklenir; modal presentation layer. `offlineReport != null && offlineReport.earned > 0` koşulunda `state.inventory.r1Crumbs` zaten yükseltilmiş (GameStateNotifier.build existing code). CTA branch'ları arasında Crumbs farkı YOK — Collect ceremony + telemetry `_action_taken`, Dismiss silent skip + telemetry `_dismissed`.
- **[I26]** One-shot modal: `offlineReportProvider.clear()` hem Collect hem Dismiss path'inde çağrılır. `_modalShown` gibi ek local guard YOK (clear = single source of truth). Test: cold-start mount → 1 modal; subsequent provider changes → 0 modal.

---

## Components & Contracts (§2)

### 2.1 SessionRecapModal widget

```dart
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
                Text(s.sessionRecapCapped(8),
                    style: theme.textTheme.bodySmall),
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
    );
  }
  // _onCollect, _onDismiss handlers — see §3.4
}
```

### 2.2 SessionRecapHost.show

```dart
abstract final class SessionRecapHost {
  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    OfflineReport report,
  ) async {
    // Idempotent — provider null check'i caller'da ama defense-in-depth.
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

    // barrierDismissible=true ile backdrop tap veya back gesture modal'ı kapatırsa
    // emit _dismissed fire etmemiş olur. Defense: show sonrası provider hâlâ
    // non-null ise dismissed path'inden clear.
    if (ref.read(offlineReportProvider) != null) {
      _emitDismissed(ref);
      ref.read(offlineReportProvider.notifier).clear();
    }
  }
  // Telemetry emitters — see §3
}
```

**Backdrop tap / back gesture:** `showGeneralDialog` `barrierDismissible: true` ile dismiss. CTA handler'ları fire etmez — show future return sonrası host `_dismissed` telemetry emit + clear.

### 2.3 L10n keys (tr.arb eklentileri)

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
"sessionRecapDismiss": "Kapat"
```

Mevcut `welcomeBack` l10n key (B1 SnackBar) — **korunur**, Home'daki yalın durum için (capped durumunda edge case fallback) veya Session Recap modal'ı hiç açılmadıysa (ör. offline earned = 0 durumunda SnackBar hâlâ uygun). Bkz §3.5 fallback policy.

### 2.4 Telemetry event schema (docs/telemetry.md §4.7)

```dart
// lib/core/telemetry/telemetry_event.dart'a eklenir.
final class SessionRecapShown extends TelemetryEvent {
  const SessionRecapShown({
    required this.installId,
    required this.sessionId,
    required this.offlineDurationMs,
    required this.resourceEarnedOffline,  // int, floor'lu
  });
  final String installId;
  final String sessionId;
  final int offlineDurationMs;
  final int resourceEarnedOffline;

  @override
  String get eventName => 'session_recap_shown';

  @override
  Map<String, Object> toParams() => {
    'install_id': installId,
    'session_id': sessionId,
    'offline_duration_ms': offlineDurationMs,
    'resource_earned_offline': resourceEarnedOffline,
  };
}

final class SessionRecapActionTaken extends TelemetryEvent {
  const SessionRecapActionTaken({
    required this.installId,
    required this.sessionId,
    required this.actionType,  // B6: sadece kActionCollect
  });
  final String installId;
  final String sessionId;
  final String actionType;

  @override
  String get eventName => 'session_recap_action_taken';

  @override
  Map<String, Object> toParams() => {
    'install_id': installId,
    'session_id': sessionId,
    'action_type': actionType,
  };
}

final class SessionRecapDismissed extends TelemetryEvent {
  const SessionRecapDismissed({
    required this.installId,
    required this.sessionId,
  });
  final String installId;
  final String sessionId;

  @override
  String get eventName => 'session_recap_dismissed';

  @override
  Map<String, Object> toParams() => {
    'install_id': installId,
    'session_id': sessionId,
  };
}

// session_recap_host.dart veya aynı dosya
const String kActionCollect = 'collect';
// B7 refactor'da: enum SessionRecapActionType { collect, openShop, buyBuilding, ... }
```

**Int dönüşüm:** `resourceEarnedOffline: report.earned.toInt()` — dashboard aggregation integer arithmetic (B4 `cost: int` pattern paralel).

---

## Data Flow + Lifecycle Integration (§3)

### 3.1 Emit sequence

**Cold-start Home-first:**
1. `main.dart` → `FirebaseBootstrap` → `AppBootstrap` → `container.read(audioSettingsProvider.future)` → `runApp`
2. `GameStateNotifier.build()` async hydrate → `SaveRepository.load` → `OfflineProgress.compute` → `offlineReportProvider.state = report` (existing B1 code)
3. `CrumbsApp` MaterialApp router mount → `/` → HomePage mount
4. `HomePage.initState` → `addPostFrameCallback`
5. PostFrame tick → `ref.read(offlineReportProvider)` non-null → `SessionRecapHost.show(...)`
6. `SessionRecapHost.show`:
   - `_emitShown` → `telemetryLoggerProvider.log(SessionRecapShown(...))`
   - `showGeneralDialog` → modal mount
   - Animated counter tween 0 → earned (1.5s, Duration.zero if reduceMotion)
7. User tap Collect or Dismiss (see §3.4)

**Cold-start non-Home first (Settings deep-link):**
- Steps 1-3 same, but user starts at `/settings` (or similar)
- Modal NOT pushed (HomePage not mounted yet)
- User navigates to `/` → HomePage mount → initState postFrame catches existing `offlineReportProvider` value → modal push

**Hot-resume (no modal):**
- `AppLifecycleListener.onResume` → `GameStateNotifier.applyResumeDelta` → `offlineReport` provider NOT touched (B1 invariant)
- `HomePage` already mounted → no initState re-fire
- No modal. Correct per [I24].

### 3.2 CTA handlers

```dart
// session_recap_modal.dart

Future<void> _onCollect(BuildContext context, WidgetRef ref) async {
  // Ceremony intentionally NOT forced — pop immediate. Kullanıcı ilk 200ms
  // içinde Collect'e tap ederse counter animation henüz peak'e ulaşmadan
  // modal kapanır. Paternalistik "disabled 1500ms" UX reddedildi. Earned
  // Crumbs zaten ledger'da [I25] — animation opsiyonel presentation.
  _emitActionTaken(ref, actionType: kActionCollect);
  ref.read(offlineReportProvider.notifier).clear();
  if (context.mounted) Navigator.of(context).pop();
}

Future<void> _onDismiss(BuildContext context, WidgetRef ref) async {
  // Explicit X tap — emit dismissed + pop. Backdrop tap / back gesture is
  // handled by SessionRecapHost.show post-return logic (defense-in-depth for
  // barrier dismiss).
  //
  // Idempotency guard: provider null ise (host post-return path'inden
  // çağrılmışsa) skip — [I26] single-source clear invariant'ını korur.
  if (ref.read(offlineReportProvider) == null) {
    if (context.mounted) Navigator.of(context).pop();
    return;
  }
  _emitDismissed(ref);
  ref.read(offlineReportProvider.notifier).clear();
  if (context.mounted) Navigator.of(context).pop();
}
```

### 3.3 Edge cases

| Senaryo | Davranış |
|---|---|
| `earned == 0` veya `earned.toInt() == 0` (tam 60s boundary veya capped=0 veya 0 < earned < 1) | Modal açılmaz, SnackBar da yok — sessiz geçiş. Telemetry emit edilmez (kullanıcı hiçbir şey yapmadı gözlemi). Gate kodda **explicit**: `if (report != null && report.earned.toInt() > 0)` — double `earned > 0` ile integer floor `.toInt() > 0` tutarsız olmasın. 0 < earned < 1 edge'i int floor ile elenir. |
| `capped == true` | Modal "8 saat sınırına ulaşıldı" badge gösterir. Earned clamp yansıtılmış. |
| Pre-hydrate Home mount (boot race) | initState postFrame henüz `offlineReportProvider` null; listen kurulmuş. Hydrate sonrası provider set → listen `prev=null, next=report` → push. OK. |
| Reduce motion ON | TweenAnimationBuilder Duration.zero → counter instant final value. showGeneralDialog transitionDuration.zero → modal pop instant. Content identical. |
| User 2. kez Collect (rapid double-tap) | İlk tap clear() + Navigator.pop → modal dispose. Second tap no-op (widget dead). Guard değil, race-hardened. |
| Back gesture on open modal | showGeneralDialog barrierDismissible=true → pop. Host post-return check `offlineReportProvider` hâlâ non-null → dismissed emit + clear. |
| Modal mount sırasında app pause | AppLifecycleGate.onPause → pauseAmbient + persist + session. Modal visible kalır. Resume'da modal hâlâ açık, counter animation devam/bitmiş. No issue — modal presentation state'ten bağımsız. |

### 3.4 Fallback: B1 SnackBar path

Mevcut HomePage `ref.listen(offlineReportProvider)` SnackBar koduyla replace edilir mi yoksa paralel mi çalışır?

**Karar:** Replace — `earned > 0` ise modal, `earned == 0` ise nothing (SnackBar gereksiz edge). Mevcut `welcomeBack` SnackBar code path silinir. `welcomeBack` l10n key korunur (başka kullanım olursa; aksi halde deprecate).

**Rationale:** Modal ve SnackBar aynı anda iki UX feedback = gereksiz. Modal offline earned > 0 için kapsayıcı. Boundary (earned=0) modal göstermeye değmez — SnackBar bile gereksiz (kullanıcı 60s altında pause etti, hiçbir şey olmadı).

---

## Testing Strategy + DoD (§4)

### 4.1 Test layers

| Katman | Kapsam | Dosya |
|---|---|---|
| Unit | TelemetryEvent schema (name regex, reserved prefix, toParams), kActionCollect const | `test/core/telemetry/session_recap_events_test.dart` |
| Widget | Modal render (counter, elapsed, capped, multiplier, CTA), Collect/Dismiss handlers, low-motion Duration.zero, idempotent clear | `test/features/session_recap/session_recap_modal_test.dart` |
| Widget | SessionRecapHost.show emit sequence (shown → dismissed on backdrop), no-modal when report null | `test/features/session_recap/session_recap_host_test.dart` |
| Widget | HomePage trigger pattern (initState postFrame + listen), one-shot [I26], cold-start non-Home navigation | `test/features/home/home_page_session_recap_test.dart` |
| Integration | Cold-start → Home mount → modal push → Collect → next session clean | `integration_test/session_recap_integration_test.dart` (veya `test/app/` widget-level, B5 precedent) |

### 4.2 Kritik test senaryoları

- **Telemetry schema:** 3 event — `eventName` Firebase regex (`^[a-zA-Z][a-zA-Z0-9_]{0,39}$`) + no reserved prefix (`firebase_`, `google_`, `ga_`)
- **Modal render:** `TweenAnimationBuilder` mount → `pump(const Duration(milliseconds: 1600))` (1.5s animation + buffer) → final value displayed. `pumpAndSettle` tercih edilmez — 1.5s frame-by-frame bekleme test slow + tick timer interference; explicit duration pump kontrollü.
- **Low-motion:** `MediaQuery.disableAnimations=true` → counter Text shows final value on first pump
- **Collect CTA:** tap FilledButton → SessionRecapActionTaken(`action_type: 'collect'`) emitted + `offlineReportProvider` cleared + modal popped
- **Dismiss X CTA:** tap close icon → SessionRecapDismissed + clear + pop
- **Backdrop dismiss:** `tester.tapAt(Offset.zero)` (outside dialog) → SessionRecapDismissed (via host post-return) + clear
- **[I26] one-shot:** cold-start mount → 1 modal; subsequent `offlineReportProvider.state = newValue` (artificial) → push fires listen path; no double-push since clear'ed
- **[I25] Crumbs integrity:** Collect vs Dismiss — `state.inventory.r1Crumbs` identical (earned already applied during hydrate)
- **clear() idempotent:** `clear()` iki kez çağrılması no-op, state null kalır
- **Non-Home cold-start:** router mount `/settings` → no modal; `context.go('/')` → HomePage mount → initState postFrame → modal push
- **Hot-resume:** `applyResumeDelta` → `offlineReportProvider` NOT touched → no modal (existing B1 invariant test + session recap integration)

### 4.3 Coverage hedefi

- `lib/features/session_recap/` → ≥85%
- Platform-specific widget test exclusion yok (tümü Flutter cross-platform)

### 4.4 Definition of Done

**Code:**
- [ ] `lib/features/session_recap/session_recap_modal.dart` rewrite (ConsumerWidget + TweenAnimationBuilder)
- [ ] `lib/features/session_recap/session_recap_host.dart` yeni
- [ ] `lib/core/telemetry/telemetry_event.dart` 3 subclass ekleme
- [ ] `lib/features/home/home_page.dart` — SnackBar path silinir, initState postFrame + listen SessionRecapHost.show
- [ ] `lib/l10n/tr.arb` — 6 yeni key + regenerate
- [ ] kActionCollect sabit + SessionRecapActionType enum TODO (B7 refactor note)
- [ ] CLAUDE.md §12 — [I24][I25][I26] gotcha paragrafları

**Tests:**
- [ ] `flutter analyze`: No issues
- [ ] `flutter test -j 1`: tüm mevcut test + ~15-20 yeni session recap test (302 → ~317+)
- [ ] `lib/features/session_recap/` coverage ≥85%

**Manuel QA (docs/audio-plan.md pattern):**
- [ ] iOS simulator → 2 dakikalık cold-start gap → app launch → modal açılır, counter anim 1.5s, earned "+X Crumbs" doğru, pasif çarpan gösterilir
- [ ] Collect tap → modal kapan + Home'da sayaç güncel
- [ ] Dismiss (X) + Dismiss (backdrop) → modal kapan + Home'da sayaç yine güncel (identical, [I25] doğrula)
- [ ] Non-Home cold-start → Settings'e direkt → Home'a geç → modal açılır
- [ ] Hot-resume → ambient/no issue, modal açılmaz
- [ ] VoiceOver (iOS) / TalkBack (Android) → modal announce + focus title + CTA accessible
- [ ] Settings → Reduce Motion ON → cold-start → counter instant, transition instant

**Docs:**
- [ ] `CLAUDE.md §5` — `features/session_recap/` directory tree already present (stub vardı, rewrite)
- [ ] `CLAUDE.md §12` — 3 invariant gotcha
- [ ] `CLAUDE.md §13` — post-PRD decisions B6 subsection (MVP lean scope, B7 extension plan)
- [ ] `docs/telemetry.md §4.7` — schema güncelleme (int type, actionType literal kApi)

---

## Scope + Risks + Task Estimate (§5)

### 5.1 IN Scope (B6)

- SessionRecapModal rewrite (stub → real ConsumerWidget)
- SessionRecapHost helper (show + post-return dismiss defense)
- 3 TelemetryEvent subclass (Shown / ActionTaken / Dismissed)
- HomePage trigger (initState postFrame + ref.listen, SnackBar path silinir)
- L10n 6 yeni key + regen
- Invariants [I24][I25][I26]
- Unit + widget + integration test (≥85% coverage)
- A11y: scopesRoute, explicitChildNodes, disableAnimations, focus management, 44×44 tap
- showGeneralDialog + barrierDismissible + transitionDuration control

### 5.2 OUT of Scope (Sprint B7+)

- "En çok katkı: [Bina]" — OfflineProgress per-building refactor, OfflineReport extension
- "En verimli 3 aksiyon önerisi" — ROI advisor modülü (yeni `lib/core/advisor/`)
- "Yeni özellik unlock bandı" — progression diff tracker
- "Take Action" CTA (3+) — GoRouter deep-link
- `SessionRecapActionType` enum refactor (literal `kActionCollect` → typed enum)
- Hero motion sinematik prestige geçişi
- Modal content kişiselleştirme (ör. "Bugünün en verimli oyuncusu" social)

### 5.3 Resolved Decisions

1. Scope: **C Hybrid** — lean MVP + pasif çarpan secondary line
2. State machine: **No new provider** — offlineReportProvider state machine
3. Listen: **HomePage initState postFrame + ref.listen** (both gates, clear() sole guard)
4. `_modalShown` local guard: **REMOVED** — `offlineReportProvider.clear()` sole source of truth
5. Counter animation: **TweenAnimationBuilder<double>** (no flutter_animate — B2 leak lesson avoid)
6. Low-motion: **Duration.zero** (disableAnimations MediaQuery)
7. Modal widget: **showGeneralDialog** (transitionDuration control) — not showDialog
8. Barrier: **barrierDismissible: true** (backdrop tap = Dismiss)
9. CTA count B6: **2** (Collect + Dismiss); Take Action B7
10. `resourceEarnedOffline` type: **int** (floor'lu, B4 cost pattern paralel)
11. A11y modal announce: **Semantics(scopesRoute, explicitChildNodes)** manual (showGeneralDialog doesn't auto-wrap)
12. Telemetry literal: **`const kActionCollect = 'collect';`** (B7 enum refactor)
13. Fallback: **B1 SnackBar REPLACED** — modal covers earned > 0, earned==0 no feedback
14. Multiplier display: **secondary stat line "Pasif çarpan: ×1.50"** (via multiplierChainTotalProvider)

### 5.4 Risks

| Risk | Olasılık | Impact | Mitigasyon |
|---|---|---|---|
| `showGeneralDialog` barrier dismiss double-emit (host post-return + modal onDismiss) | Orta | Düşük | host post-return check: `if (ref.read(offlineReportProvider) != null)` — CTA handler'ları clear'lamışsa skip |
| `TweenAnimationBuilder` low-motion Duration.zero counter flicker | Düşük | Düşük | Duration.zero = instant final value, no frame flicker (Flutter framework guarantee) |
| HomePage initState postFrame vs listen double-push | Düşük | Düşük | Riverpod 3.1 ref.listen fireImmediately=false default; provider kurulumundaki value listen'e gelmez (test ile doğrulanır) |
| non-Home cold-start (Settings deep-link) hydrate race | Düşük | Düşük | HomePage mount'ta `ref.read(offlineReportProvider)` hydrate tamamlandığı için already-set value yakalar |
| Multiplier provider mevcut değil (Sprint A/B1) | Düşük | Orta | Plan task T1: `multiplierChainTotalProvider` varlık doğrulaması; yoksa basit compute `ref.watch(gameStateProvider).value.multiplier` fallback |
| i18n regression (welcomeBack vs sessionRecap*) | Düşük | Düşük | Mevcut welcomeBack key preserved (deprecate yok) + 6 yeni key ayrı namespace |
| Test flake — `addPostFrameCallback` timing | Düşük | Düşük | `pump(Duration.zero)` postFrame fire + explicit `pump(Duration(ms: 1600))` animation complete — `pumpAndSettle` tick timer interference nedeniyle kullanılmaz |

### 5.5 Dependencies

- `multiplierChainTotalProvider` — B1 codebase varlığı plan T1'de **kesin karar**: grep + file read ile doğrula; mevcut değilse T1'e yeni provider create task step'i (derived: `Provider<double>((ref) { final gs = ref.watch(gameStateNotifierProvider).valueOrNull; if (gs == null) return 1.0; return MultiplierChain.computeTotal(gs); })`). Smoke check değil — yoksa eklenir.
- `offlineReportProvider` — B1'de tamamlandı, reuse.
- `sessionControllerProvider.currentSessionId` — B3 pattern, telemetry event enrich için.
- `telemetryLoggerProvider` — B3.
- `flutter_animate` paketi gerekli değil — TweenAnimationBuilder built-in.

### 5.6 Task estimate

**12-14 task**, writing-plans'te birleştirmeyle 10-11'e inebilir:

1. MultiplierChain provider smoke + telemetry event schema (3 subclass + TDD)
2. kActionCollect sabit + toParams unit tests
3. SessionRecapModal widget rewrite (TweenAnimationBuilder + CTA + Semantics)
4. Widget test: modal render + low-motion + CTA handlers
5. SessionRecapHost.show + _emitShown/_emitActionTaken/_emitDismissed
6. Widget test: host show sequence + backdrop dismiss post-return
7. HomePage trigger — SnackBar silinir, initState postFrame + ref.listen SessionRecapHost.show
8. Widget test: HomePage cold-start + non-Home + hot-resume
9. L10n 6 key + regen
10. [I26] one-shot + [I25] Crumbs integrity widget tests
11. Integration test: cold-start → modal → Collect → next session clean
12. CLAUDE.md §5/§12/§13 updates + docs/telemetry.md §4.7 schema güncel
13. Coverage check + CLAUDE.md §4 ek list "session recap manuel QA 7 item" tek satır inline (yeni `docs/session-recap-qa.md` YARATMA — B6 scope audio-plan.md'den dar, doc overhead gereksiz)
14. Git housekeeping (stub file cleanup, `welcomeBack` usage audit)

---

## Invariants (§6)

- **[I24] Session Recap cold-start-only + Home-route-only push:** `OfflineReport` yalnız `GameStateNotifier.build()` hydrate'te set edilir; `applyResumeDelta` hot-resume push etmez. HomePage listen + initState push sites. Non-Home route mount'ta modal görünmez; Home'a navigate'te yakalanır.
- **[I25] Earned Crumbs ledger independent of modal CTA:** `state.inventory.r1Crumbs` hydrate'te artırılır. Collect vs Dismiss — aynı Crumbs ledger. Modal presentation + telemetry branch fark.
- **[I26] One-shot modal — `clear()` sole guard:** `offlineReportProvider.clear()` hem Collect hem Dismiss path'inde. Local `_modalShown` bool YOK. Riverpod `ref.listen` fireImmediately=false garantili (3.1+).

---

## Verification (spec-level)

- **Placeholder scan:** Yok — tüm kararlar §5.3'te 14 resolved decision ile kilitli.
- **Internal consistency:** `resourceEarnedOffline: int` §2.4 + §5.3 #10 + docs/telemetry.md §4.7 güncel. `kActionCollect` §2.4 + §5.3 #12 + §6 task T1/T2 tutarlı. `showGeneralDialog` §2.2 + §5.3 #7 + §5.4 risk paralel.
- **Scope:** Tek sprint için odaklı — 12-14 task, yeni alt-subsystem yok (modal + host + telemetry expansion + HomePage integration).
- **Ambiguity:** Yok — trigger dual-gate (initState + listen) explicit, `_modalShown` removal explicit, barrier dismiss defense explicit.

---

## Next Steps

1. Spec commit: `docs(b6-spec): sprint B6 session recap modal design`
2. User review — bu spec'i oku, değişiklik/ekleme gerekirse belirt
3. Onay geldikten sonra `superpowers:writing-plans` skill → implementation plan yazılır
4. Plan onaylanırsa branch `sprint/b6-session-recap` açılır, subagent-driven development başlar (sonraki session)
