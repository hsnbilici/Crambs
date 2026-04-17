import 'package:crumbs/core/feedback/offline_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineReport', () {
    test('constructor + equality', () {
      const r1 = OfflineReport(
        earned: 12.5,
        elapsed: Duration(minutes: 1),
        capped: false,
      );
      const r2 = OfflineReport(
        earned: 12.5,
        elapsed: Duration(minutes: 1),
        capped: false,
      );
      expect(r1, equals(r2));
    });

    test('capped flag field', () {
      const r = OfflineReport(
        earned: 0,
        elapsed: Duration(days: 2),
        capped: true,
      );
      expect(r.capped, isTrue);
    });
  });
}
