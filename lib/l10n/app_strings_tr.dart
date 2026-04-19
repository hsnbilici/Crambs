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
  String get tapHint => 'Fırına dokun, Crumb kazan';

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

  @override
  String get tutorialStep1Message => 'Crumb kazanmak için fırına dokun!';

  @override
  String get tutorialStep2NavMessage => 'Dükkân\'a git ve ilk üreticini al';

  @override
  String get tutorialStep2ShopMessage => 'Crumb Collector\'ı satın al';

  @override
  String get tutorialStep3Title => 'Neden Crumb kazanıyorsun?';

  @override
  String get tutorialStep3Body =>
      'Binaların otomatik olarak saniyede Crumb üretir. Daha fazla satın al, daha hızlı büyü!';

  @override
  String get tutorialSkipButton => 'Geç';

  @override
  String get tutorialCloseButton => 'Anladım';

  @override
  String get settingsAudioSection => 'Ses ve Müzik';

  @override
  String get settingsAudioMusicToggle => 'Müzik';

  @override
  String get settingsAudioSfxToggle => 'Efektler';

  @override
  String get settingsAudioMasterVolume => 'Genel Ses';

  @override
  String get settingsDevSection => 'Geliştirici';

  @override
  String get settingsDevTestCrash => 'Test Crash Gönder';

  @override
  String get settingsDevTestCrashHint =>
      'Crashlytics doğrulama — cihaz yeniden açıldığında rapor gönderilir';

  @override
  String get settingsDevTestCrashNotInit =>
      'Firebase başlatılmadı — crash rapor edilmez';

  @override
  String get settingsDevTutorialReplay => 'Tutorial\'i Tekrar Oyna';

  @override
  String get settingsDevTutorialReplayHint =>
      '3 adımlı girişi yeniden başlatır';

  @override
  String get settingsDevTutorialReplayDialogTitle =>
      'Tutorial yeniden oynatılsın mı?';

  @override
  String get settingsDevTutorialReplayDialogBody =>
      'İlerlemen (binalar, upgrade\'ler, Crumbs) kaybolmaz. Yalnız tutorial adımları yeniden gösterilir.';

  @override
  String get settingsDevTutorialReplayCancel => 'Vazgeç';

  @override
  String get settingsDevTutorialReplayConfirm => 'Evet, yeniden oyna';
}
