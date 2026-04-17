import 'dart:convert';
import 'dart:io';

import 'package:crumbs/core/feedback/save_recovery.dart';
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

  SaveEnvelope sampleEnvelope({String checksum = 'abc'}) => SaveEnvelope(
        version: 1,
        lastSavedAt: '2026-04-17T12:00:00.000',
        gameState: const {'x': 1},
        checksum: checksum,
      );

  group('SaveRepository.save', () {
    test('creates main.json file', () async {
      await repo.save(sampleEnvelope());
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
    });

    test('second save rotates .bak', () async {
      await repo.save(sampleEnvelope(checksum: 'first'));
      await repo.save(sampleEnvelope(checksum: 'second'));
      final main = File('${tempDir.path}/crumbs_save.json');
      final bak = File('${tempDir.path}/crumbs_save.json.bak');
      expect(main.existsSync(), isTrue);
      expect(bak.existsSync(), isTrue);
      final mainJson =
          jsonDecode(main.readAsStringSync()) as Map<String, dynamic>;
      final bakJson =
          jsonDecode(bak.readAsStringSync()) as Map<String, dynamic>;
      expect(mainJson['checksum'], 'second');
      expect(bakJson['checksum'], 'first');
    });

    test('concurrent saves serialized (no race)', () async {
      final futures = List.generate(5, (i) => repo.save(
            sampleEnvelope(checksum: 'save-$i'),
          ));
      await Future.wait(futures);
      final main = File('${tempDir.path}/crumbs_save.json');
      expect(main.existsSync(), isTrue);
      final mainJson =
          jsonDecode(main.readAsStringSync()) as Map<String, dynamic>;
      expect((mainJson['checksum'] as String).startsWith('save-'), isTrue);
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
      expect(result.envelope!.version, 1);
      expect(result.recovery, isNull);
    });

    test('corrupt main → uses .bak, signals checksumFailedUsedBackup',
        () async {
      await repo.save(sampleEnvelope(checksum: 'valid-bak'));
      await repo.save(sampleEnvelope(checksum: 'valid-main'));
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{corrupt');
      final result = await repo.load();
      expect(result.envelope, isNotNull);
      expect(result.recovery, SaveRecoveryReason.checksumFailedUsedBackup);
    });

    test('both corrupt → null + bothCorruptedStartedFresh', () async {
      await repo.save(sampleEnvelope(checksum: 'v1'));
      await repo.save(sampleEnvelope(checksum: 'v2'));
      File('${tempDir.path}/crumbs_save.json').writeAsStringSync('{bad}');
      File('${tempDir.path}/crumbs_save.json.bak').writeAsStringSync('{bad}');
      final result = await repo.load();
      expect(result.envelope, isNull);
      expect(result.recovery, SaveRecoveryReason.bothCorruptedStartedFresh);
    });
  });
}
