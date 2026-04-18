import 'package:flutter/foundation.dart';

/// Immutable audio settings.
///
/// Defaults rationale (spec §2.3):
/// - `musicEnabled: false` — mobile context (transit, offices) expects
///   music off; opt-in via Settings toggle.
/// - `sfxEnabled: true` — tap feedback trio (haptic + visual + SFX)
///   establishes the first interaction contract.
/// - `masterVolume: 0.7` — comfortable listening range; 1.0 risks
///   audioplayers distortion with source files.
@immutable
class AudioSettings {
  const AudioSettings({
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.masterVolume,
  });

  const AudioSettings.defaults()
      : musicEnabled = false,
        sfxEnabled = true,
        masterVolume = 0.7;

  final bool musicEnabled;
  final bool sfxEnabled;
  final double masterVolume;

  AudioSettings copyWith({
    bool? musicEnabled,
    bool? sfxEnabled,
    double? masterVolume,
  }) {
    return AudioSettings(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSettings &&
          musicEnabled == other.musicEnabled &&
          sfxEnabled == other.sfxEnabled &&
          masterVolume == other.masterVolume;

  @override
  int get hashCode => Object.hash(musicEnabled, sfxEnabled, masterVolume);
}
