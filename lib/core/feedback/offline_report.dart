import 'package:freezed_annotation/freezed_annotation.dart';

part 'offline_report.freezed.dart';

/// Cold start hydration sonunda UI'a taşınan offline kazanç özeti.
/// applyResumeDelta (hot resume) BU MODELİ PUSH ETMEZ — yalnız build path.
/// Spec: design §2.3, §2.4
@freezed
abstract class OfflineReport with _$OfflineReport {
  const factory OfflineReport({
    required double earned,
    required Duration elapsed,
    required bool capped,
  }) = _OfflineReport;
}
