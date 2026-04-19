import 'dart:async';

import 'package:crumbs/core/audio/audio_engine.dart';
import 'package:crumbs/core/audio/audio_settings_notifier.dart';
import 'package:crumbs/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings > Ses ve Müzik — B5 gerçek impl.
///
/// Spec §3.5:
/// - AsyncValue loading guard (race during hydrate)
/// - 2 switches: music + SFX → AudioSettingsNotifier setters
/// - Slider: previewVolume live on drag; debounced 100ms persist via
///   setMasterVolume (fake_async tested)
/// - onChangeEnd → cancel debounce + immediate final persist
class AudioSettingsSection extends ConsumerStatefulWidget {
  const AudioSettingsSection({super.key});

  @override
  ConsumerState<AudioSettingsSection> createState() =>
      _AudioSettingsSectionState();
}

class _AudioSettingsSectionState extends ConsumerState<AudioSettingsSection> {
  static const Duration _debounceDelay = Duration(milliseconds: 100);

  Timer? _volumeDebounce;
  double? _localVolume;

  @override
  void initState() {
    super.initState();
    // Eagerly build audioControllerProvider so its `ref.listen` on
    // audioSettingsProvider is wired up. Toggling music/SFX in this UI
    // relies on the controller's updateSettings diff to start/stop the
    // ambient loop — without this read, the provider stays lazy and
    // settings mutations would not reach the engine.
    ref.read(audioControllerProvider);
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    super.dispose();
  }

  void _onVolumeChanged(double v) {
    setState(() => _localVolume = v);
    unawaited(ref.read(audioControllerProvider).previewVolume(v));
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(_debounceDelay, () {
      unawaited(ref.read(audioSettingsProvider.notifier).setMasterVolume(v));
    });
  }

  void _onVolumeChangeEnd(double v) {
    _volumeDebounce?.cancel();
    unawaited(ref.read(audioSettingsProvider.notifier).setMasterVolume(v));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context)!;
    final async = ref.watch(audioSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.settingsAudioSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ses ayarları yüklenemedi: $e'),
          ),
          data: (settings) {
            final vol = _localVolume ?? settings.masterVolume;
            return Column(
              children: [
                SwitchListTile(
                  title: Text(s.settingsAudioMusicToggle),
                  value: settings.musicEnabled,
                  onChanged: (v) => unawaited(
                    ref
                        .read(audioSettingsProvider.notifier)
                        .setMusicEnabled(enabled: v),
                  ),
                ),
                SwitchListTile(
                  title: Text(s.settingsAudioSfxToggle),
                  value: settings.sfxEnabled,
                  onChanged: (v) => unawaited(
                    ref
                        .read(audioSettingsProvider.notifier)
                        .setSfxEnabled(enabled: v),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.settingsAudioMasterVolume)),
                      Expanded(
                        flex: 2,
                        child: Slider(
                          value: vol,
                          onChanged: _onVolumeChanged,
                          onChangeEnd: _onVolumeChangeEnd,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
