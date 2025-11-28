import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/squared_widget.dart';

class LoggedInPage extends StatelessWidget {
  final UserModel userModel;

  const LoggedInPage({super.key, required this.userModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Main"),
        backgroundColor: Colors.redAccent,
      ),
      body: 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.car_rental,
                      label: AppLocalizations.of(context).createRequest,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/create_request");
                      },
                      size: 125.0,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.minor_crash,
                      label: AppLocalizations.of(context).createOffer,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/create_offer");
                      },
                      size: 125,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.local_activity,
                      label: AppLocalizations.of(context).requests,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/active_requests");
                      },
                      size: 125,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.local_offer,
                      label: AppLocalizations.of(context).offers,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/active_offers");
                      },
                      size: 125,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.star,
                      label: AppLocalizations.of(context).starred,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/starred_routes");
                      },
                      size: 125,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconTextTile(
                      icon: Icons.check_box_outlined,
                      label: AppLocalizations.of(context).active,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, "/my_active_resources");
                      },
                      size: 125,
                      backgroundColor: Colors.red.shade300,
                      iconColor: Colors.grey,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      endDrawer: DrawerMenu(userModel: this.userModel),
    );
  }
}
