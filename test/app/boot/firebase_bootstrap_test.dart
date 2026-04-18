import 'package:crumbs/app/boot/firebase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseBootstrap', () {
    test('initial state — isInitialized false', () {
      expect(FirebaseBootstrap.isInitialized, isFalse);
    });

    test('initialize() does not throw even if Firebase platform unavailable',
        () async {
      // Test environment'ta Firebase platform plugin register edilmemiş —
      // initializeApp exception atar. FirebaseBootstrap.initialize try/catch
      // ile yutmalı ve exception atmamalı.
      await expectLater(
        FirebaseBootstrap.initialize,
        returnsNormally,
      );
      // Test env'da phase 1 fail → isInitialized false
      expect(FirebaseBootstrap.isInitialized, isFalse);
    });

    test('isInitialized is static state accessor (sync bool getter)', () {
      final value = FirebaseBootstrap.isInitialized;
      expect(value, isA<bool>());
    });
  });

  // Not: Phase 2/3 full coverage için Firebase.initializeApp mock gerekir
  // (platform interface override). mocktail + firebase_core_platform_interface
  // entegrasyonu kapsamlı ama B3 scope'ta phase 1 fail → isInitialized=false
  // integration test (T14) ile korunur.
}
