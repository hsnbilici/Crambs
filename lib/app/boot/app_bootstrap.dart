import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pre-hydration saf servis — runApp çağrısından önce:
/// 1. WidgetsFlutterBinding ready
/// 2. SharedPreferences warm cache (ilk getInstance async; sonraki sync)
/// 3. ProviderContainer kurulumu
///
/// Lifecycle / autosave / observer sorumluluğu AppLifecycleGate (T13).
/// Firebase init ayrı runbook — A kapsamı dışı.
class AppBootstrap {
  const AppBootstrap._();

  static Future<ProviderContainer> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SharedPreferences.getInstance();
    return ProviderContainer();
  }
}
