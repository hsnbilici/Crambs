/// Sound effect cues — 4 distinct audio events in MVP.
///
/// `stepComplete` domain-neutral (not tutorial-specific); post-MVP reuse
/// candidates: research node unlock, achievement claim.
///
/// `error` cue dropped per spec §5.3#10 (industry pattern — Cookie Clicker,
/// Egg Inc, AdVenture Capitalist error screens all silent).
enum SfxCue { tap, purchaseSuccess, upgradeBuy, stepComplete }

abstract final class SfxCatalog {
  static String assetPath(SfxCue cue) => switch (cue) {
        SfxCue.tap => 'audio/sfx/tap.ogg',
        SfxCue.purchaseSuccess => 'audio/sfx/purchase.ogg',
        SfxCue.upgradeBuy => 'audio/sfx/upgrade.ogg',
        SfxCue.stepComplete => 'audio/sfx/step_complete.ogg',
      };
}
