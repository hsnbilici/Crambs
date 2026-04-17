import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// SaveEnvelope — disk persistence şeması.
/// Spec: docs/save-format.md §1
///
/// gameState alanı A'da `Map<String, dynamic>` tutuyor; B'de GameState typed
/// field'a geçilir (envelope version 1 → 2 bump + migrator v1→v2).
@freezed
abstract class SaveEnvelope with _$SaveEnvelope {
  const factory SaveEnvelope({
    required int version,
    required String lastSavedAt,
    required Map<String, dynamic> gameState,
    required String checksum,
  }) = _SaveEnvelope;

  factory SaveEnvelope.fromJson(Map<String, dynamic> json) =>
      _$SaveEnvelopeFromJson(json);
}
