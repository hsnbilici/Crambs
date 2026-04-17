import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 canonical JSON hash — key-sorted, determinism garantisi.
///
/// Amaç: disk corruption detection (NFR-2). Tamper resistance kapsam dışı —
/// single-player offline, leaderboard yok. Anti-cheat ihtiyacı doğarsa
/// HMAC + server secret'a geçilir, API surface (Checksum.of) korunur.
///
/// Spec: docs/save-format.md §3
class Checksum {
  const Checksum._();

  static String of(Map<String, dynamic> json) {
    final canonical = _canonicalize(json);
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static dynamic _canonicalize(dynamic v) {
    if (v is Map) {
      final sorted = SplayTreeMap<String, dynamic>.of(
        v.map((k, val) => MapEntry(k.toString(), _canonicalize(val))),
      );
      return sorted;
    }
    if (v is List) return v.map(_canonicalize).toList();
    return v;
  }
}
