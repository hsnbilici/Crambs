# Sprint B2 — Tutorial + Telemetry + A11y Audit Design

**Hedef:** FR-3 3-step tutorial overlay, stub-first telemetry pipeline (TelemetryLogger interface + DebugLogger impl + 5 events), 48dp accessibility audit ve install_id kararlılık katmanı. Firebase Analytics aktivasyonu kapsam dışı (B3).

**Sonraki:** Sprint B3 (Firebase Analytics provider wiring + Crashlytics + install_id_age_ms + Settings Tutorial replay). Sprint C (R2 Research Shards + 3 bina daha).

**Tarih:** 2026-04-17
**Referans:** `cookie_clicker_derivative_prd.md §6.4 (FR-3), §11 (telemetry)`, `docs/ux-flows.md §6`, `docs/telemetry.md`, `CLAUDE.md §6, §7, §12`

---

## 1. Kapsam

### 1.1 In Scope (B2)

- **FR-3 3-step tutorial overlay:**
  - Step 1: "Kek'e dokun" — HomePage'de cupcake üzerinde pulse halo + ilk tap'te advance
  - Step 2: Route-aware çift aşama:
    - HomePage görünürken: BottomNav "Dükkân" item'ı üzerinde callout
    - ShopPage'e geçiş sonrası: ilk building row (crumb_collector) üzerinde halo + ilk satın alma tap'ı ile advance
  - Step 3: ShopPage'de bottom-sheet "Neden Crumb kazanıyorsun?" — info card + "Anladım" CTA ile close
  - **Tek seferlik flow:** cold start'ta `firstLaunchMarked == false` ise başlar; tutorialCompleted=true yazıldıktan sonra asla tekrar tetiklenmez
  - **Skip = all-or-nothing:** Step 1'de global "Geç" action → tüm tutorial atla, completed=true
- **TutorialState provider** (SharedPreferences-backed):
  - `firstLaunchMarked: bool` — app ilk kez başlatıldı mı
  - `tutorialCompleted: bool` — tutorial bitirildi mi (skip dahil)
  - `currentStep: TutorialStep?` — aktif step (session boyunca, disk'e yazılmaz)
- **Telemetry stub pipeline:**
  - `TelemetryLogger` abstract interface (log/beginSession/endSession)
  - `DebugLogger` impl — `debugPrint('[TELEMETRY] {eventName} {payload}')`
  - 5 event: `AppInstall`, `SessionStart`, `SessionEnd`, `TutorialStarted`, `TutorialCompleted`
  - `SessionController` — lifecycle-driven session tracking (AppLifecycleGate entegre)
- **InstallId stabilization:**
  - Separate `installIdProvider` (Notifier<String?>) — SharedPreferences-backed, `_prefKey='crumbs.install_id'`
  - Boot sequence'ta `ensureLoaded()` → `adoptFromGameState(savedInstallId)` (disk-wins reconciliation)
  - Telemetry payload'lara `install_id` GameState'ten değil bu provider'dan okunur (boot race önlenir)
- **48dp accessibility audit** (manuel):
  - HomePage cupcake tap target (şu an ~96dp, OK)
  - BottomNav item'ları (builtin 48dp, OK)
  - ShopPage "Satın al" button (audit + gerekirse padding artırımı)
  - UpgradesPage "Satın al" button (aynı)
  - "Tekrar dene" ErrorScreen button (aynı)
  - Welcome back / snackbar dismissable (gesture OK)
  - Tutorial "Geç" + "Anladım" button'ları (48dp garanti)
- **AppLifecycleGate entegrasyon:** `SessionController.onResume/onPause` çağrıları mevcut `ref.read(gameStateNotifierProvider.notifier).applyResumeDelta`/`persistNow` yanında çalışır; persist > session end sırası korunur

### 1.2 Out of Scope (B2)

- Firebase Analytics provider implementation (TelemetryLogger impl) → B3
- Crashlytics integration → B3
- Settings "Tutorial'i tekrar oyna" toggle → B3
- `install_id_age_ms` payload property (B2'de drop edildi; creation timestamp persistence B3'te) → B3
- Tutorial Step 4+ (prestige, research overview) → post-MVP
- Tutorial i18n ötesi — TR-only string (tr.arb) → post-MVP
- Purchase/Upgrade/Error event'leri → B3 (telemetry event kataloğu genişlemesi)
- Tutorial animation micro-interactions (flutter_animate chain'leri — sade pulse ve fade yeterli)
- Accessibility automation (screen reader contract, semantic label audit) → Sprint D
- Playtest feedback-driven balans tuning → post-MVP

### 1.3 Design assumptions

- B1 PR #3 merge sonrası B2 branch'i `main`'den çıkar (`sprint/b2-tutorial-telemetry`). Ara branch bağımlılığı yok.
- Telemetry'nin Firebase aktivasyonu B3'e bırakılır çünkü (a) stub interface production shape'i sabitler, (b) provider swap tek-task (1 file) olur, (c) dashboard/funnel setup ayrı runbook gerektirir.
- `install_id` zaten `GameState.meta.installId`'da Sprint A'dan beri var. B2'de disk-wins reconciliation eklenir — ikili kaynak senkronize edilir.
- OnboardingPrefs (Sprint A'dan firstLaunchMarked) **TutorialState ile ayrı tutulur**. OnboardingPrefs bir kez yazılır (boot); TutorialState aktif session'da mutate edilir. Tek provider'a birleştirmek testing/concurrency karmaşıklığı yaratır.
- A11y audit **manuel**: koordinasyon + ölçüm değeri test automation'dan yüksek (5-6 widget spot check yeterli, Sprint D'de genel audit).

---

## 2. Architecture

### 2.1 Yeni modüller

```
lib/core/telemetry/                       [YENİ dizin]
├── telemetry_event.dart                  [YENİ]
│     └── sealed class TelemetryEvent
│         ├── AppInstall
│         ├── SessionStart
│         ├── SessionEnd
│         ├── TutorialStarted
│         └── TutorialCompleted
├── telemetry_logger.dart                 [YENİ]
│     └── abstract class TelemetryLogger
├── debug_logger.dart                     [YENİ]
│     └── class DebugLogger implements TelemetryLogger
├── session_controller.dart               [YENİ]
│     └── class SessionController
│         ├── onLaunch()       → AppInstall (if first) + SessionStart
│         ├── onResume()       → SessionStart
│         └── onPause()        → SessionEnd
└── telemetry_providers.dart              [YENİ]
      └── telemetryLoggerProvider (Provider<TelemetryLogger>)
      └── installIdProvider (Notifier<String?>)
      └── sessionControllerProvider (Provider<SessionController>)

lib/core/tutorial/                        [YENİ dizin]
├── tutorial_step.dart                    [YENİ]
│     └── enum TutorialStep { tapCupcake, openShop, buyFirstBuilding, explainCrumbs }
│         (4 enum — Step 2 HomePage/Shop transition: openShop → buyFirstBuilding)
├── tutorial_state.dart                   [YENİ]
│     └── freezed TutorialState
│         ├── firstLaunchMarked: bool
│         ├── tutorialCompleted: bool
│         └── currentStep: TutorialStep?
├── tutorial_notifier.dart                [YENİ]
│     └── class TutorialNotifier extends Notifier<TutorialState>
│         ├── start()          → idempotent, currentStep != null ise no-op
│         ├── advance()        → re-entry guard (expected step verify)
│         ├── skip()           → all-or-nothing, completed=true
│         └── complete()       → completed=true
└── tutorial_providers.dart               [YENİ]
      └── tutorialNotifierProvider (NotifierProvider<TutorialNotifier, TutorialState>)
      └── tutorialActiveProvider (Provider<bool>) — !tutorialCompleted

lib/features/tutorial/                    [YENİ dizin]
├── tutorial_scaffold.dart                [YENİ]
│     └── class TutorialScaffold (ConsumerStatefulWidget)
│         └── initState → postFrameCallback → notifier.start() + TutorialStarted emit
│         └── build → switch(currentStep) overlay render
│         └── ref.listen<GameState>(gameStateNotifierProvider, ...)
│             → Step 1 advance trigger (totalTaps delta),
│             → Step 2 advance trigger (first building purchase)
├── widgets/
│   ├── coach_mark_overlay.dart           [YENİ]
│   │     └── CoachMarkOverlay (StatefulWidget)
│   │         ├── targetKey: GlobalKey
│   │         ├── message: String
│   │         ├── shape: HaloShape { rectangle, circle }
│   │         ├── onSkip: VoidCallback?
│   │         └── initState → postFrameCallback → geometry resolve
│   │         └── LayoutBuilder → clamp to safe area
│   ├── info_card_overlay.dart            [YENİ]
│   │     └── Step 3 bottom-sheet
│   └── bottom_nav_callout.dart           [YENİ]
│         └── Step 2 HomePage aşaması (BottomNav "Dükkân" üstünde)
└── keys.dart                             [YENİ]
      └── kTutorialCupcakeKey (HomePage cupcake)
      └── kTutorialShopNavKey (BottomNav "Dükkân" item)
      └── kTutorialShopFirstRowKey (ShopPage first BuildingRow)
```

### 2.2 Değişen modüller

```
lib/app/boot/
└── app_bootstrap.dart                    [modified]
      ├── installIdProvider.ensureLoaded() eklenir
      ├── adoptFromGameState(gs.meta.installId) eklenir
      └── sessionController.onLaunch() çağrısı eklenir

lib/app/lifecycle/
└── app_lifecycle_gate.dart               [modified]
      ├── onResume: sessionController.onResume() çağrısı
      └── onPause: persistNow ÖNCE → sessionController.onPause() SONRA

lib/core/state/
└── game_state_notifier.dart              [unchanged]
      (Telemetry cross-cut widget/controller katmanında; notifier saf kalır)

lib/l10n/
└── tr.arb                                [modified]
      └── 10 yeni key: tutorialStep1*, tutorialStep2Nav*, tutorialStep2Shop*,
                        tutorialStep3*, tutorialSkipButton, tutorialCloseButton

lib/features/home/home_page.dart          [modified]
      └── cupcake IconButton: key: kTutorialCupcakeKey
          (mevcut sized/padding aynı — 96dp zaten 48dp üstü)

lib/app/nav/app_navigation_bar.dart       [modified]
      └── "Dükkân" NavigationDestination: key: kTutorialShopNavKey

lib/features/shop/widgets/building_row.dart  [modified]
      └── ilk BuildingRow (crumb_collector): key: kTutorialShopFirstRowKey
          (parent passed — widget'a key parametresi eklenir)

lib/main.dart                             [modified]
      └── MaterialApp.builder: TutorialScaffold(child: child)
          → tüm route'ların üstünde overlay katmanı
```

### 2.3 Test yapısı

```
test/core/telemetry/
├── telemetry_event_test.dart             — payload shape + sealed hierarchy
├── debug_logger_test.dart                — debugPrint format + beginSession/endSession
├── session_controller_test.dart          — onLaunch/onResume/onPause sequencing
└── install_id_notifier_test.dart         — disk-wins reconciliation

test/core/tutorial/
├── tutorial_notifier_test.dart           — start/advance/skip/complete state machine
└── tutorial_state_test.dart              — freezed equality + serialization

test/features/tutorial/
├── tutorial_scaffold_test.dart           — widget test (route-aware Step 2)
├── coach_mark_overlay_test.dart          — geometry resolution + halo shape
└── tutorial_flow_integration_test.dart   — 3-step happy path + skip path

integration_test/
└── tutorial_telemetry_integration_test.dart
      └── cold start → 3 event emit → complete tutorial → SessionEnd on pause
```

---

## 3. TelemetryEvent sealed hierarchy

### 3.1 Event schema

```dart
sealed class TelemetryEvent {
  const TelemetryEvent();

  String get eventName;
  Map<String, Object?> get payload;
}

class AppInstall extends TelemetryEvent {
  const AppInstall({required this.installId, required this.platform});
  final String installId;
  final String platform; // 'ios' | 'android'

  @override
  String get eventName => 'app_install';

  @override
  Map<String, Object?> get payload => {
    'install_id': installId,
    'platform': platform,
    // Not: install_id_age_ms B2'de dropped; creation timestamp persistence B3'te.
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

### 3.2 TelemetryLogger interface

```dart
abstract class TelemetryLogger {
  void log(TelemetryEvent event);
  void beginSession(); // placeholder — Firebase'de session tracking hook'u
  void endSession();
}

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

### 3.3 InstallIdNotifier

```dart
class InstallIdNotifier extends Notifier<String?> {
  static const _prefKey = 'crumbs.install_id';
  static const kNotLoadedSentinel = '<not-loaded>';

  @override
  String? build() => null;

  /// Called on cold start BEFORE session telemetry emits.
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefKey);
  }

  /// Called after GameState hydration — disk wins.
  Future<void> adoptFromGameState(String savedInstallId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKey);
    if (existing != savedInstallId) {
      await prefs.setString(_prefKey, savedInstallId);
    }
    state = savedInstallId;
  }
}

/// Telemetry invariant guard: telemetry payload hazırlanırken null olursa
/// bu sentinel kullanılır. Integration test bu değeri production emission'da
/// görürse fail eder.
String resolveInstallIdForTelemetry(Ref ref) {
  return ref.read(installIdProvider) ?? InstallIdNotifier.kNotLoadedSentinel;
}
```

### 3.4 SessionController

```dart
class SessionController {
  SessionController(this._ref);
  final Ref _ref;

  String? _currentSessionId;
  DateTime? _sessionStartedAt;

  TelemetryLogger get _logger => _ref.read(telemetryLoggerProvider);

  void onLaunch({required bool firstLaunchMarkedBefore}) {
    final installId = resolveInstallIdForTelemetry(_ref);
    if (!firstLaunchMarkedBefore) {
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
```

---

## 4. TutorialState + UI

### 4.1 State machine

```
TutorialStep enum:
  tapCupcake        (Step 1)
  openShop          (Step 2a — HomePage'de BottomNav callout)
  buyFirstBuilding  (Step 2b — ShopPage'e geçti, first row halo)
  explainCrumbs     (Step 3 — bottom-sheet info card)

Transitions:
  (null, !completed) --[TutorialScaffold.postFrame + !firstLaunchMarked]--> tapCupcake
  tapCupcake        --[GameState.run.totalTaps delta > 0]-->                openShop
  openShop          --[GoRouter.matchedLocation == '/shop']-->              buyFirstBuilding
  buyFirstBuilding  --[GameState.buildings.owned['crumb_collector'] > 0]--> explainCrumbs
  explainCrumbs     --["Anladım" CTA]-->                                    (null, completed=true)
  <any step>        --["Geç" CTA in Step 1 overlay]-->                      (null, completed=true, skipped=true)
```

### 4.2 TutorialNotifier

```dart
class TutorialNotifier extends Notifier<TutorialState> {
  static const _prefKeyFirstLaunch = 'crumbs.first_launch_marked';
  static const _prefKeyCompleted = 'crumbs.tutorial_completed';

  @override
  TutorialState build() {
    // Synchronous build returns a "loading" default; hydrate() called from boot.
    return const TutorialState(
      firstLaunchMarked: false,
      tutorialCompleted: false,
      currentStep: null,
    );
  }

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      firstLaunchMarked: prefs.getBool(_prefKeyFirstLaunch) ?? false,
      tutorialCompleted: prefs.getBool(_prefKeyCompleted) ?? false,
    );
  }

  /// Idempotent. Called from TutorialScaffold postFrameCallback.
  /// No-op if tutorial already active, completed, or not first launch.
  Future<void> start() async {
    if (state.tutorialCompleted || state.currentStep != null) return;
    if (state.firstLaunchMarked) return;

    state = state.copyWith(currentStep: TutorialStep.tapCupcake);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyFirstLaunch, true);
    state = state.copyWith(firstLaunchMarked: true);
    // TutorialStarted event emit edilir caller (TutorialScaffold) tarafından.
  }

  /// Re-entry guard: only advances if currentStep == expected.
  void advance({required TutorialStep from}) {
    if (state.currentStep != from) return;
    final next = _nextStep(from);
    state = state.copyWith(currentStep: next);
  }

  Future<void> skip() async {
    await _markCompleted();
    // TutorialCompleted(skipped: true) emit edilir caller tarafından.
  }

  Future<void> complete() async {
    await _markCompleted();
    // TutorialCompleted(skipped: false) emit edilir caller tarafından.
  }

  Future<void> _markCompleted() async {
    state = state.copyWith(tutorialCompleted: true, currentStep: null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyCompleted, true);
  }

  TutorialStep? _nextStep(TutorialStep current) {
    return switch (current) {
      TutorialStep.tapCupcake => TutorialStep.openShop,
      TutorialStep.openShop => TutorialStep.buyFirstBuilding,
      TutorialStep.buyFirstBuilding => TutorialStep.explainCrumbs,
      TutorialStep.explainCrumbs => null,
    };
  }
}
```

### 4.3 CoachMarkOverlay (StatefulWidget pattern)

```dart
enum HaloShape { rectangle, circle }

class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    required this.targetKey,
    required this.message,
    this.shape = HaloShape.rectangle,
    this.onSkip,
    super.key,
  });

  final GlobalKey targetKey;
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

    return LayoutBuilder(builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final safeRect = Rect.fromLTWH(
        media.padding.left,
        media.padding.top,
        constraints.maxWidth - media.padding.horizontal,
        constraints.maxHeight - media.padding.vertical,
      );
      final clamped = Rect.fromLTWH(
        topLeft.dx.clamp(safeRect.left, safeRect.right - size.width).toDouble(),
        topLeft.dy.clamp(safeRect.top, safeRect.bottom - size.height).toDouble(),
        size.width,
        size.height,
      );
      return Stack(children: [
        ModalBarrier(color: Colors.black54, dismissible: false),
        Positioned.fromRect(
          rect: clamped.inflate(12),
          child: _PulseHalo(shape: widget.shape),
        ),
        _MessageCallout(rect: clamped, message: widget.message, onSkip: widget.onSkip),
      ]);
    });
  }
}
```

### 4.4 TutorialScaffold (route-aware Step 2)

```dart
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
      _startInvoked = true;
      final notifier = ref.read(tutorialNotifierProvider.notifier);
      await notifier.hydrate();
      await notifier.start();
      final postState = ref.read(tutorialNotifierProvider);
      if (postState.currentStep == TutorialStep.tapCupcake) {
        _startedAt = DateTime.now();
        final installId = resolveInstallIdForTelemetry(ref);
        ref.read(telemetryLoggerProvider).log(
          TutorialStarted(installId: installId),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialNotifierProvider);

    // Step 1 advance trigger: cupcake tap (totalTaps delta)
    ref.listen<AsyncValue<GameState>>(gameStateNotifierProvider, (prev, next) {
      final step = tutorialState.currentStep;
      if (step == null) return;
      final prevTaps = prev?.value?.run.totalTaps ?? 0;
      final nextTaps = next.value?.run.totalTaps ?? 0;
      if (step == TutorialStep.tapCupcake && nextTaps > prevTaps) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
      // Step 2b advance trigger: first building purchase
      final prevOwned = prev?.value?.buildings.owned['crumb_collector'] ?? 0;
      final nextOwned = next.value?.buildings.owned['crumb_collector'] ?? 0;
      if (step == TutorialStep.buyFirstBuilding && nextOwned > prevOwned) {
        ref.read(tutorialNotifierProvider.notifier).advance(from: step);
      }
    });

    return Stack(children: [
      widget.child,
      if (tutorialState.currentStep != null) _buildOverlay(tutorialState.currentStep!),
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
      TutorialStep.openShop => _buildStep2Overlay(notifier, s),
      TutorialStep.buyFirstBuilding => _buildStep2Overlay(notifier, s),
      TutorialStep.explainCrumbs => InfoCardOverlay(
        title: s.tutorialStep3Title,
        body: s.tutorialStep3Body,
        ctaLabel: s.tutorialCloseButton,
        onClose: () => _onCompletePressed(notifier),
      ),
    };
  }

  Widget _buildStep2Overlay(TutorialNotifier notifier, AppStrings s) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/shop') {
      return CoachMarkOverlay(
        targetKey: kTutorialShopFirstRowKey,
        message: s.tutorialStep2ShopMessage,
        shape: HaloShape.rectangle,
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
    ref.read(telemetryLoggerProvider).log(TutorialCompleted(
      installId: resolveInstallIdForTelemetry(ref),
      skipped: skipped,
      durationMs: duration.inMilliseconds,
    ));
  }
}
```

---

## 5. A11y audit checklist (48dp minimum tap target)

| Widget | Konum | Mevcut boy | Action |
|---|---|---|---|
| Cupcake IconButton | HomePage | ~96dp (visual) | Verify → OK |
| BottomNav items | AppNavigationBar | Flutter default 48dp | Verify → OK |
| "Satın al" button (Shop) | BuildingRow | FilledButton.min ~40dp | **Fix:** min 48dp wrap |
| "Satın al" button (Upgrades) | UpgradeRow | Aynı | **Fix:** min 48dp wrap |
| "Tekrar dene" button | ErrorScreen | FilledButton default | Verify → check |
| "Geç" button | Tutorial Step 1 | TextButton | **Fix:** 48dp explicit |
| "Anladım" button | Tutorial Step 3 | FilledButton | Verify → OK |
| Snackbar dismiss | Welcome back | Gesture | OK (N/A) |

**Fix pattern:**
```dart
// Before
FilledButton(onPressed: ..., child: Text('Satın al'))

// After
SizedBox(
  height: 48,
  child: FilledButton(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: ...,
    child: Text('Satın al'),
  ),
)
```

**Validation:** `flutter test` widget boy ölçümü golden snapshot veya `tester.getSize(find.byType(FilledButton))` assertion (3 call site için smoke test).

---

## 6. Lifecycle ordering contract

Bu sözleşme `AppLifecycleGate` + `SessionController` + `GameStateNotifier` entegrasyonunu deterministik tutar. İhlali invariant test tetikler.

### 6.1 onLaunch (cold start)

```
1. AppBootstrap.initialize
   a. ProviderContainer kurulumu
   b. await container.read(installIdProvider.notifier).ensureLoaded()
      → SharedPreferences'tan install_id okundu (veya null)
   c. await container.read(gameStateNotifierProvider.future)
      → GameState hydrate edildi (save load + migration + default)
   d. await container.read(installIdProvider.notifier)
        .adoptFromGameState(gs.meta.installId)
      → Disk-wins: GameState.meta.installId SharedPreferences'a yazılır (eğer farklıysa)
      → state = savedInstallId
   e. await container.read(tutorialNotifierProvider.notifier).hydrate()
      → SharedPreferences'tan firstLaunchMarked + tutorialCompleted okundu

2. firstLaunchMarked değerini hydrate sonrası, start() öncesi capture et:
   final tutorialState = container.read(tutorialNotifierProvider);
   final firstLaunchBefore = !tutorialState.firstLaunchMarked;
   (Not: TutorialNotifier.start() henüz çağrılmadı — step 4'te TutorialScaffold
    postFrameCallback'i firstLaunchMarked=true olarak flip edecek.)

3. container.read(sessionControllerProvider).onLaunch(
     firstLaunchMarkedBefore: firstLaunchBefore,
   )
   → if (firstLaunchBefore) AppInstall event
   → SessionStart event (her zaman)

4. runApp(ProviderScope(...))
   → MaterialApp.builder içinde TutorialScaffold mount
   → postFrameCallback → tutorial notifier.start()
     (eğer !firstLaunchMarked ise currentStep=tapCupcake + TutorialStarted emit)
```

### 6.2 onResume (hot resume)

```
AppLifecycleListener.onResume:
1. ref.read(sessionControllerProvider).onResume()
   → Yeni session_id + SessionStart event
2. ref.read(gameStateNotifierProvider.notifier).applyResumeDelta()
   → Offline delta hesapla, state güncelle (sessiz — offlineReportProvider'ı push etmez)
3. (tick clock reset mevcut AppLifecycleGate'te)
```

### 6.3 onPause

```
AppLifecycleListener.onPause:
1. await ref.read(gameStateNotifierProvider.notifier).persistNow()
   → Disk'e commit (save race lock korunur)
2. ref.read(sessionControllerProvider).onPause()
   → SessionEnd event + endSession

Sıra kritik: persist ÖNCE, telemetry SONRA.
Gerekçe: pause sırasında süreç öldürülürse persist garanti edilmiş olmalı; telemetry kayıp kabul edilebilir.
```

### 6.4 Invariant tests

1. **installId-never-null:** Session events (SessionStart/SessionEnd) payload'unda `install_id != null`. `<not-loaded>` sentinel'ı production emission'da görünürse fail.
2. **tutorialStarted-emit-contract:** TutorialScaffold mount + !firstLaunchMarked → exactly 1 TutorialStarted event per cold start.
3. **onPause-order:** SessionEnd event'i `persistNow()` future'ı resolve olduktan sonra emit edilir.
4. **no-double-session:** onResume iki kez çağrılırsa (unlikely ama test edilir) ikinci çağrı yeni session_id başlatır, mevcut unclosed session'ı kapatır (defansif kontrat).
5. **tutorial-idempotent-start:** `start()` iki kez çağrılırsa state mutate olmaz, TutorialStarted bir kez emit edilir (TutorialScaffold startInvoked guard).

---

## 7. Invariants & DoD

### 7.1 Invariants (regression test mandatory)

- **[I1]** Telemetry payload'larında `install_id` hiçbir zaman null olmaz; null olursa `<not-loaded>` sentinel görünür (test bu sentinel'ı production'da reddeder)
- **[I2]** Tutorial `currentStep` disk'e yazılmaz (session-only)
- **[I3]** `tutorialCompleted=true` yazıldıktan sonra `currentStep` tekrar non-null olmaz (provider invalidate hariç)
- **[I4]** `start()` idempotent: aynı session'da iki kez çağrılırsa ikinci çağrı no-op
- **[I5]** `advance(from: X)` re-entry guard: `currentStep != X` ise no-op (race condition'a karşı)
- **[I6]** onPause sıra: persist > telemetry
- **[I7]** Chain 3-site invariant B1'den korunur (Sprint B2 değişikliği yok)
- **[I8]** OfflineReport push kuralı B1'den korunur (cold start only)
- **[I9]** `installIdProvider` ve `GameState.meta.installId` boot sonrası aynı değeri taşır (disk-wins)
- **[I10]** `flutter_riverpod` `NotifierProvider` pattern B1'den devralınır; `StateProvider` eklenmez

### 7.2 Definition of Done

- [ ] `flutter analyze` clean (0 error, 0 warning)
- [ ] `flutter test` 100% pass (target: +20-25 yeni test, ~155-160 toplam)
- [ ] Integration test (tutorial_telemetry) geçer
- [ ] Invariants [I1]-[I10] regression test dosyalarında assert edilir
- [ ] `<not-loaded>` sentinel production emission'da görülürse integration test fail eder
- [ ] `docs/telemetry.md` 5 event şemasıyla güncellenir
- [ ] `docs/ux-flows.md §6` tutorial flow güncellenir (route-aware Step 2)
- [ ] `CLAUDE.md §12` tutorial/telemetry gotcha'ları eklenir (postFrame start, disk-wins installId, pause-sıra)
- [ ] Coverage gate: yeni modüller ≥85% (telemetry + tutorial)
- [ ] Manuel a11y audit: 8 widget (bölüm 5 tablo) spot check raporu PR description'da

---

## 8. Testing strategy

### 8.1 Unit

- `TelemetryEvent` sealed hierarchy payload shape
- `DebugLogger` debugPrint format (overridePrint)
- `SessionController` onLaunch/onResume/onPause sequencing — mock TelemetryLogger + fake Ref
- `InstallIdNotifier` disk-wins reconciliation (3 senaryo: disk empty, disk matches GameState, disk differs from GameState)
- `TutorialNotifier` state machine:
  - start() idempotent + no-op if completed
  - advance(from:) re-entry guard
  - skip() → completed=true + currentStep=null
  - complete() → completed=true + currentStep=null

### 8.2 Widget

- `CoachMarkOverlay`:
  - Targetkey resolve postFrame sonrası SetState tetikler
  - Mount olurken target henüz tree'de değilse SizedBox.shrink render eder
  - LayoutBuilder safe area clamp (edge case: target near screen edge)
  - Circle vs rectangle shape render farkı (golden)
- `TutorialScaffold`:
  - Route == '/' + Step 2 → BottomNavCallout
  - Route == '/shop' + Step 2 → CoachMarkOverlay on first row
  - Step 1 → cupcake halo + skip button
  - Step 3 → InfoCardOverlay

### 8.3 Integration

`tutorial_telemetry_integration_test.dart`:
1. Cold start (first launch) → AppInstall + SessionStart + TutorialStarted events
2. Cupcake tap → Step 1 → Step 2 (Home)
3. Tap BottomNav "Dükkân" → Step 2 (Shop) → halo visible on first row
4. Tap "Satın al" → Step 2 → Step 3 (info card)
5. Tap "Anladım" → TutorialCompleted(skipped: false) event
6. Second cold start → no TutorialStarted event (firstLaunchMarked=true)
7. Invariant: all 5 events carry non-null install_id and non-sentinel value

### 8.4 Manual

A11y audit checklist (bölüm 5) — screenshot comparison + TalkBack/VoiceOver spot check (optional, B3 Sprint D kapsamında genişler).

---

## 9. Task decomposition (17 task)

Etiketler: **(S)** subagent-driven TDD strict, **(C)** controller-direct, **★** critical.

### Phase 1 — Telemetry foundation (T1-T5)

| # | Task | Mode | Critical |
|---|---|---|---|
| T1 | `TelemetryEvent` sealed hierarchy + unit test | S | |
| T2 | `TelemetryLogger` abstract + `DebugLogger` impl + unit test | S | |
| T3 | `InstallIdNotifier` + disk-wins reconciliation + unit test | S | ★ |
| T4 | `SessionController` + lifecycle sequencing + unit test | S | ★ |
| T5 | `telemetry_providers.dart` + wiring to ProviderContainer | C | |

### Phase 2 — Tutorial state (T6-T8)

| # | Task | Mode | Critical |
|---|---|---|---|
| T6 | `TutorialStep` enum + `TutorialState` freezed + codegen | C | |
| T7 | `TutorialNotifier` state machine + invariant tests | S | ★ |
| T8 | `tutorial_providers.dart` + `tutorialActiveProvider` derived | C | |

### Phase 3 — Tutorial UI widgets (T9-T12)

| # | Task | Mode | Critical |
|---|---|---|---|
| T9 | `CoachMarkOverlay` StatefulWidget + postFrame + LayoutBuilder + test | S | ★ |
| T10 | `BottomNavCallout` widget + test | S | |
| T11 | `InfoCardOverlay` widget + test | S | |
| T12 | `tr.arb` 10 yeni key + AppStrings regen | C | |

### Phase 4 — Integration (T13-T15)

| # | Task | Mode | Critical |
|---|---|---|---|
| T13 | `TutorialScaffold` route-aware + ref.listen advance triggers + test | S | ★ |
| T14 | GlobalKey injection (HomePage, BottomNav, ShopPage first row) + `main.dart` scaffold mount | C | ★ |
| T15 | `AppBootstrap` + `AppLifecycleGate` SessionController integration | S | ★ |

### Phase 5 — A11y + docs + gates (T16-T17)

| # | Task | Mode | Critical |
|---|---|---|---|
| T16 | A11y 48dp audit fixes (3 widget wrap) + widget smoke test | C | |
| T17 | Integration test (tutorial_telemetry) + docs updates (telemetry.md + ux-flows.md + CLAUDE.md §12) | S | ★ |

**Subagent-driven (11):** T1, T2, T3, T4, T7, T9, T10, T11, T13, T15, T17
**Controller-direct (6):** T5, T6, T8, T12, T14, T16
**Critical (★, 8):** T3, T4, T7, T9, T13, T14, T15, T17

---

## 10. Dependency chain

```
T1 (TelemetryEvent)
   └→ T2 (DebugLogger)  ─────────────┐
                                      ↓
T3 (InstallIdNotifier) ──────────→ T4 (SessionController) → T5 (telemetry_providers)
                                                                      ↓
T6 (TutorialStep+State) → T7 (TutorialNotifier) → T8 (tutorial_providers)
                                                         ↓
                                                   T9, T10, T11 (UI widgets, parallel-OK)
                                                         ↓
T12 (tr.arb) ───────────────────────────────────────→ T13 (TutorialScaffold)
                                                         ↓
                                                   T14 (GlobalKey injection + main.dart)
                                                         ↓
                                                   T15 (AppBootstrap + AppLifecycleGate)
                                                         ↓
                                                   T16 (A11y fixes)
                                                         ↓
                                                   T17 (integration test + docs)
```

**Paralel subagent kuralı:** Subagent-driven akışta tek seferde **bir** task dispatch edilir (context pollution yok). T9/T10/T11 arka arkaya sıralı çalıştırılır; paralel dispatch edilmez.

**Sıralama notu:** T12 (l10n) T13'ten ÖNCE gerekli çünkü TutorialScaffold `AppStrings.of(context)!.tutorialStep1Message` erişir. T14 T13 sonrası çünkü TutorialScaffold'un mount edileceği entry point (`MaterialApp.builder`) T14'te bağlanır.

---

## 11. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| CoachMarkOverlay target widget unmount (orientation change) | Overlay stale/invisible | `didUpdateWidget` + key re-resolve; LayoutBuilder rebuild |
| Step 2 route transition before user taps "Dükkân" | Overlay stranded mid-state | `_buildStep2Overlay` route-aware branch (HomePage nav callout visible until navigation) |
| `install_id` SharedPreferences ile GameState drift | Dashboard cohort split | Disk-wins reconciliation (boot step 1d); tek kaynak (installIdProvider) telemetry'de |
| Provider invalidate / hot reload'da `TutorialStarted` tekrar emit | Dashboard double-count | `TutorialScaffold._startInvoked` guard + `start()` idempotent |
| AppLifecycleGate onPause çağrısı persist'ten önce SessionEnd atarsa | Pause sırasında kaybolan save | Ordering contract §6.3 + integration test assertion |
| A11y fix wrap'ları mevcut visual density bozarsa | UI regresyon | 48dp wrap yalnız button'lara (text/chip dokunulmaz); golden test spot check |
| TelemetryLogger stub'ı test environment'ta debugPrint flood eder | Log noise | Testte `ProviderScope(overrides: [telemetryLoggerProvider.overrideWithValue(FakeLogger())])` |

---

## 12. Rollback plan

B2 PR merge sonrası herhangi bir kritik regresyon çıkarsa:
1. `git revert <merge-commit>` tek komut
2. Tutorial altyapısı cold start'ta gizlenir (provider'lar tanımlı kalır; UI katmanı overlay çizmez)
3. Telemetry events sessiz debugPrint olarak devam eder (Firebase yokluğu zaten kabul edildi, B3)
4. InstallId reconciliation geri alınırsa GameState.meta.installId'e geri döner (önceki davranış)

Kritik regresyon olmasa bile: B3'e kadar tutorial completed=true olan kullanıcılar için tutorial replay yoktur (Settings toggle B3'te eklenir).

---

## 13. Followups (B3 backlog)

- [ ] Firebase Analytics provider implementation (TelemetryLogger impl) — tek dosya swap
- [ ] Crashlytics integration (onError handler + recordFatal)
- [ ] `install_id_age_ms` payload property — install creation timestamp persistence ekle
- [ ] Settings → "Tutorial'i tekrar oyna" toggle (TutorialNotifier.reset())
- [ ] Purchase/Upgrade/ResearchComplete event'leri (telemetry event kataloğu genişlemesi)
- [ ] A11y screen reader contract audit (Semantic labels) — Sprint D
- [ ] Tutorial Step 4+ (Prestige, Research intro) — post-MVP
- [ ] Sentry alternatif evaluation (Crashlytics vs Sentry tradeoff) — post-MVP

---

## 14. Referans

- `cookie_clicker_derivative_prd.md §6.4, §11`
- `docs/ux-flows.md §6`
- `docs/telemetry.md`
- `CLAUDE.md §6, §7, §12`
- Sprint B1 spec: `docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md`
- Sprint A spec: `docs/superpowers/specs/2026-04-17-sprint-a-vertical-slice-design.md`
