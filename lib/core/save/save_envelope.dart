import 'package:crumbs/core/save/game_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// Disk persistence şeması.
/// Spec: docs/save-format.md §1
///   docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.3
///
/// B1'den itibaren typed GameState. v1 disk formatı (`Map<String, dynamic>`)
/// SaveMigrator üzerinden raw parse edilir — bkz lib/core/save/migrations/.
@freezed
abstract class SaveEnvelope with _$SaveEnvelope {
  const factory SaveEnvelope({
    required int version,
    required String lastSavedAt,
    required GameState gameState,
    required String checksum,
  }) = _SaveEnvelope;

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) =>
      _$SaveEnvelopeFromJson(json);
}
