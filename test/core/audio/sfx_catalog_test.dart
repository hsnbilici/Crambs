import 'package:crumbs/core/audio/sfx_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SfxCue enum', () {
    test('has 4 values (error cue dropped — spec §5.3#10)', () {
      expect(SfxCue.values, hasLength(4));
      expect(
        SfxCue.values,
        containsAll([
          SfxCue.tap,
          SfxCue.purchaseSuccess,
          SfxCue.upgradeBuy,
          SfxCue.stepComplete,
        ]),
      );
    });
  });

  group('SfxCatalog.assetPath', () {
    test('maps each cue to audio/sfx/*.ogg', () {
      expect(SfxCatalog.assetPath(SfxCue.tap), 'audio/sfx/tap.ogg');
      expect(SfxCatalog.assetPath(SfxCue.purchaseSuccess),
          'audio/sfx/purchase.ogg');
      expect(SfxCatalog.assetPath(SfxCue.upgradeBuy),
          'audio/sfx/upgrade.ogg');
      expect(SfxCatalog.assetPath(SfxCue.stepComplete),
          'audio/sfx/step_complete.ogg');
    });
  });
}
