import 'package:freezed_annotation/freezed_annotation.dart';

part 'save_envelope.freezed.dart';
part 'save_envelope.g.dart';

/// SaveEnvelope şeması — docs/save-format.md §1
/// TODO: gameState alanı GameState tipine geçirilecek — ayrı task
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
