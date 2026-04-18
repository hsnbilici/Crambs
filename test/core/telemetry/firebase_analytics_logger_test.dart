import 'package:crumbs/core/telemetry/firebase_analytics_logger.dart';
import 'package:crumbs/core/telemetry/telemetry_event.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late _MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsLogger logger;

  setUp(() {
    analytics = _MockFirebaseAnalytics();
    logger = FirebaseAnalyticsLogger(analytics);
    when(() => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});
  });

  group('FirebaseAnalyticsLogger — log()', () {
    test('AppInstall → logEvent("app_install", {install_id, platform})', () {
      logger.log(const AppInstall(installId: 'abc', platform: 'ios'));
      verify(() => analytics.logEvent(
            name: 'app_install',
            parameters: {'install_id': 'abc', 'platform': 'ios'},
          )).called(1);
    });

    test('TutorialCompleted bool skipped=true → coerced to int 1', () {
      logger.log(const TutorialCompleted(
        installId: 'abc',
        skipped: true,
        durationMs: 3000,
      ));
      verify(() => analytics.logEvent(
            name: 'tutorial_completed',
            parameters: {
              'install_id': 'abc',
              'skipped': 1,
              'duration_ms': 3000,
            },
          )).called(1);
    });

    test('TutorialCompleted bool skipped=false → coerced to int 0', () {
      logger.log(const TutorialCompleted(
        installId: 'abc',
        skipped: false,
        durationMs: 3000,
      ));
      verify(() => analytics.logEvent(
            name: 'tutorial_completed',
            parameters: {
              'install_id': 'abc',
              'skipped': 0,
              'duration_ms': 3000,
            },
          )).called(1);
    });

    test('PurchaseMade → logEvent with 4-field payload (B4)', () {
      logger.log(const PurchaseMade(
        installId: 'abc',
        buildingId: 'oven',
        cost: 120,
        ownedAfter: 3,
      ));
      verify(() => analytics.logEvent(
            name: 'purchase_made',
            parameters: {
              'install_id': 'abc',
              'building_id': 'oven',
              'cost': 120,
              'owned_after': 3,
            },
          )).called(1);
    });

    test('UpgradePurchased → logEvent with 3-field payload (B4)', () {
      logger.log(const UpgradePurchased(
        installId: 'abc',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      ));
      verify(() => analytics.logEvent(
            name: 'upgrade_purchased',
            parameters: {
              'install_id': 'abc',
              'upgrade_id': 'golden_recipe_i',
              'cost': 200,
            },
          )).called(1);
    });

    test('TutorialStarted isReplay=true → coerced to int 1 (B4)', () {
      logger.log(const TutorialStarted(installId: 'abc', isReplay: true));
      verify(() => analytics.logEvent(
            name: 'tutorial_started',
            parameters: {'install_id': 'abc', 'is_replay': 1},
          )).called(1);
    });

    test('TutorialStarted isReplay=false → coerced to int 0 (B4)', () {
      logger.log(const TutorialStarted(installId: 'abc', isReplay: false));
      verify(() => analytics.logEvent(
            name: 'tutorial_started',
            parameters: {'install_id': 'abc', 'is_replay': 0},
          )).called(1);
    });
  });

  group('FirebaseAnalyticsLogger — beginSession/endSession no-op', () {
    test('beginSession does not call any analytics method', () {
      logger.beginSession();
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });

    test('endSession does not call any analytics method', () {
      logger.endSession();
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });
  });

  group('FirebaseAnalyticsLogger — Firebase compliance invariant', () {
    // B2 event'lerinin (SessionStart B3'te genişler, T6) name invariant'ı.
    // B4: SessionStart + PurchaseMade + UpgradePurchased eklendi.
    final events = <TelemetryEvent>[
      const AppInstall(installId: 'x', platform: 'ios'),
      const SessionStart(installId: 'x', sessionId: 'y', installIdAgeMs: 0),
      const SessionEnd(installId: 'x', sessionId: 'y', durationMs: 0),
      const TutorialStarted(installId: 'x', isReplay: false),
      const TutorialCompleted(installId: 'x', skipped: false, durationMs: 0),
      const PurchaseMade(
        installId: 'x',
        buildingId: 'crumb_collector',
        cost: 15,
        ownedAfter: 1,
      ),
      const UpgradePurchased(
        installId: 'x',
        upgradeId: 'golden_recipe_i',
        cost: 200,
      ),
    ];

    final nameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
    const reservedPrefixes = ['firebase_', 'google_', 'ga_'];

    for (final event in events) {
      test('${event.eventName} matches Firebase name regex', () {
        expect(
          nameRegex.hasMatch(event.eventName),
          isTrue,
          reason: '${event.eventName} Firebase regex ihlal ediyor',
        );
      });

      test('${event.eventName} has no reserved prefix', () {
        for (final prefix in reservedPrefixes) {
          expect(
            event.eventName.startsWith(prefix),
            isFalse,
            reason:
                '${event.eventName} reserved prefix "$prefix" kullanıyor',
          );
        }
      });
    }
  });
}
