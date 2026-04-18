import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppInstall event trigger'ı için "bu cihazın ilk boot'u mu?" sinyali.
///
/// Tutorial state'inden DISJOINT — TutorialNotifier.reset() bu provider'a
/// dokunmaz, yani tutorial replay sonrası AppInstall re-emit EDİLMEZ
/// (invariant I18).
///
/// Pre-B4 migration: B4 öncesi install'lar `first_launch_observed` pref'ine
/// sahip değil, ama `install_id` pref'i B1'den beri mevcut. `install_id`
/// varlığı "bu cihaz daha önce boot edilmiş" kanıtı — backfill observed=true.
class FirstBootNotifier extends Notifier<bool?> {
  static const _prefKey = 'crumbs.first_launch_observed';

  @override
  bool? build() => null;

  /// Boot'ta bir kez çağrılır. İdempotent (ikinci çağrı pref'ten okur).
  ///
  /// Returns: bu cihazın ilk B4 boot'u mu?
  ///   - true  → fresh B4 install (AppInstall emit edilmeli)
  ///   - false → pre-B4 migration OR second+ boot (AppInstall suppressed)
  Future<bool> ensureObserved() async {
    final prefs = await SharedPreferences.getInstance();
    final wasObserved = prefs.getBool(_prefKey) ?? false;
    if (!wasObserved) {
      final installId = prefs.getString('crumbs.install_id');
      if (installId != null) {
        await prefs.setBool(_prefKey, true);
        state = false;
        return false;
      }
      await prefs.setBool(_prefKey, true);
      state = true;
      return true;
    }
    state = false;
    return false;
  }
}

final firstBootProvider =
    NotifierProvider<FirstBootNotifier, bool?>(FirstBootNotifier.new);
