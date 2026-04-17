import 'package:crumbs/core/save/save_envelope.dart';

/// Save version zinciri yönetimi.
/// Spec: docs/save-format.md §6
///
/// A kapsamı: v1 → v1 no-op (framework hazır).
/// B'de migrator v1 → v2 eklenir (envelope typed GameState transition).
class SaveMigrator {
  const SaveMigrator._();

  /// Envelope'u target version'a taşır. Future-version gelirse UnsupportedError
  /// (kullanıcı yeni app sürümünü eski app'te açmaya çalıştı).
  static SaveEnvelope migrate(
    SaveEnvelope envelope, {
    required int targetVersion,
  }) {
    if (envelope.version == targetVersion) return envelope;
    if (envelope.version > targetVersion) {
      throw UnsupportedError(
        'Save version ${envelope.version} newer than app '
        'version $targetVersion — downgrade not supported',
      );
    }
    throw UnimplementedError(
      'Migration chain ${envelope.version} → $targetVersion '
      'henüz tanımlı değil',
    );
  }
}
