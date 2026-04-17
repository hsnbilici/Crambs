import 'package:crumbs/core/save/upgrade_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';
part 'game_state.g.dart';

/// Game state root — 3'lü ayrım: meta (deterministic invariant),
/// inventory (resource state), buildings (structure state).
///
/// OnboardingPrefs checksum/migration dışında kalır (device state ≠ player state).
///
/// OfflineReport push rule: yalnız cold start hydration (SaveRepository.load)
/// path'inde tetiklenir. applyResumeDelta (hot resume) sessiz çalışır — kural
/// GameStateNotifier'da pekiştirilir (Task 11).
@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    required MetaState meta,
    required InventoryState inventory,
    required BuildingsState buildings,
    @Default(UpgradeState()) UpgradeState upgrades,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);

  factory GameState.initial({DateTime? now, String? installId}) => GameState(
        meta: MetaState(
          lastSavedAt: (now ?? DateTime.now()).toIso8601String(),
          schemaVersion: 1,
          installId: installId ?? 'uninitialized',
        ),
        inventory: const InventoryState(r1Crumbs: 0),
        buildings: const BuildingsState(owned: {}),
      );
}

@freezed
abstract class MetaState with _$MetaState {
  const factory MetaState({
    required String lastSavedAt,
    required int schemaVersion,
    required String installId,
  }) = _MetaState;
  factory MetaState.fromJson(Map<String, dynamic> j) =>
      _$MetaStateFromJson(j);
}

@freezed
abstract class InventoryState with _$InventoryState {
  const factory InventoryState({
    required double r1Crumbs,
  }) = _InventoryState;
  factory InventoryState.fromJson(Map<String, dynamic> j) =>
      _$InventoryStateFromJson(j);
}

@freezed
abstract class BuildingsState with _$BuildingsState {
  const factory BuildingsState({
    required Map<String, int> owned,
  }) = _BuildingsState;
  factory BuildingsState.fromJson(Map<String, dynamic> j) =>
      _$BuildingsStateFromJson(j);
}
