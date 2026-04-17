// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_strings.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppStringsTr extends AppStrings {
  AppStringsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Crumbs';

  @override
  String get tapHint => 'Cupcake\'e dokun, Crumbs kazan';

  @override
  String welcomeBack(String amount, String duration) {
    return 'Yokken $amount Crumb kazandın ($duration)';
  }

  @override
  String offlineCapped(int cap) {
    return 'Çevrim dışı kazanç $cap saate sınırlandı';
  }

  @override
  String get saveRecoveryBackup => 'Son kayıt bozuk, yedekten yüklendi';

  @override
  String get saveRecoveryFresh => 'Kayıt kurtarılamadı, yeni başladı';

  @override
  String get crumbCollectorName => 'Crumb Collector';

  @override
  String get buyButton => 'Satın al';

  @override
  String ownedLabel(int count) {
    return 'Sahip: $count';
  }

  @override
  String get insufficientCrumbs => 'Yetersiz Crumb';

  @override
  String rateLabel(String rate) {
    return 'C/s: $rate';
  }

  @override
  String get navHome => 'Ev';

  @override
  String get navShop => 'Dükkân';

  @override
  String get navUpgrades => 'Yükseltmeler';

  @override
  String get navResearch => 'Araştırma';

  @override
  String get navMore => 'Daha fazla';

  @override
  String get navEvents => 'Olaylar';

  @override
  String get navPrestige => 'Prestige';

  @override
  String get navCollection => 'Koleksiyon';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get navLockUpgradesA => 'Sonraki güncellemede açılır';

  @override
  String get navLockResearch => '15-30 dakika oyun sonrası açılır';

  @override
  String get navLockEvents => 'Yakında';

  @override
  String get navLockPrestige => 'Prestige koşulu sağlandığında açılır';

  @override
  String get navLockCollection => 'Yakında';

  @override
  String get settingsPlaceholder => 'Ayarlar yakında eklenecek';

  @override
  String get goldenRecipeIName => 'Altın Tarif I';

  @override
  String get goldenRecipeIDescription => 'Tüm üretim × 1.5';

  @override
  String get upgradeOwnedBadge => 'Sahip ✓';

  @override
  String get ovenName => 'Fırın';

  @override
  String get bakeryLineName => 'Fırıncılık Hattı';

  @override
  String get errorScreenTitle => 'Beklenmedik bir hata';

  @override
  String get errorScreenBody =>
      'Oyun başlatılamadı. Tekrar denemek ister misin?';

  @override
  String get errorScreenRetry => 'Tekrar dene';
}
