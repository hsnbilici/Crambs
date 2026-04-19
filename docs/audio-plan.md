# Audio Plan — Operasyonel Runbook

**Durum:** B5 sprint çıktısı. CLAUDE.md §4 ek operasyonel doküman listesinde.

## Paket Seçimi

**audioplayers ^6.x** — multi-SFX concurrent + single ambient loop için optimal. Alternatifler değerlendirildi (`just_audio`, `soloud`) — spec §brainstorming bölümünde karar gerekçeleri.

## Mimari

`lib/core/audio/` — AudioEngine interface + AudioplayersEngine impl + AudioController + AudioSettings + SfxCatalog. Detay: `docs/superpowers/specs/2026-04-19-sprint-b5-audio-layer-design.md §1-2`.

## Platform Parity

### iOS

- `AVAudioSessionCategory.ambient` — silent switch'e saygı, diğer müzikle mix.
- Silent mode ON → ambient + SFX mute (platform seviyesinde), crash yok.
- Spotify/podcast çalarken app açılır → karışır, kesmez.

### Android

- `STREAM_MUSIC` default (platform convention).
- Ring mode silent → ambient + SFX **çalar** (Android kullanıcı beklentisi).

## Manuel QA Checklist (DoD)

B5 sprint close'dan önce gerçek cihaz + simulator'de doğrulanır:

- [ ] iOS simulator silent switch ON → ambient + SFX mute, crash yok, lifecycle pause hâlâ çalışır
- [ ] iOS simulator silent switch OFF → ambient (toggle açıksa) + SFX gelir
- [ ] iOS: Spotify çalarken app aç → Spotify kesilmez, ambient mix olur
- [ ] Android emulator ring silent → ambient + SFX çalar
- [ ] Android emulator normal → ambient + SFX çalar
- [ ] `xcrun simctl spawn booted log stream --predicate 'process == "Runner"'` → hiç audio error log yok
- [ ] Rapid tap (10/sec) → tek SFX per 80ms ([I22])
- [ ] App pause → ambient susar → app resume → ambient geri gelir
- [ ] Engine init fail senaryosu (dev override) → toggle'lar çalışır, ses yok, crash yok

## Asset Placeholder Stratejisi

B5 ship'i için placeholder asset'ler (ffmpeg generated sine tones) kullanılır. Final quality curation paralel task: `_dev/tasks/post-b5-audio-asset-curation.md`. Post-launch 2 hafta içinde kullanıcı feedback'e göre tetiklenir.

## Invariants

- **[I21]** Audio fail-silent: engine init fail veya dispose sonrası tüm play metodları no-op
- **[I22]** TapArea haptic + SFX ortak 80ms gate — stacking yok
- **[I23]** onPause ordering: `pauseAmbient → persistNow → session.onPause` ([I6] extends)

## Post-MVP Roadmap

- Dönem-spesifik ambient (industrial/galactic loops) → Sprint D prestige polish
- Dual-format (iOS .m4a + Android .ogg) → B6 polish
- Platform parity CI automation (patrol) → post-MVP backlog
- `AudioPreferenceChanged` telemetry event → post-MVP
