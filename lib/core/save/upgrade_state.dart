import 'package:freezed_annotation/freezed_annotation.dart';

part 'upgrade_state.freezed.dart';
part 'upgrade_state.g.dart';

/// Satın alınmış upgrade'ler.
///
/// **Convention (B1):** `owned` YALNIZCA true entry'leri tutar. buyUpgrade
/// `id: true` yazar; false durumu production flow'unda oluşmaz. fromJson
/// tarihî/malformed veri için tolere eder.
///
/// Spec: docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.1
@freezed
abstract class UpgradeState with _$UpgradeState {
  const factory UpgradeState({
    @Default(<String, bool>{}) Map<String, bool> owned,
  }) = _UpgradeState;

  factory UpgradeState.fromJson(Map<String, dynamic> json) =>
      _$UpgradeStateFromJson(json);
}
