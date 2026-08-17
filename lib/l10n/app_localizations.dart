import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @homeDeliveryTo.
  ///
  /// In en, this message translates to:
  /// **'Delivery to'**
  String get homeDeliveryTo;

  /// No description provided for @homePopularStalls.
  ///
  /// In en, this message translates to:
  /// **'Popular Stalls'**
  String get homePopularStalls;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products, stalls...'**
  String get searchHint;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping Cart'**
  String get cartTitle;

  /// No description provided for @cartProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get cartProceed;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Start adding items from the market'**
  String get cartEmptyHint;

  /// No description provided for @cartDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to {address}'**
  String cartDeliverTo(String address);

  /// No description provided for @cartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get cartTotal;

  /// No description provided for @cartCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get cartCheckout;

  /// No description provided for @cartMaxStock.
  ///
  /// In en, this message translates to:
  /// **'Maximum stock reached'**
  String get cartMaxStock;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @proceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get proceed;

  /// No description provided for @checkoutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutSectionTitle;

  /// No description provided for @deliveryAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddressTitle;

  /// No description provided for @paymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodTitle;

  /// No description provided for @orderSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummaryTitle;

  /// No description provided for @orderNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Notes / Instructions'**
  String get orderNotesTitle;

  /// No description provided for @notesForVendor.
  ///
  /// In en, this message translates to:
  /// **'Notes for {vendorName}'**
  String notesForVendor(String vendorName);

  /// No description provided for @summarySubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get summarySubtotal;

  /// No description provided for @summaryDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get summaryDeliveryFee;

  /// No description provided for @feeFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get feeFree;

  /// No description provided for @summaryPriorityFee.
  ///
  /// In en, this message translates to:
  /// **'Priority Delivery Fee'**
  String get summaryPriorityFee;

  /// No description provided for @summaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get summaryTotal;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @codSelected.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery selected'**
  String get codSelected;

  /// No description provided for @gcashSelected.
  ///
  /// In en, this message translates to:
  /// **'GCash selected'**
  String get gcashSelected;

  /// No description provided for @cardSelected.
  ///
  /// In en, this message translates to:
  /// **'Card selected'**
  String get cardSelected;

  /// No description provided for @paymentMethodUpdated.
  ///
  /// In en, this message translates to:
  /// **'Payment method updated'**
  String get paymentMethodUpdated;

  /// No description provided for @deliveryMethod.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryMethod;

  /// No description provided for @pickupMethod.
  ///
  /// In en, this message translates to:
  /// **'Pick-Up'**
  String get pickupMethod;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
