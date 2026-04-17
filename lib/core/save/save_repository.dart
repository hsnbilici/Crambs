import 'dart:convert';
import 'dart:io';

import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:path_provider/path_provider.dart';

/// Save load sonucu — envelope + opsiyonel recovery sinyali.
class SaveLoadResult {
  const SaveLoadResult({this.envelope, this.recovery});
  final SaveEnvelope? envelope;
  final SaveRecoveryReason? recovery;
}

/// _tryRead sonucu — okunabildi mi ve parse edilebildi mi ayrımı
/// recovery sinyali için gereklidir (dosya var ama bozuk ≠ dosya yok).
class _ReadResult {
  const _ReadResult({
    required this.existed,
    this.envelope,
  });
  final bool existed;
  final SaveEnvelope? envelope;
}

/// Disk I/O, atomik yazma, yedek rotasyon, corruption recovery.
/// Spec: docs/save-format.md §4, §5
///
/// Save cadence SaveRepository'de DEĞİL — AppLifecycleGate'te (30s + pause +
/// purchase sync). Concurrent save race: _pending Future lock ile serialize.
class SaveRepository {
  SaveRepository({Future<String> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<String> Function() _directoryProvider;
  Future<void>? _pending;

  static const _mainFileName = 'crumbs_save.json';
  static const _bakFileName = 'crumbs_save.json.bak';
  static const _tmpFileName = 'crumbs_save.json.tmp';

  static Future<String> _defaultDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> save(SaveEnvelope envelope) async {
    while (_pending != null) {
      await _pending;
    }
    _pending = _saveImpl(envelope);
    try {
      await _pending;
    } finally {
      _pending = null;
    }
  }

  Future<void> _saveImpl(SaveEnvelope envelope) async {
    final dir = await _directoryProvider();
    final main = File('$dir/$_mainFileName');
    final bak = File('$dir/$_bakFileName');
    final tmp = File('$dir/$_tmpFileName');

    final data = jsonEncode(envelope.toJson());
    await tmp.writeAsString(data, flush: true);

    // Atomik rotasyon: main varsa .bak'a taşı (önceki .bak silinir),
    // sonra tmp → main. Exists() kontrolü yerine delete/rename hatayı
    // yakalar (avoid_slow_async_io lint uyumu).
    try {
      await bak.delete();
    } on FileSystemException {
      // .bak yoktu; sorun değil.
    }
    try {
      await main.rename(bak.path);
    } on FileSystemException {
      // main yoktu (ilk save); rotasyon atlanır.
    }
    await tmp.rename(main.path);
  }

  Future<SaveLoadResult> load() async {
    final dir = await _directoryProvider();
    final main = File('$dir/$_mainFileName');
    final bak = File('$dir/$_bakFileName');

    final mainRead = await _tryRead(main);
    if (mainRead.envelope != null) {
      return SaveLoadResult(envelope: mainRead.envelope);
    }

    if (!mainRead.existed) {
      // Fresh install — recovery sinyali yok.
      return const SaveLoadResult();
    }

    // Main exists ama parse edilemedi → bak'tan dene.
    final bakRead = await _tryRead(bak);
    if (bakRead.envelope != null) {
      return SaveLoadResult(
        envelope: bakRead.envelope,
        recovery: SaveRecoveryReason.checksumFailedUsedBackup,
      );
    }
    return const SaveLoadResult(
      recovery: SaveRecoveryReason.bothCorruptedStartedFresh,
    );
  }

  Future<_ReadResult> _tryRead(File file) async {
    final String raw;
    try {
      raw = await file.readAsString();
    } on PathNotFoundException {
      return const _ReadResult(existed: false);
    } on FileSystemException {
      return const _ReadResult(existed: false);
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final envelope = SaveEnvelope.fromJson(json);
      // NFR-2 / save-format.md §3: checksum mismatch = corruption → bak fallback.
      if (Checksum.of(envelope.gameState.toJson()) != envelope.checksum) {
        return const _ReadResult(existed: true);
      }
      return _ReadResult(existed: true, envelope: envelope);
    } on Exception {
      return const _ReadResult(existed: true);
    }
  }
}
