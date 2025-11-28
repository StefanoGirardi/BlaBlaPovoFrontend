// Intermidiate page with two icon buttons to acces active ridees that the current user
// might be correlated to.

import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/squared_widget.dart';

class ActiveRedirect extends StatefulWidget {
  final UserModel userModel;

  const ActiveRedirect({super.key, required this.userModel});
  
  @override
  State<StatefulWidget> createState() => _ActiveRedirectState(userModel: userModel);
}

class _ActiveRedirectState extends State<ActiveRedirect> {
  final UserModel userModel;

  _ActiveRedirectState({required this.userModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppLocalizations.of(context).active}"),
        backgroundColor: Colors.redAccent,
      ),
      endDrawer: DrawerMenu(userModel: userModel),
      body: Row(
        children: [
          Padding(
            padding: EdgeInsetsGeometry.all(8.0),
            child: IconTextTile(
                  icon: Icons.handshake,
                  label: "${AppLocalizations.of(context).requests}",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/my_active_requests");
                  },
                  size: 125.0,
                  backgroundColor: Colors.red.shade300,
                  iconColor: Colors.grey,
                ),
          ),
          Padding(
            padding: EdgeInsetsGeometry.all(8.0),
            child: IconTextTile(
                  icon: Icons.car_rental,
                  label: "${AppLocalizations.of(context).offers}",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/my_active_offers");
                  },
                  size: 125.0,
                  backgroundColor: Colors.red.shade300,
                  iconColor: Colors.grey,
                ),
          )
        ],
      ),
    );
  }
}