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
  /// **'Cupcake\'e dokun, Crumbs kazan'**
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

  /// No description provided for @navLockUpgradesA.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki güncellemede açılır'**
  String get navLockUpgradesA;

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
