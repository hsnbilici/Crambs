/// v1 → v2 GameState migration. Raw Map üzerinde çalışır, typed cast YOK.
///
/// **Kural (Spec §3.4):** Migration HER ZAMAN raw map üzerinde koşar,
/// `GameState.fromJson` migration SONRASI çağrılır. `@Default(UpgradeState())`
/// fallback davranışına güvenilmez — explicit putIfAbsent.
///
/// Idempotent: `upgrades` zaten varsa dokunulmaz.
Map<String, dynamic> migrateV1ToV2GameState(
  Map<String, dynamic> rawGameState,
) {
  return Map<String, dynamic>.from(rawGameState)
    ..putIfAbsent('upgrades', () => {'owned': <String, bool>{}});
}
