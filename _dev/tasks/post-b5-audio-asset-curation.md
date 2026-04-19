# Post-B5 Audio Asset Curation

**Durum:** Backlog — B5 ship sonrası tetiklenir (post-launch 2 hafta).
**Bağımlılık:** B5 audio layer merged.

## Kapsam

1. **Paid library evaluation** — Epidemic Sound 14-day trial. Artisan fırın teması ambient + 4 SFX alternatifleri denenir. Kalite/aboneliğe karar.
2. **CC0 curation alternatifi** — Epidemic/Splice yerine freesound.org'da "seamless loop" filtered ambient + 4 crisp SFX seçilir; atıf gereken varsa `docs/audio-licenses.md` güncel tutulur.
3. **Asset swap** — `assets/audio/` dosyaları replace; format `.ogg` korunur (dual-format iOS .m4a B6 polish).
4. **Mix pass** — Her cue için volume seviyesi balanced; `SfxCatalog` cue-level volume map gerekli ise eklenir (spec §5.2 post-asset mixing pass).
5. **License doc update** — `docs/audio-licenses.md` final satırlar.

## Acceptance

- [ ] Asset'ler 30s Hero Oven dokunuş + 5 dakikalık idle oturum ile test edildi
- [ ] Hiçbir loop boundary pop/click
- [ ] Kullanıcı feedback: "ses kalitesi iyi/kabul edilebilir"
- [ ] License doc güncel
