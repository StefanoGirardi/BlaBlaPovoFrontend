import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @user_login.
  ///
  /// In en, this message translates to:
  /// **'User Login'**
  String get user_login;

  /// No description provided for @orLetter.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get orLetter;

  /// No description provided for @createRequest.
  ///
  /// In en, this message translates to:
  /// **'Create Request'**
  String get createRequest;

  /// No description provided for @createOffer.
  ///
  /// In en, this message translates to:
  /// **'Create Offer'**
  String get createOffer;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @offer.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get offer;

  /// No description provided for @starred.
  ///
  /// In en, this message translates to:
  /// **'Starred Routes'**
  String get starred;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active Rides'**
  String get active;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @startPoint.
  ///
  /// In en, this message translates to:
  /// **'Start Point'**
  String get startPoint;

  /// No description provided for @arrivalPoint.
  ///
  /// In en, this message translates to:
  /// **'Arrival Point'**
  String get arrivalPoint;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick Start Time'**
  String get pickTime;

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set Time'**
  String get setTime;

  /// No description provided for @selectDay.
  ///
  /// In en, this message translates to:
  /// **'Select Day'**
  String get selectDay;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @customizeRoute.
  ///
  /// In en, this message translates to:
  /// **'Customize Route'**
  String get customizeRoute;

  /// No description provided for @saveRoute.
  ///
  /// In en, this message translates to:
  /// **'Save Route'**
  String get saveRoute;

  /// No description provided for @successfulyOffer.
  ///
  /// In en, this message translates to:
  /// **'Offer Created Successfully'**
  String get successfulyOffer;

  /// No description provided for @completeFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete all fields'**
  String get completeFields;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @allTimes.
  ///
  /// In en, this message translates to:
  /// **'All Times'**
  String get allTimes;

  /// No description provided for @nextHour.
  ///
  /// In en, this message translates to:
  /// **'Next Hour'**
  String get nextHour;

  /// No description provided for @next3Hour.
  ///
  /// In en, this message translates to:
  /// **'Next 3 Hours'**
  String get next3Hour;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @noRequest.
  ///
  /// In en, this message translates to:
  /// **'No Request found'**
  String get noRequest;

  /// No description provided for @noOffer.
  ///
  /// In en, this message translates to:
  /// **'No Offer found'**
  String get noOffer;

  /// No description provided for @registerNewRoute.
  ///
  /// In en, this message translates to:
  /// **'Register New Route'**
  String get registerNewRoute;

  /// No description provided for @nameRoute.
  ///
  /// In en, this message translates to:
  /// **'Enter name for the route'**
  String get nameRoute;

  /// No description provided for @routeSaved.
  ///
  /// In en, this message translates to:
  /// **'Route saved as'**
  String get routeSaved;

  /// No description provided for @modifyRoute.
  ///
  /// In en, this message translates to:
  /// **'Modify Route'**
  String get modifyRoute;

  /// No description provided for @deleteOffer.
  ///
  /// In en, this message translates to:
  /// **'Delete Offer'**
  String get deleteOffer;

  /// No description provided for @deleteRequest.
  ///
  /// In en, this message translates to:
  /// **'Delete Request'**
  String get deleteRequest;

  /// No description provided for @requestToTake.
  ///
  /// In en, this message translates to:
  /// **'Request To Take'**
  String get requestToTake;

  /// No description provided for @myRequest.
  ///
  /// In en, this message translates to:
  /// **'My Request'**
  String get myRequest;

  /// No description provided for @myRequests.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get myRequests;

  /// No description provided for @offersToTake.
  ///
  /// In en, this message translates to:
  /// **'Offers To Take'**
  String get offersToTake;

  /// No description provided for @myOffers.
  ///
  /// In en, this message translates to:
  /// **'My Offers'**
  String get myOffers;

  /// No description provided for @myOffer.
  ///
  /// In en, this message translates to:
  /// **'My Offer'**
  String get myOffer;

  /// No description provided for @seatsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Seats Available'**
  String get seatsAvailable;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @openMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openMaps;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @mail.
  ///
  /// In en, this message translates to:
  /// **'Mail'**
  String get mail;

  /// No description provided for @modUsername.
  ///
  /// In en, this message translates to:
  /// **'Modify Username'**
  String get modUsername;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @registerCar.
  ///
  /// In en, this message translates to:
  /// **'Register Car'**
  String get registerCar;

  /// No description provided for @modify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modify;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @renounce.
  ///
  /// In en, this message translates to:
  /// **'Renounce'**
  String get renounce;

  /// No description provided for @take.
  ///
  /// In en, this message translates to:
  /// **'Take'**
  String get take;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @seat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seat;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @passenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @noReqCreated.
  ///
  /// In en, this message translates to:
  /// **'No Requests Created'**
  String get noReqCreated;

  /// No description provided for @noReqAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Requests Available'**
  String get noReqAvailable;

  /// No description provided for @offCreatedSucc.
  ///
  /// In en, this message translates to:
  /// **'Offer created successfully'**
  String get offCreatedSucc;

  /// No description provided for @reqCreatedSucc.
  ///
  /// In en, this message translates to:
  /// **'Request created successfully'**
  String get reqCreatedSucc;

  /// No description provided for @routeSavedSucc.
  ///
  /// In en, this message translates to:
  /// **'Route saved successfully'**
  String get routeSavedSucc;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @nameForRoute.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this route'**
  String get nameForRoute;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @tooFarFromRouteErr.
  ///
  /// In en, this message translates to:
  /// **'Selected location is too far from the route. Please choose a location closer to the route.'**
  String get tooFarFromRouteErr;

  /// No description provided for @modStopsSucc.
  ///
  /// In en, this message translates to:
  /// **'Stops modified successfully!'**
  String get modStopsSucc;

  /// No description provided for @modStopsErr.
  ///
  /// In en, this message translates to:
  /// **'Failed to modify stops'**
  String get modStopsErr;

  /// No description provided for @seatRenSucc.
  ///
  /// In en, this message translates to:
  /// **'Seat renounced successfully!'**
  String get seatRenSucc;

  /// No description provided for @seatRenErr.
  ///
  /// In en, this message translates to:
  /// **'Failed to renounce seat'**
  String get seatRenErr;

  /// No description provided for @modStops.
  ///
  /// In en, this message translates to:
  /// **'Modify Your Stops'**
  String get modStops;

  /// No description provided for @offDet.
  ///
  /// In en, this message translates to:
  /// **'Offer Details'**
  String get offDet;

  /// No description provided for @gotSeat.
  ///
  /// In en, this message translates to:
  /// **'You have a seat in this offer'**
  String get gotSeat;

  /// No description provided for @notGotSeat.
  ///
  /// In en, this message translates to:
  /// **'You are not a passenger in this offer'**
  String get notGotSeat;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @extTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival'**
  String get extTime;

  /// No description provided for @yourStops.
  ///
  /// In en, this message translates to:
  /// **'Your Stops'**
  String get yourStops;

  /// No description provided for @othersStops.
  ///
  /// In en, this message translates to:
  /// **'Others Stops'**
  String get othersStops;

  /// No description provided for @modStopBanner1.
  ///
  /// In en, this message translates to:
  /// **'Tap on a stop number below to select which stop to modify, then tap on the map to place it'**
  String get modStopBanner1;

  /// No description provided for @modStopBanner2.
  ///
  /// In en, this message translates to:
  /// **'Now tap on the map to place Stop'**
  String get modStopBanner2;

  /// No description provided for @modStopBanner3.
  ///
  /// In en, this message translates to:
  /// **'Use the Modify Stops button to change your stop locations'**
  String get modStopBanner3;

  /// No description provided for @renounceSeatBanner.
  ///
  /// In en, this message translates to:
  /// **'You can modify your stops or renounce your seat entirely'**
  String get renounceSeatBanner;

  /// No description provided for @swapStops.
  ///
  /// In en, this message translates to:
  /// **'Swap Stops'**
  String get swapStops;

  /// No description provided for @backToOff.
  ///
  /// In en, this message translates to:
  /// **'Back To Offers'**
  String get backToOff;

  /// No description provided for @backToReq.
  ///
  /// In en, this message translates to:
  /// **'Back To Requests'**
  String get backToReq;

  /// No description provided for @offTakenSucc.
  ///
  /// In en, this message translates to:
  /// **'You are set up for your ride'**
  String get offTakenSucc;

  /// No description provided for @reviewOff.
  ///
  /// In en, this message translates to:
  /// **'Review Offer'**
  String get reviewOff;

  /// No description provided for @searchPick.
  ///
  /// In en, this message translates to:
  /// **'Search Pickup'**
  String get searchPick;

  /// No description provided for @searchDrop.
  ///
  /// In en, this message translates to:
  /// **'Search DropOff'**
  String get searchDrop;

  /// No description provided for @takeReqBanner.
  ///
  /// In en, this message translates to:
  /// **'Please select pickup, dropoff locations and a route'**
  String get takeReqBanner;

  /// No description provided for @reqAccSucc.
  ///
  /// In en, this message translates to:
  /// **'Request accepted successfully!'**
  String get reqAccSucc;

  /// No description provided for @reqAccFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept request'**
  String get reqAccFail;

  /// No description provided for @delReqBanner.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this request? This action cannot be undone.'**
  String get delReqBanner;

  /// No description provided for @reqDelSucc.
  ///
  /// In en, this message translates to:
  /// **'Request deleted successfully!'**
  String get reqDelSucc;

  /// No description provided for @reqDelFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete request'**
  String get reqDelFail;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @requestedTime.
  ///
  /// In en, this message translates to:
  /// **'Requested time'**
  String get requestedTime;

  /// No description provided for @selRoute.
  ///
  /// In en, this message translates to:
  /// **'Selected Route'**
  String get selRoute;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @reqSelBanner1.
  ///
  /// In en, this message translates to:
  /// **'Pickup location selected. Now choose your drop-off point.'**
  String get reqSelBanner1;

  /// No description provided for @reqSelBanner2.
  ///
  /// In en, this message translates to:
  /// **'Route selected! Ready to accept the request.'**
  String get reqSelBanner2;

  /// No description provided for @acceptReq.
  ///
  /// In en, this message translates to:
  /// **'Accept Request'**
  String get acceptReq;

  /// No description provided for @noStopSel.
  ///
  /// In en, this message translates to:
  /// **'No stops selected for modification'**
  String get noStopSel;

  /// No description provided for @tapMap.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to select your new'**
  String get tapMap;

  /// No description provided for @failedUpd.
  ///
  /// In en, this message translates to:
  /// **'Failed to update'**
  String get failedUpd;

  /// No description provided for @succUpd.
  ///
  /// In en, this message translates to:
  /// **'updated successfully'**
  String get succUpd;

  /// No description provided for @reqRevBanner1.
  ///
  /// In en, this message translates to:
  /// **'New start point set. Confirm or cancel modification'**
  String get reqRevBanner1;

  /// No description provided for @reqRevBanner2.
  ///
  /// In en, this message translates to:
  /// **'New arrival point set. Confirm or cancel modification'**
  String get reqRevBanner2;

  /// No description provided for @reqRevBanner3.
  ///
  /// In en, this message translates to:
  /// **'Error loading user info'**
  String get reqRevBanner3;

  /// No description provided for @reqRevBanner4.
  ///
  /// In en, this message translates to:
  /// **'Driver resigned successfully!'**
  String get reqRevBanner4;

  /// No description provided for @reqRevBanner5.
  ///
  /// In en, this message translates to:
  /// **'Failed to resign!'**
  String get reqRevBanner5;

  /// No description provided for @reqRevBanner6.
  ///
  /// In en, this message translates to:
  /// **'Resign from Request'**
  String get reqRevBanner6;

  /// No description provided for @reqRevBanner7.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to resign as driver? This action cannot be undone.'**
  String get reqRevBanner7;

  /// No description provided for @reqRevBanner8.
  ///
  /// In en, this message translates to:
  /// **'My Assigned Requests'**
  String get reqRevBanner8;

  /// No description provided for @resign.
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get resign;

  /// No description provided for @userInfo.
  ///
  /// In en, this message translates to:
  /// **'UserInfo'**
  String get userInfo;

  /// No description provided for @waypoints.
  ///
  /// In en, this message translates to:
  /// **'Waypoints'**
  String get waypoints;

  /// No description provided for @waipoint.
  ///
  /// In en, this message translates to:
  /// **'Waypoint'**
  String get waipoint;

  /// No description provided for @starBanner1.
  ///
  /// In en, this message translates to:
  /// **'Done Reordering'**
  String get starBanner1;

  /// No description provided for @starBanner2.
  ///
  /// In en, this message translates to:
  /// **'Reorder Waypoints'**
  String get starBanner2;

  /// No description provided for @starBanner3.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder waypoints'**
  String get starBanner3;

  /// No description provided for @starBanner5.
  ///
  /// In en, this message translates to:
  /// **'Tap on map to add waypoint'**
  String get starBanner5;

  /// No description provided for @starBanner4.
  ///
  /// In en, this message translates to:
  /// **'(click to remove)'**
  String get starBanner4;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
