import 'dart:convert';
import 'dart:io';

import 'package:crumbs/core/feedback/save_recovery.dart';
import 'package:crumbs/core/save/checksum.dart';
import 'package:crumbs/core/save/game_state.dart';
import 'package:crumbs/core/save/save_envelope.dart';
import 'package:crumbs/core/save/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late SaveRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crumbs_save_test_');
    repo = SaveRepository(directoryProvider: () async => tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Valid envelope — checksum matches gameState by default; override `tag`
  /// to mark different versions across tests (installId carries the tag).
  SaveEnvelope sampleEnvelope({String tag = 'v'}) {
    final gs = GameState.initial(
      installId: 'test-$tag',
      now: DateTime(2026, 4, 17, 12),
    );
    return SaveEnvelope(
      version: 2,
      lastSavedAt: '2026-04-17T12:00:00.000',
      gameState: gs,
      checksum: Checksum.of(gs.toJson()),
    );
  }

  group('SaveRepository.save', () {
    test('creates main.json file', () async {
      await repo.save(sampleEnvelope());
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
    });

    test('second save rotates .bak', () async {
      await repo.save(sampleEnvelope(tag: 'first'));
      await repo.save(sampleEnvelope(tag: 'second'));
      final main = File('${tempDir.path}/crumbs_save.json');
      final bak = File('${tempDir.path}/crumbs_save.json.bak');
      expect(main.existsSync(), isTrue);
      expect(bak.existsSync(), isTrue);
      final mainEnv = SaveEnvelope.fromJson(
        jsonDecode(main.readAsStringSync()) as Map<String, dynamic>,
      );
      final bakEnv = SaveEnvelope.fromJson(
        jsonDecode(bak.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(mainEnv.gameState.meta.installId, 'test-second');
      expect(bakEnv.gameState.meta.installId, 'test-first');
    });

    test('concurrent saves serialized (no race)', () async {
      final futures = List.generate(
        5,
        (i) => repo.save(sampleEnvelope(tag: 'save-$i')),
      );
      await Future.wait(futures);
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
      final mainEnv = SaveEnvelope.fromJson(
        jsonDecode(main.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(
        mainEnv.gameState.meta.installId.startsWith('test-save-'),
        isTrue,
      );
    });
  });

  group('SaveRepository.load — recovery', () {
    test('no file → null + no recovery reason', () async {
      final result = await repo.load();
      expect(result.envelope, isNull);
      expect(result.recovery, isNull);
    });

    test('valid main → returns envelope, no recovery', () async {
      await repo.save(sampleEnvelope());
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.envelope!.version, 2);
      expect(result.recovery, isNull);
    });

    test('corrupt main → uses .bak, signals checksumFailedUsedBackup',
        () async {
      await repo.save(sampleEnvelope(tag: 'bak-gen'));
      await repo.save(sampleEnvelope(tag: 'main-gen'));
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{corrupt');
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.recovery, SaveRecoveryReason.checksumFailedUsedBackup);
    });

    test('checksum mismatch (valid JSON, wrong hash) → uses .bak', () async {
      // Two saves → main + .bak both populated with real hashes.
      await repo.save(sampleEnvelope(tag: 'bak'));
      await repo.save(sampleEnvelope(tag: 'main-orig'));
      final mainPath = '${tempDir.path}/crumbs_save.json';
      final tamperedGs = GameState.initial(
        installId: 'tampered',
        now: DateTime(2026, 4, 17, 12),
      );
      File(mainPath).writeAsStringSync(
        jsonEncode({
          'version': 2,
          'lastSavedAt': '2026-04-17T12:00:00.000',
          'gameState': tamperedGs.toJson(),
          'checksum': 'deadbeef' * 8, // 64 hex but not the real hash
        }),
      );
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.recovery, SaveRecoveryReason.checksumFailedUsedBackup);
      expect(
        result.envelope!.gameState.meta.installId,
        'test-bak',
        reason: 'must restore from .bak, not the tampered main',
      );
    });

    test('both corrupt → null + bothCorruptedStartedFresh', () async {
      await repo.save(sampleEnvelope(tag: 'v1'));
      await repo.save(sampleEnvelope(tag: 'v2'));
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{bad}');
      File('${tempDir.path}/crumbs_save.json.bak').writeAsStringSync('{bad}');
      final result = await repo.load();
      expect(result.envelope, isNull);
      expect(result.recovery, SaveRecoveryReason.bothCorruptedStartedFresh);
    });
  });
}
