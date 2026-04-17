/// Save load path'inde corruption detection sonrası UI'a taşınan sinyal.
/// Spec: docs/save-format.md NFR-2 fallback to backup.
enum SaveRecoveryReason {
  checksumFailedUsedBackup,
  bothCorruptedStartedFresh,
}
