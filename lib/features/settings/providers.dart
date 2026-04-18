import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Developer subsection görünürlük gate'i.
/// - `kDebugMode`: her dev build'de visible
/// - `--dart-define=CRASHLYTICS_TEST=true`: release build'de QA/internal erişim
/// - Production release (flag yok): tamamen gizli — widget tree'de YOK
///
/// Test override:
///   ProviderScope(overrides: [
///     developerVisibilityProvider.overrideWithValue(true|false),
///   ])
///
/// `const bool.fromEnvironment` compile-time sabit — widget test'te doğrudan
/// manipüle edilemez. Provider wrapper test ergonomisini sağlar.
///
/// Production release gate (manual smoke zorunlu): kDebugMode test ortamında
/// her zaman true döner — automated test ile "release build'de Developer
/// section gizli" invariant'ı doğrulanamaz. DoD manual smoke test zorunlu.
final developerVisibilityProvider = Provider<bool>((ref) {
  return kDebugMode || const bool.fromEnvironment('CRASHLYTICS_TEST');
});
