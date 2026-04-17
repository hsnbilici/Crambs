import 'package:crumbs/app/boot/app_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initialize returns ready ProviderContainer', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final container = await AppBootstrap.initialize();
    expect(container, isA<ProviderContainer>());
    container.dispose();
  });
}
