import 'package:crumbs/core/save/save_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaveEnvelope', () {
    test('scaffold placeholder — TODO per docs/save-format.md §1', () {
      // Freezed constructor build_runner sonrası resolve olur.
      expect(SaveEnvelope, isA<Type>());
    });
  });
}
