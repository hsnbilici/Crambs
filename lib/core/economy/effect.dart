import 'package:flutter/foundation.dart';

/// Upgrade etki tipleri (economy.md §6 çarpan katmanları).
/// B1'de sadece globalMultiplier implemented; B2/C'de
/// buildingSpecific, event, research, prestige, costReduction eklenir.
enum EffectType { globalMultiplier }

/// Upgrade etkisi — tip + değer.
///
/// Düz const class; freezed değil — fromJson gerekmez (catalog sabit).
@immutable
class Effect {
  const Effect({required this.type, required this.value});

  final EffectType type;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is Effect && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}
