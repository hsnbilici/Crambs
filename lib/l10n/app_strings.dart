import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_strings_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppStrings
/// returned by `AppStrings.of(context)`.
///
/// Applications need to include `AppStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppStrings.localizationsDelegates,
///   supportedLocales: AppStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppStrings.supportedLocales
/// property.
abstract class AppStrings {
  AppStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppStrings? of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Crumbs'**
  String get appTitle;

  /// No description provided for @tapHint.
  ///
  /// In tr, this message translates to:
  /// **'Fırına dokun, Crumb kazan'**
  String get tapHint;

  /// No description provided for @welcomeBack.
  ///
  /// In tr, this message translates to:
  /// **'Yokken {amount} Crumb kazandın ({duration})'**
  String welcomeBack(String amount, String duration);

  /// No description provided for @offlineCapped.
  ///
  /// In tr, this message translates to:
  /// **'Çevrim dışı kazanç {cap} saate sınırlandı'**
  String offlineCapped(int cap);

  /// No description provided for @saveRecoveryBackup.
  ///
  /// In tr, this message translates to:
  /// **'Son kayıt bozuk, yedekten yüklendi'**
  String get saveRecoveryBackup;

  /// No description provided for @saveRecoveryFresh.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt kurtarılamadı, yeni başladı'**
  String get saveRecoveryFresh;

  /// No description provided for @crumbCollectorName.
  ///
  /// In tr, this message translates to:
  /// **'Crumb Collector'**
  String get crumbCollectorName;

  /// No description provided for @buyButton.
  ///
  /// In tr, this message translates to:
  /// **'Satın al'**
  String get buyButton;

  /// No description provided for @ownedLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sahip: {count}'**
  String ownedLabel(int count);

  /// No description provided for @insufficientCrumbs.
  ///
  /// In tr, this message translates to:
  /// **'Yetersiz Crumb'**
  String get insufficientCrumbs;

  /// No description provided for @rateLabel.
  ///
  /// In tr, this message translates to:
  /// **'C/s: {rate}'**
  String rateLabel(String rate);

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ev'**
  String get navHome;

  /// No description provided for @navShop.
  ///
  /// In tr, this message translates to:
  /// **'Dükkân'**
  String get navShop;

  /// No description provided for @navUpgrades.
  ///
  /// In tr, this message translates to:
  /// **'Yükseltmeler'**
  String get navUpgrades;

  /// No description provided for @navResearch.
  ///
  /// In tr, this message translates to:
  /// **'Araştırma'**
  String get navResearch;

  /// No description provided for @navMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get navMore;

  /// No description provided for @navEvents.
  ///
  /// In tr, this message translates to:
  /// **'Olaylar'**
  String get navEvents;

  /// No description provided for @navPrestige.
  ///
  /// In tr, this message translates to:
  /// **'Prestige'**
  String get navPrestige;

  /// No description provided for @navCollection.
  ///
  /// In tr, this message translates to:
  /// **'Koleksiyon'**
  String get navCollection;

  /// No description provided for @navSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get navSettings;

  /// No description provided for @navLockResearch.
  ///
  /// In tr, this message translates to:
  /// **'15-30 dakika oyun sonrası açılır'**
  String get navLockResearch;

  /// No description provided for @navLockEvents.
  ///
  /// In tr, this message translates to:
  /// **'Yakında'**
  String get navLockEvents;

  /// No description provided for @navLockPrestige.
  ///
  /// In tr, this message translates to:
  /// **'Prestige koşulu sağlandığında açılır'**
  String get navLockPrestige;

  /// No description provided for @navLockCollection.
  ///
  /// In tr, this message translates to:
  /// **'Yakında'**
  String get navLockCollection;

  /// No description provided for @settingsPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar yakında eklenecek'**
  String get settingsPlaceholder;

  /// No description provided for @goldenRecipeIName.
  ///
  /// In tr, this message translates to:
  /// **'Altın Tarif I'**
  String get goldenRecipeIName;

  /// No description provided for @goldenRecipeIDescription.
  ///
  /// In tr, this message translates to:
  /// **'Tüm üretim × 1.5'**
  String get goldenRecipeIDescription;

  /// No description provided for @upgradeOwnedBadge.
  ///
  /// In tr, this message translates to:
  /// **'Sahip ✓'**
  String get upgradeOwnedBadge;

  /// No description provided for @ovenName.
  ///
  /// In tr, this message translates to:
  /// **'Fırın'**
  String get ovenName;

  /// No description provided for @bakeryLineName.
  ///
  /// In tr, this message translates to:
  /// **'Fırıncılık Hattı'**
  String get bakeryLineName;

  /// No description provided for @errorScreenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmedik bir hata'**
  String get errorScreenTitle;

  /// No description provided for @errorScreenBody.
  ///
  /// In tr, this message translates to:
  /// **'Oyun başlatılamadı. Tekrar denemek ister misin?'**
  String get errorScreenBody;

  /// No description provided for @errorScreenRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get errorScreenRetry;

  /// No description provided for @tutorialStep1Message.
  ///
  /// In tr, this message translates to:
  /// **'Crumb kazanmak için fırına dokun!'**
  String get tutorialStep1Message;

  /// No description provided for @tutorialStep2NavMessage.
  ///
  /// In tr, this message translates to:
  /// **'Dükkân\'a git ve ilk üreticini al'**
  String get tutorialStep2NavMessage;

  /// No description provided for @tutorialStep2ShopMessage.
  ///
  /// In tr, this message translates to:
  /// **'Crumb Collector\'ı satın al'**
  String get tutorialStep2ShopMessage;

  /// No description provided for @tutorialStep3Title.
  ///
  /// In tr, this message translates to:
  /// **'Neden Crumb kazanıyorsun?'**
  String get tutorialStep3Title;

  /// No description provided for @tutorialStep3Body.
  ///
  /// In tr, this message translates to:
  /// **'Binaların otomatik olarak saniyede Crumb üretir. Daha fazla satın al, daha hızlı büyü!'**
  String get tutorialStep3Body;

  /// No description provided for @tutorialSkipButton.
  ///
  /// In tr, this message translates to:
  /// **'Geç'**
  String get tutorialSkipButton;

  /// No description provided for @tutorialCloseButton.
  ///
  /// In tr, this message translates to:
  /// **'Anladım'**
  String get tutorialCloseButton;

  /// No description provided for @settingsAudioSection.
  ///
  /// In tr, this message translates to:
  /// **'Ses ve Müzik'**
  String get settingsAudioSection;

  /// No description provided for @settingsAudioMusicToggle.
  ///
  /// In tr, this message translates to:
  /// **'Müzik'**
  String get settingsAudioMusicToggle;

  /// No description provided for @settingsAudioSfxToggle.
  ///
  /// In tr, this message translates to:
  /// **'Efektler'**
  String get settingsAudioSfxToggle;

  /// No description provided for @settingsAudioMasterVolume.
  ///
  /// In tr, this message translates to:
  /// **'Genel Ses'**
  String get settingsAudioMasterVolume;

  /// No description provided for @sessionRecapTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yokken kazandın!'**
  String get sessionRecapTitle;

  /// No description provided for @sessionRecapEarned.
  ///
  /// In tr, this message translates to:
  /// **'{amount} Crumb'**
  String sessionRecapEarned(String amount);

  /// No description provided for @sessionRecapElapsed.
  ///
  /// In tr, this message translates to:
  /// **'{duration} boyunca'**
  String sessionRecapElapsed(String duration);

  /// No description provided for @sessionRecapCapped.
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat sınırına ulaşıldı'**
  String sessionRecapCapped(int hours);

  /// No description provided for @sessionRecapMultiplier.
  ///
  /// In tr, this message translates to:
  /// **'Pasif çarpan: ×{value}'**
  String sessionRecapMultiplier(String value);

  /// No description provided for @sessionRecapCollect.
  ///
  /// In tr, this message translates to:
  /// **'Topla'**
  String get sessionRecapCollect;

  /// No description provided for @sessionRecapDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get sessionRecapDismiss;

  /// No description provided for @settingsDevSection.
  ///
  /// In tr, this message translates to:
  /// **'Geliştirici'**
  String get settingsDevSection;

  /// No description provided for @settingsDevTestCrash.
  ///
  /// In tr, this message translates to:
  /// **'Test Crash Gönder'**
  String get settingsDevTestCrash;

  /// No description provided for @settingsDevTestCrashHint.
  ///
  /// In tr, this message translates to:
  /// **'Crashlytics doğrulama — cihaz yeniden açıldığında rapor gönderilir'**
  String get settingsDevTestCrashHint;

  /// No description provided for @settingsDevTestCrashNotInit.
  ///
  /// In tr, this message translates to:
  /// **'Firebase başlatılmadı — crash rapor edilmez'**
  String get settingsDevTestCrashNotInit;

  /// No description provided for @settingsDevTutorialReplay.
  ///
  /// In tr, this message translates to:
  /// **'Tutorial\'i Tekrar Oyna'**
  String get settingsDevTutorialReplay;

  /// No description provided for @settingsDevTutorialReplayHint.
  ///
  /// In tr, this message translates to:
  /// **'3 adımlı girişi yeniden başlatır'**
  String get settingsDevTutorialReplayHint;

  /// No description provided for @settingsDevTutorialReplayDialogTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tutorial yeniden oynatılsın mı?'**
  String get settingsDevTutorialReplayDialogTitle;

  /// No description provided for @settingsDevTutorialReplayDialogBody.
  ///
  /// In tr, this message translates to:
  /// **'İlerlemen (binalar, upgrade\'ler, Crumbs) kaybolmaz. Yalnız tutorial adımları yeniden gösterilir.'**
  String get settingsDevTutorialReplayDialogBody;

  /// No description provided for @settingsDevTutorialReplayCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get settingsDevTutorialReplayCancel;

  /// No description provided for @settingsDevTutorialReplayConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Evet, yeniden oyna'**
  String get settingsDevTutorialReplayConfirm;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(lookupAppStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

AppStrings lookupAppStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppStringsTr();
  }

  throw FlutterError(
    'AppStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
