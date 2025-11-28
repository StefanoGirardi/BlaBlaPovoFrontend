import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/pages/active_offers.dart';
import 'package:multi_user_flutter_app/pages/active_redirect.dart';
import 'package:multi_user_flutter_app/pages/active_requests.dart';
import 'package:multi_user_flutter_app/pages/create_offer.dart';
import 'package:multi_user_flutter_app/pages/create_request.dart';
import 'package:multi_user_flutter_app/pages/history_pages.dart';
import 'package:multi_user_flutter_app/pages/logged_in_page.dart';
import 'package:multi_user_flutter_app/pages/modify_offer.dart';
import 'package:multi_user_flutter_app/pages/modify_request.dart';
import 'package:multi_user_flutter_app/pages/my_active_offers.dart';
import 'package:multi_user_flutter_app/pages/my_active_request.dart';
import 'package:multi_user_flutter_app/pages/new_starred_route.dart';
import 'package:multi_user_flutter_app/pages/offer_review.dart';
import 'package:multi_user_flutter_app/pages/offers_details.dart';
import 'package:multi_user_flutter_app/pages/request_details.dart';
import 'package:multi_user_flutter_app/pages/request_review.dart';
import 'package:multi_user_flutter_app/pages/starred_route_details.dart';
import 'package:multi_user_flutter_app/pages/starred_routes.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/settings.dart';
import 'pages/history.dart';
// import 'pages/login_page.dart';
import 'models/user_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


const String apiBaseUrl = 'http://localhost:8000';

class RoutesState extends StatelessWidget {
  final UserModel userModel;

  const RoutesState({super.key, required this.userModel});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        // Build routes based on current login state
        final Map<String, WidgetBuilder> appRoutes;
        if (userModel.currentUser == null) {
          appRoutes = {
            '/': (_) => const HomePage(), // show login screen
          };
        } else {
          appRoutes = {
            '/home_page': (_) => LoggedInPage(userModel: userModel),
            '/settings': (_) => Settings(userModel: userModel),
            '/create_request': (_) => CreateRequest(userModel: userModel),
            '/create_offer': (_) => CreateOffer(userModel: userModel),
            '/active_offers': (_) => OffersPage(userModel: userModel),
            '/active_requests': (_) => RequestsPage(userModel: userModel),
            '/my_active_rides': (_) => CreateRequest(userModel: userModel),
            '/offers_details': (_) => OfferDetail(userModel: userModel),
            '/request_details': (_) => RequestDetail(userModel: userModel),
            '/starred_routes': (_) => RoutePage(userModel: userModel),
            '/starred_route_details': (_) => StarredDetails(userModel: userModel),
            '/new_starred_route': (_) => NewStarredRoute(userModel: userModel),
            '/my_active_resources': (_) => ActiveRedirect(userModel: userModel),
            '/my_active_offers': (_) => MyOffersPage(userModel: userModel),
            '/my_active_requests': (_) => MyRequestsPage(userModel: userModel),
            '/modify_offer': (_) => ModifyOffer(userModel: userModel),
            '/modify_request': (_) => ModifyRequest(userModel: userModel),
            '/history': (context) => HistoryPage(userModel: userModel),
            '/request_history': (context) => RequestHistoryPage(userModel: userModel),
            '/offer_history': (context) => OfferHistoryPage(userModel: userModel),
            '/offer_review': (context) => OfferReview(userModel: userModel),
            '/request_review': (context) => RequestReview(userModel: userModel),
          };
        }

        return MaterialApp(
          locale: localeProvider.locale, // Use locale from provider
          initialRoute: userModel.currentUser == null ? '/' : '/home_page',
          routes: appRoutes,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('it'),
          ],
        );
      },
    );
  }
}


class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;
  
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}