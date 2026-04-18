# Sprint B5 — Audio Layer Design

**Tarih:** 2026-04-19
**Durum:** Design freeze — writing-plans stage'ine hazır
**Branch (hedef):** `sprint/b5-audio-layer` (henüz açılmadı; plan yazımı sonrası)
**Kaynak:** Brainstorming oturumu (B4 merge + simulator deploy sonrası), `docs/superpowers/backlog/sprint-b3-backlog.md` §1, `docs/visual-design.md` (Living Oven kararı), PRD §6/§7/§8.

---

## Goal

Crumbs'ın şu anda **sessiz** olan oyun döngüsüne temel audio katmanı eklemek: 4 SFX cue + 1 ambient loop + Settings toggle'ları gerçeği + prefs persistence + platform parity. Engine-first yaklaşımı; asset kalitesi B5 sonrası paralel swap task'ı.

**Değer:** Living Oven görsel kimliği kararından sonra brand deneyiminin ikinci ayağı. "Fırına dokun" ses üretmezse Living Oven vaadi yarım; tap'e haptic + görsel + ses üçlüsü bakery empire'i hissettirir. Mevcut Settings'teki `onChanged: null` stub toggle'lar B5'te gerçek işlev kazanır.

---

## Architecture (§1)

### Module layout

```
lib/core/audio/
  audio_engine.dart               # AudioEngine interface + AudioplayersEngine impl
  audio_settings.dart             # AudioSettings @immutable model
  audio_settings_notifier.dart    # AsyncNotifier<AudioSettings>, prefs-backed
  sfx_catalog.dart                # SfxCue enum + asset path map
  audio_controller.dart           # Plain class, engine + settings snapshot bridge
```

### Provider graph

| Provider | Tip | Lifecycle |
|---|---|---|
| `audioEngineProvider` | `Provider<AudioEngine>` | App lifetime; `ref.onDispose(() => engine.dispose())` explicit cleanup |
| `audioSettingsProvider` | `AsyncNotifierProvider<AudioSettingsNotifier, AudioSettings>` | App lifetime; prefs-hydrated |
| `audioControllerProvider` | `Provider<AudioController>` | App lifetime; `ref.listen(audioSettingsProvider)` ile snapshot güncellenir |

**Provider listen pattern (A — kabul edilen):**

```dart
final audioControllerProvider = Provider<AudioController>((ref) {
  final engine = ref.watch(audioEngineProvider);
  final initial = ref.read(audioSettingsProvider).value ??
      const AudioSettings.defaults();
  final ctrl = AudioController(engine, initial);
  ref.listen<AsyncValue<AudioSettings>>(audioSettingsProvider, (prev, next) {
    final n = next.value;
    if (n != null) ctrl.updateSettings(n);
  });
  return ctrl;
});
```

### Integration points

- `main.dart` — lazy init via `Future.microtask(() => engine.init())` runApp sonrası, fire-and-forget. Cold start'a 200-500ms bindirme yok.
- `AppLifecycleGate` — `onPause` / `onResume` yeni audio hook'ları (bkz §3.2)
- `TapArea` — mevcut 80ms haptic throttle gate'i SFX'e de kapsar (bkz §3.3)
- Shop buy, Upgrade buy, Tutorial advance — tek satır `playCue` eklemesi
- `AudioSettingsSection` — stub switch'ler gerçek notifier'a bağlanır + master volume slider eklenir

### Isolation contract

AudioEngine arayüzü `playOneShot(path)` / `startLoop(path)` seviyesinde — `audioplayers` bağımlılığı impl'e gömülü. Test katmanı `FakeAudioEngine` (mocktail) ile sinyal-seviye doğrular; audioplayers'ın native davranışı unit testte test edilmez.

---

## Components & Contracts (§2)

### 2.1 AudioEngine (interface)

```dart
abstract interface class AudioEngine {
  Future<void> init();                    // AVAudioSession Ambient config + AudioPool pre-warm (paralel)
  Future<void> playOneShot(String assetPath, {double volume});
  Future<void> startLoop(String assetPath, {double volume});
  Future<void> stopLoop();
  Future<void> pauseLoop();
  Future<void> resumeLoop();
  Future<void> setLoopVolume(double v);
  Future<void> dispose();                 // release all player instances
}
```

**Impl (`AudioplayersEngine`):**
- SFX: `audioplayers` 6.x `AudioPool` (her cue için ayrı pool); rapid tap overlap için polyphonic
- Ambient: tek `AudioPlayer` instance, `ReleaseMode.loop`
- iOS: `AudioContextConfig(category: AVAudioSessionCategory.ambient)` — silent switch respect, diğer müzikle mix
- Android: `STREAM_MUSIC` default (platform convention)
- Init AudioPool warm paralel: `await Future.wait([for (final cue in SfxCue.values) _initPool(cue)])`
- Dispose: tüm pool'lar + ambient release, idempotent

**Init race guard — `_initCompleter` pattern:**

Lazy `Future.microtask(engine.init())` runApp sonrası non-blocking başlar. Kullanıcı <500ms içinde Settings'e girip music toggle'ı açarsa, `audioControllerProvider.startAmbient()` init tamamlanmadan çağrılabilir. Her public metod init completer'ı await eder — race'siz, cold start latency değişmez.

```dart
class AudioplayersEngine implements AudioEngine {
  Completer<void>? _initCompleter;
  bool _failed = false;
  bool _disposed = false;

  @override
  Future<void> init() {
    _initCompleter ??= Completer<void>();
    _bootstrap().then(
      (_) => _initCompleter!.complete(),
      onError: (e, st) {
        _failed = true;
        _initCompleter!.complete();  // complete even on failure so awaiters proceed
        debugPrint('AudioEngine init failed: $e');
      },
    );
    return _initCompleter!.future;
  }

  @override
  Future<void> playOneShot(String path, {double volume = 1.0}) async {
    await _initCompleter?.future;   // wait if init in-flight
    if (_failed || _disposed) return;  // silent no-op
    // ... actual play
  }
  // startLoop, resumeLoop, setLoopVolume — aynı pattern
}
```

**Failure sentinel — kararlaştırıldı:**
- init fail → `_failed = true` → tüm play metodları silent no-op (throw etmez)
- dispose sonrası play → `_disposed = true` → silent no-op (DisposedEngineException atılmaz)
- Gerekçe: B3 `FirebaseBootstrap.isInitialized` pattern'iyle paralel; gameplay etkilenmez, test edilebilir, production error log kirliliği yok. Invariant [I21].

### 2.2 AudioController

**Plain class (Notifier değil); Riverpod provider kapsamında `ref.listen` ile snapshot güncellenir.**

```dart
class AudioController {
  AudioController(this._engine, AudioSettings initial) : _settingsSnapshot = initial;
  final AudioEngine _engine;
  AudioSettings _settingsSnapshot;

  /// Update settings snapshot and react to diff:
  /// - masterVolume change triggers live loop re-volume when music on
  /// - music toggle on/off start/stop ambient
  /// - sfx toggle snapshot-checked at playCue (no diff needed)
  Future<void> updateSettings(AudioSettings next) async {
    final prev = _settingsSnapshot;
    _settingsSnapshot = next;
    if (next.musicEnabled && !prev.musicEnabled) await startAmbient();
    if (!next.musicEnabled && prev.musicEnabled) await stopAmbient();
    if (next.masterVolume != prev.masterVolume && next.musicEnabled) {
      await _engine.setLoopVolume(next.masterVolume * 0.6);
    }
  }

  Future<void> playCue(SfxCue cue) async {
    if (!_settingsSnapshot.sfxEnabled) return;
    await _engine.playOneShot(
      SfxCatalog.assetPath(cue),
      volume: _settingsSnapshot.masterVolume,
    );
  }

  Future<void> startAmbient() async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.startLoop(
      'audio/music/artisan_ambient.ogg',
      volume: _settingsSnapshot.masterVolume * 0.6,  // ducked vs SFX
    );
  }

  Future<void> stopAmbient() => _engine.stopLoop();
  Future<void> pauseAmbient() => _engine.pauseLoop();
  Future<void> resumeAmbient() async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.resumeLoop();
  }

  /// Preview volume during slider drag (engine-only, no prefs write).
  Future<void> previewVolume(double v) async {
    if (!_settingsSnapshot.musicEnabled) return;
    await _engine.setLoopVolume(v * 0.6);
  }
}
```

### 2.3 AudioSettings model

```dart
@immutable
class AudioSettings {
  final bool musicEnabled;       // default: false (opt-in music — mobil bağlam)
  final bool sfxEnabled;         // default: true (tap feedback kontratı)
  final double masterVolume;     // 0.0-1.0, default: 0.7

  const AudioSettings({
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.masterVolume,
  });

  const AudioSettings.defaults()
      : musicEnabled = false,
        sfxEnabled = true,
        masterVolume = 0.7;

  AudioSettings copyWith({bool? musicEnabled, bool? sfxEnabled, double? masterVolume});
}
```

**Defaults rationale:** Mobil oyuncu bağlamı (toplu taşıma, iş arası) müziği kapalı bekler; ilk açılışta charm maliyeti < "ses zorla çıktı" maliyeti. SFX default true, çünkü tap feedback üçlüsü (haptic + görsel + ses) ilk sözleşmeyi kurar. Music opt-in → oyuncu Settings'te açtığında keşif anı.

**Post-MVP:** `AudioPreferenceChanged` telemetry event ile toggle-rate ölçülür.

### 2.4 AudioSettingsNotifier

```dart
class AudioSettingsNotifier extends AsyncNotifier<AudioSettings> {
  static const _prefMusic = 'crumbs.audio_music_enabled';
  static const _prefSfx = 'crumbs.audio_sfx_enabled';
  static const _prefVolume = 'crumbs.audio_master_volume';

  @override
  Future<AudioSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AudioSettings(
      musicEnabled: prefs.getBool(_prefMusic) ?? false,
      sfxEnabled: prefs.getBool(_prefSfx) ?? true,
      masterVolume: prefs.getDouble(_prefVolume) ?? 0.7,
    );
  }

  Future<void> setMusicEnabled(bool v) async { /* prefs write + state update */ }
  Future<void> setSfxEnabled(bool v)   async { /* prefs write + state update */ }
  Future<void> setMasterVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    /* prefs write + state update */
  }
}
```

Pattern paraleli: B4 `TutorialNotifier` + `DeveloperVisibility` — AsyncNotifier + prefs.

### 2.5 SfxCatalog

```dart
enum SfxCue { tap, purchaseSuccess, upgradeBuy, stepComplete }

class SfxCatalog {
  static String assetPath(SfxCue c) => switch (c) {
    SfxCue.tap              => 'audio/sfx/tap.ogg',
    SfxCue.purchaseSuccess  => 'audio/sfx/purchase.ogg',
    SfxCue.upgradeBuy       => 'audio/sfx/upgrade.ogg',
    SfxCue.stepComplete     => 'audio/sfx/step_complete.ogg',
  };
}
```

**Naming notu:** `stepComplete` domain-neutral — tutorial'a özel değil, post-MVP research node unlock / achievement claim gibi yerlerde reuse edilebilir.

**Out of scope cue'lar (§5.1):** `error` cue düşürüldü (industry pattern, double-negative UX).

---

## Data Flow + Lifecycle Integration (§3)

### 3.1 Boot sequence

```
main():
  FirebaseBootstrap.initialize()          // mevcut
  runApp(ProviderScope(...))
    └─ AppBootstrap → prefs + save load + state hydrate
    └─ YENİ: Future.microtask(() => container.read(audioEngineProvider).init())
    └─ audioSettingsProvider.build() lazy on first watch
    └─ audioControllerProvider lazy on first watch, listen kurar
```

**Ambient ilk start:** Boot'ta AUTO-START yok. Default `musicEnabled=false` olduğu için fresh install sessiz. Kullanıcı Settings'te toggle açarsa `updateSettings` diff devreye girer → `startAmbient()`.

**Race guard:** Kullanıcı init <500ms'de Settings'e girip toggle açarsa, `startAmbient` engine'deki `_initCompleter.future` await'ine takılır (§2.1). Init tamamlandığında engine çağrısı otomatik ilerler; `_failed=true` durumda silent no-op. Oyuncu tarafında "bir an sessiz, sonra ses geldi" latency = init süresi (~200-500ms) — acceptable.

**Hydrate race guard (küçük):** Kullanıcı fresh install'da Settings'e hydrate tamamlanmadan girerse loading state gösterilir (CircularProgressIndicator), toggle'lar gizlenir. Plan'da `AsyncValue.when(loading: ..., data: ...)` pattern.

### 3.2 AppLifecycleGate audio hooks

```dart
Future<void> _onPause() async {
  // YENİ — en önce, ama persist'i bloklamasın: audio fail silent absorbed.
  try {
    await ref.read(audioControllerProvider).pauseAmbient();
  } catch (e, st) {
    debugPrint('audio pauseAmbient failed in _onPause: $e');
  }
  await ref.read(saveRepositoryProvider).persistNow();      // mevcut, kritik (invariant [I6])
  ref.read(sessionControllerProvider).onPause();            // mevcut
}

void _onResume() {
  ref.read(saveRepositoryProvider).applyResumeDelta();      // mevcut
  ref.read(sessionControllerProvider).onResume();           // mevcut
  // YENİ — en sonda; throw etse bile UI ve session zaten hazır.
  try {
    ref.read(audioControllerProvider).resumeAmbient();
  } catch (e, st) {
    debugPrint('audio resumeAmbient failed in _onResume: $e');
  }
}
```

**onPause sıra gerekçesi:** Ambient pause en önce — iOS kill senaryosunda ses ortada kalmasın. Try/catch zorunlu: audio hata `persistNow()`'u **asla** bloklamamalı (save kaybı [I6] ihlali). [I23] ordering invariant'ı korunur; "pauseAmbient başarısız olsa bile persist çalışır" garantisi.
**onResume sıra gerekçesi:** Audio en sonda — ses gelmeden UI hazır olmalı. resumeAmbient fail olsa bile state + session restore edilmiş.

Yeni invariant [I23] (§6).

### 3.3 TapArea feedback gate (kritik)

Mevcut `lib/features/home/tap_area.dart` 80ms haptic throttle'ı **hem haptic hem SFX**'i kapsar:

```dart
DateTime _lastFeedbackAt = DateTime.fromMillisecondsSinceEpoch(0);  // rename: _lastHapticAt → _lastFeedbackAt

void _onTap() {
  ref.read(gameStateNotifierProvider.notifier).tapCrumb();
  final now = DateTime.now();
  if (now.difference(_lastFeedbackAt).inMilliseconds >= 80) {
    HapticFeedback.selectionClick();
    ref.read(audioControllerProvider).playCue(SfxCue.tap);
    _lastFeedbackAt = now;
  }
}
```

**Invariant [I22]:** Rapid tap → hem haptic hem SFX skip; stacking yok, kakofoni yok.

### 3.4 Cue emit site'leri

| Event | Dosya | Hook |
|---|---|---|
| PurchaseSuccess | `lib/features/shop/building_row.dart` onBuy | `playCue(SfxCue.purchaseSuccess)` — purchase success dönüşünden sonra |
| UpgradeBuy | `lib/features/upgrades/upgrade_tile.dart` onBuy | `playCue(SfxCue.upgradeBuy)` — aynı pattern |
| StepComplete | `lib/features/tutorial/tutorial_scaffold.dart` advance listener | Mevcut `ref.listen` gate'inde, tutorial step geçişinde. Replay sırasında her zaman çalar (flag-based suppress YOK — replay de oyuncu deneyimi). |

**Failure isolation:** `playCue` throws → `debugPrint` + no-op. Oyun logic'i duraklamaz.

### 3.5 Settings UI (AudioSettingsSection rewrite)

```
AudioSettingsSection:
  AsyncValue.when(
    loading: CircularProgressIndicator,
    error: (_, _) => ErrorText + retry button,
    data: (settings) => Column(
      SwitchListTile: Müzik → setMusicEnabled
      SwitchListTile: Efektler → setSfxEnabled
      Divider
      ListTile: Genel Ses label + Slider (0.0-1.0)
        onChanged: (v) {
          setState local value;
          controller.previewVolume(v);        // engine live
          _debounce(100ms, () => notifier.setMasterVolume(v));  // prefs persist
        }
        onChangeEnd: (v) {
          cancel debounce;
          notifier.setMasterVolume(v);        // immediate final
        }
    )
  )
```

**Slider UX gerekçesi:** onChangeEnd kötü UX — kullanıcı drag ederken ses değişmesini duymak ister (Spotify/YouTube pattern). Throttled 100ms onChanged disk I/O'yu sınırlar, engine volume anlık.

**L10n değişiklikleri (tr.arb):**
- `settingsAudioMusicToggle` — korunur ("Müzik")
- `settingsAudioSfxToggle` — korunur ("Efektler")
- `settingsAudioMasterVolume` — **yeni** ("Genel Ses")
- `settingsAudioStubHint` — **silinir** (artık placeholder değil)

**Slider görsel:** Material `Slider` default, `SliderTheme` custom B5'te YOK. Dönem paletine hizalama visual-design.md asset teslimi sonrası polish sprint'te.

### 3.6 Edge case matrisi

| Senaryo | Davranış |
|---|---|
| Asset missing | `playCue` → engine throws → catch → debugPrint, no-op |
| Engine init fail | `_failed=true`; tüm play'ler no-op; Settings toggle'ları çalışır (prefs) ama ses yok. Gameplay etkilenmez. |
| Silent switch ON (iOS) | Ambient category otomatik mute; play calls exception atmaz; crash yok |
| App background'dayken music toggle OFF | `updateSettings` diff'te ambient zaten paused; `stopAmbient` çalar (idempotent) |
| SharedPreferences hydrate fail | AsyncNotifier error state; controller `AudioSettings.defaults()` fallback |
| Slider drag sırasında app background | onChangeEnd veya debounce fire → prefs persist; resume'de aynı volume restore |
| Dispose sonrası play call | `_failed=true` veya `DisposedEngineException` (plan'da karar) — no-op fail-silent |

---

## Testing Strategy + Definition of Done (§4)

### 4.1 Test layers

| Katman | Kapsam | Dosya |
|---|---|---|
| Unit | AudioController diff, AudioSettings model, AudioSettingsNotifier prefs, SfxCatalog map | `test/core/audio/*_test.dart` |
| Widget | AudioSettingsSection switch/slider onChanged, throttle debounce, loading guard | `test/features/settings/audio_settings_section_test.dart` (rewrite) |
| Integration | Lifecycle pause/resume ordering, boot hydrate defaults, tap throttle gate | `integration_test/audio_lifecycle_integration_test.dart` (yeni) |

### 4.2 FakeAudioEngine (mocktail)

Tek fake, tüm testlerde reuse. State çağrıları record eder (`oneShots: List<String>`, `loopsStarted`, `loopRunning`, `loopPaused`, `currentVolume`, `disposed`).

### 4.3 Kritik test senaryoları

**AudioController diff (unit):**
- `updateSettings(musicOff → musicOn)` → `startLoop` called
- `updateSettings(musicOn → musicOff)` → `stopLoop` called
- `updateSettings(volume 0.7 → 0.5)` while music on → `setLoopVolume(0.3)` called (0.5 × 0.6)
- `updateSettings(sfx toggle)` → no loop side-effect
- `playCue` when `sfxEnabled=false` → engine not called
- `playCue` when engine `_failed=true` → engine not called, no throw

**AudioSettingsNotifier (unit):**
- Fresh prefs → `AudioSettings.defaults()` (musicEnabled=false, sfxEnabled=true, volume=0.7)
- Persisted state → hydrate reflects disk values
- `setMasterVolume(1.5)` → clamped to 1.0
- `setMasterVolume(-0.2)` → clamped to 0.0

**TapArea feedback gate (widget):**
- 10 taps in 50ms → haptic + SFX each called **1 time** (throttle holds both)
- 5 taps at 100ms intervals → haptic + SFX each called **5 times**
- SFX cue asset path = `audio/sfx/tap.ogg`

**Lifecycle ordering (integration):**
- onPause: `pauseAmbient` → `persistNow` → `session.onPause` (invariant [I23])
- onResume: `applyResumeDelta` → `session.onResume` → `resumeAmbient` (audio last)

**Engine init fail (integration):**
- `FakeAudioEngine.init()` throws → `_failed=true` → tüm plays no-op → purchase flow + tutorial advance test geçer

**Settings UI (widget):**
- `AsyncValue.loading` → `CircularProgressIndicator`, toggle'lar gizli
- `AsyncValue.data` → switch'ler hizalı
- Slider drag → `previewVolume` her frame, `setMasterVolume` 100ms sonra (**`fake_async` paketi ile time travel** — gerçek `Timer(100ms)` bekleme = flake riski; pubspec'e dev_dependency eklenir)
- onChangeEnd → debounce cancel + immediate setMasterVolume

**Resource leak guard (unit):**
- `pauseAmbient() → dispose()` → FakeAudioEngine state `loopPaused=true, disposed=true`, no lingering refs
- `audioEngineProvider` disposed → `fake.disposed=true`

### 4.4 Coverage

- `lib/core/audio/` → **≥80%** (core/economy ≥95% daha sıkı; audio platform-bound)
- `audioplayers_engine.dart` → **excluded from coverage** (platform-specific, integration smoke only)
- `FakeAudioEngine` → test helper, coverage exclusion

### 4.5 Definition of Done

**Code DoD (B5 sprint içinde):**
- [ ] `lib/core/audio/` — 5 yeni dosya
- [ ] `lib/features/settings/widgets/audio_settings_section.dart` — rewrite
- [ ] `lib/features/home/tap_area.dart` — `_lastFeedbackAt` rename + SFX call
- [ ] Shop + Upgrade buy handler'ları — `playCue` eklemesi
- [ ] `TutorialScaffold` — stepComplete cue advance'de
- [ ] `AppLifecycleGate` — pauseAmbient + resumeAmbient hook'ları (sıra [I23])
- [ ] `main.dart` — `Future.microtask` engine init
- [ ] `pubspec.yaml` — `audioplayers: ^6.x` + `assets/audio/{sfx,music}/` declarations
- [ ] `lib/l10n/tr.arb` — `settingsAudioMasterVolume` eklendi + `settingsAudioStubHint` silindi + regen

**Tests:**
- [ ] `flutter analyze`: No issues
- [ ] `flutter test -j 1`: tüm önceki 258 test + yeni audio testleri pass
- [ ] `lib/core/audio/` coverage ≥80%
- [ ] Integration test: lifecycle ordering + boot + init fail

**Placeholder Asset DoD (B5 sprint içinde — minimal quality):**
- [ ] 4 SFX placeholder (Audacity generated beep/click, <30 dk toplam) — tap, purchase, upgrade, step_complete
- [ ] 1 ambient placeholder loop (30-60 sn, basit pad; Audacity veya bir freesound CC0 quick pick)
- [ ] `docs/audio-licenses.md` — placeholder kaynak satırları (5 satır, generated ise "Own production CC0-equivalent" notu)
- [ ] `assets/audio/sfx/*.ogg` + `assets/audio/music/*.ogg` drop — engine end-to-end test edilebilir

**Quality Asset Curation (paralel task, B5 sonrası, ship engelleyici değil):**
- [ ] `_dev/tasks/post-b5-audio-asset-curation.md` not — paid library evaluation (Epidemic trial / Splice) veya yüksek kaliteli CC0 curation
- [ ] Asset swap: `assets/audio/` dosyaları replace; `audio-licenses.md` güncel atıflar
- [ ] Post-launch 2 hafta içinde kullanıcı feedback'e göre tetiklenir (risk §5.4 "kalite yetersiz" mitigasyonu)

**Manuel QA (DoD — tester checklist, `docs/audio-plan.md`'da dokümante):**
- [ ] iOS simulator silent switch ON → ambient + SFX mute, crash yok
- [ ] iOS simulator silent switch OFF → ses gelir
- [ ] iOS: Spotify çalarken app aç → Spotify kesilmez, ambient mix olur (Ambient category doğrulaması)
- [ ] Android emulator ring silent → ses çalar (platform convention)
- [ ] Android emulator normal → ses çalar
- [ ] `xcrun simctl spawn booted log stream` → hiç audio error log yok

**Docs:**
- [ ] `docs/audio-plan.md` — opsiyonel runbook (paket gerekçesi, AudioEngine kontratı, manuel QA checklist, asset placeholder strategy)
- [ ] `CLAUDE.md §4` — audio-plan.md ek operasyonel doküman listesine eklendi
- [ ] `CLAUDE.md §5` — `core/audio/` dizini eklendi
- [ ] `CLAUDE.md §12` — "Audio engine fail-silent invariant" gotcha + invariant [I21] [I22] [I23] referansları

---

## Scope + Open Questions + Risks (§5)

### 5.1 In Scope (B5)

- `lib/core/audio/` modülü (5 dosya: engine, settings, notifier, catalog, controller)
- 4 SFX cue (tap, purchaseSuccess, upgradeBuy, stepComplete)
- 1 ambient loop (60 sn, artisan tema, looped)
- Settings UI: 2 switch + 1 throttled slider + loading guard
- AppLifecycleGate pause/resume + TapArea feedback gate + emit site'leri
- Fail-silent [I21] + tap throttle [I22] + onPause ordering [I23] invariant'ları
- Unit + widget + integration test
- CC0 placeholder asset 5 dosya + `docs/audio-licenses.md`
- `docs/audio-plan.md` opsiyonel runbook

### 5.2 Out of Scope (post-MVP / Sprint C+)

- Dönem-spesifik ambient müzik (artisan/industrial/galactic 3 track) — Sprint D prestige polish
- Cue-per-step tutorial (her step ayrı ses) — post-MVP backlog
- Cue-level volume map (tap subtle / purchase celebratory) — post-asset mixing pass
- `error` cue — düşürüldü (industry pattern, double-negative UX)
- Dual-format asset (iOS .m4a + Android .ogg) — B6 polish
- Platform parity CI automation (patrol) — post-MVP backlog
- Epidemic/Splice paid subscription asset upgrade — post-MVP
- `AudioPreferenceChanged` telemetry event — post-MVP, toggle-rate ölçümü
- Ad/IAP ducking — ads MVP'de aktif değil
- Crossfade between ambient tracks — just_audio migration gerektirir (C+ dönem geçişi)
- Ambient multi-variant shuffle (2-3 loop karışık çalar) — `PlaylistAudioSource` gerektirir, post-MVP

### 5.3 Resolved Decisions (brainstorming sonucu)

1. Paket: **audioplayers** (multi-SFX concurrent + loop ambient için optimal)
2. Asset kaynağı: **CC0 placeholder-first** (freesound.org), final polish swap post-MVP
3. iOS ses kategorisi: **Ambient** (silent respect, other audio mix)
4. Controller pattern: **Pattern A** — Provider<AudioController> + ref.listen
5. updateSettings diff: **reactive** (music toggle on/off = start/stop, volume = live loop update)
6. AudioPool init: **parallel Future.wait** tüm cue'lar pre-warm
7. Cue naming: **stepComplete** (domain-neutral, tutorialAdvance değil)
8. Format: **.ogg tek format** B5'te, dual-format B6 polish
9. Defaults: **musicEnabled=false, sfxEnabled=true, volume=0.7**
10. Error cue: **dropped** — industry pattern (Cookie Clicker / Egg Inc / AdVenture Capitalist error screen'de ses çalmaz), double-negative UX
11. Slider: Material default + throttled onChanged 100ms + onChangeEnd immediate
12. Engine init: **lazy Future.microtask** runApp sonrası, cold start etkilenmez
13. Coverage: **≥80%** (audioplayers_engine.dart excluded)
14. Platform parity: **manuel DoD checklist**, CI automation post-MVP
15. Ambient: **tek loop 60 sn**, multi-variant post-MVP
16. Slider görsel: **Material default**, tema entegrasyonu post-asset polish
17. docs/audio-plan.md: **opsiyonel**, PRD §16.1 zorunlu listesine eklenmez
18. Tutorial replay SFX: **her zaman çal** (replay de oyuncu deneyimi)
19. `docs/audio-licenses.md`: 5 satır tablo (4 SFX + 1 ambient)
20. Engine impl dispose: idempotent, test FakeAudioEngine state check

### 5.4 Risks

| Risk | Olasılık | Impact | Mitigasyon |
|---|---|---|---|
| `audioplayers` iOS AVAudioSession Ambient bug | Düşük | Orta | Paket issue tracker scan + manuel DoD erken yakalar |
| CC0 asset curation 4-8 saat sprint gerilimi | Orta | Düşük | Placeholder generated beep (Audacity 30 dk) + paralel swap task |
| Ambient loop boundary click/pop | Orta | Düşük | "Seamless loop" filter freesound.org + Audacity crossfade edit |
| `audioplayers` 6.x AudioPool API deprecation | Düşük | Orta | Plan T1: `flutter pub add audioplayers` + API smoke (AudioPool varlığı doğrula) |
| CC0 placeholder kalite yetersiz — "ses amatör" review | Orta | Düşük | Backlog'da asset curation task + post-launch 2 hafta içinde paid library evaluation |
| Android emulator ses yok ama cihazda çalışır | Düşük | Orta | Manuel DoD gerçek cihaz spot-check |
| App Store review reject — autoplay izin | **Çok düşük** | Düşük | Default `musicEnabled=false` opt-in pattern |
| Asset repo size 1MB aşar → Git LFS migration | Düşük | Düşük | Plan not: 1MB altı inline, üstünde LFS — backlog |

### 5.5 Dependencies

**Blocking:** Yok. B4 merged, main temiz, analyze clean, 258 test pass.
**New package:** `audioplayers: ^6.x` (pubspec.yaml)
**Asset pipeline:** `assets/audio/{sfx,music}/` dirs + pubspec declaration.

### 5.6 Task estimate

**Beklenen task sayısı: 12-14** (writing-plans sürecinde birleştirmeyle 11-12'ye inebilir)

Kabaca:
1. Package add + API smoke check (audioplayers 6.x AudioPool varlığı) + asset dir iskeleti
2. SfxCue enum + SfxCatalog
3. AudioSettings model + copyWith + equality + unit test
4. AudioSettingsNotifier + prefs roundtrip + unit test
5. AudioEngine interface + FakeAudioEngine helper
6. AudioplayersEngine impl (platform config, pool warm, dispose, fail sentinel)
7. AudioController + updateSettings diff + unit test
8. audioControllerProvider + ref.listen + unit test
9. AppLifecycleGate pause/resume hooks + integration test [I23] ordering
10. TapArea feedback gate rename + SFX + widget test [I22]
11. Emit sites (shop + upgrade + tutorial, tek task 3 site)
12. AudioSettingsSection rewrite (switches + slider + throttle + loading guard) + widget test (+ `fake_async` dev dependency add)
13. Placeholder asset drop (generated beep/click, 4 SFX + 1 ambient) + `docs/audio-licenses.md` + `docs/audio-plan.md`
14. CLAUDE.md §4/§5/§12 + invariant [I21][I22][I23] dokümantasyonu

---

## Invariants (§6)

Yeni invariant'lar B5 kapsamında:

- **[I21] — AudioController fail-silent:** Engine `_failed=true` sentinel aktifse `playCue`, `startAmbient`, `resumeAmbient`, `setLoopVolume` no-op. Hata throw etmez. Gameplay korunur (B3 `FirebaseBootstrap.isInitialized` paterniyle paralel).
- **[I22] — TapArea haptic + SFX ortak gate:** 80ms throttle hem haptic hem SFX için tek gate. Rapid tap → ikisi de skip. Stacking, kakofoni yok.
- **[I23] — onPause ordering with audio:** `pauseAmbient → persistNow → session.onPause`. Audio en önce (kill senaryosunda ses ortada kalmasın), telemetry en sonda (kayıp kabul edilebilir). [I6] "persist > telemetry" temel sözleşmesi korunur; [I23] 3-aşamalı genişletme.

**[I6] güncel form:** `onPause ordering: persist > telemetry` — audio olmayan kod path'lerinde hâlâ geçerli. Audio eklenen path'lerde [I23] tam sırayı tanımlar.

---

## Verification (spec-level)

- **Placeholder scan:** Yok — tüm "TBD", "TODO" yerler karara bağlandı (20 resolved decision §5.3).
- **Internal consistency:** Cue sayısı tutarlı (§2.5 4 cue, §3.4 emit sites 4 cue, §4.5 DoD 4 asset). `stepComplete` naming her section'da aynı. Failure sentinel her 4 referansda (§2.1 impl, §2.2 controller guard, §3.6 edge case, §6 [I21]) `_failed=true` — "plan'da karar" cümlesi silindi, spec-level kesinleşti.
- **Scope:** Tek sprint için odaklı — 12-14 task, yeni alt-subsystem yok (audio tek modül, mevcut settings/tutorial/home dosyalarına tek satır entegrasyon).
- **Ambiguity:** Yok — slider UX (throttle 100ms + `fake_async` test), init pattern (`Future.microtask` + `_initCompleter` race guard), Engine dispose davranışı (idempotent, `_disposed=true` silent no-op), _onPause audio fail absorption (try/catch, persist bloklanmaz), default values (musicEnabled=false) hepsi explicit.

---

## Next Steps

1. Spec commit: `docs(b5-spec): sprint B5 audio layer design`
2. User review — bu spec'i oku, değişiklik/ekleme gerekirse belirt
3. Onay geldikten sonra `superpowers:writing-plans` skill → implementation plan yazılır
4. Plan onaylanırsa branch `sprint/b5-audio-layer` açılır, subagent-driven development başlar
