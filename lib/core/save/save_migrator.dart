import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/migrations/v1_to_v2.dart';
import 'package:crumbs/core/save/save_envelope.dart';

/// Migration orchestrator — raw Map'ten typed SaveEnvelope üretir.
///
/// Spec: docs/superpowers/specs/2026-04-17-sprint-b1-expansion-design.md §3.4
/// Spec: docs/save-format.md §5
///
/// **Kural:** Migration HER ZAMAN raw map üzerinde koşar,
/// `SaveEnvelope.fromJson` migration SONRASI çağrılır. Bu sayede freezed
/// `@Default` fallback davranışına bağımlılık kırılır — her migration adımı
/// yazılan explicit field'ı disk formatına işler.
class SaveMigrator {
  const SaveMigrator._();

  /// rawEnvelope: jsonDecode sonrası henüz typed yapılmamış Map.
  /// Returns: typed SaveEnvelope at targetVersion, with fresh checksum.
  /// Throws: [FormatException] if migration path yok.
  static SaveEnvelope migrate(
    Map<String, dynamic> rawEnvelope,
    int targetVersion,
  ) {
    final mutable = Map<String, dynamic>.from(rawEnvelope);
    var currentVersion = mutable['version'] as int;

    while (currentVersion < targetVersion) {
      if (currentVersion == 1) {
        final rawGs = mutable['gameState'] as Map<String, dynamic>;
        mutable['gameState'] = migrateV1ToV2GameState(rawGs);
        mutable['version'] = 2;
        currentVersion = 2;
      } else {
        throw FormatException(
          'No migration from v$currentVersion to v$targetVersion',
        );
      }
    }

    if (currentVersion > targetVersion) {
      throw FormatException(
        'No migration from v$currentVersion to v$targetVersion',
      );
    }

    final parsed = SaveEnvelope.fromJson(mutable);

    // Migration sonrası yeni payload için fresh checksum
    return parsed.copyWith(
      checksum: Checksum.of(parsed.gameState.toJson()),
    );
  }
}
