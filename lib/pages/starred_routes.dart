import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:multi_user_flutter_app/l10n/app_localizations.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:multi_user_flutter_app/widgets/drawer_menu.dart';
import 'package:multi_user_flutter_app/widgets/map_widget.dart';
import 'package:provider/provider.dart';

class RouteCard extends StatelessWidget {
  final String routeName;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.routeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Text(routeName),
          ],
        ),
      ),
    );
  }
}

class RoutePage extends StatefulWidget {
  UserModel userModel;

  RoutePage({
    super.key,
    required this.userModel,
  });

  @override
  State<RoutePage> createState() => RoutePageState(userModel: this.userModel);
}

class RoutePageState extends State<RoutePage> {
  UserModel userModel;

  RoutePageState({
    required this.userModel,
  });

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("${AppLocalizations.of(context).starred}"),
      ),
      endDrawer: DrawerMenu(userModel: userModel),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children:
                  userModel.currentUser!.starredRoutes!.entries.map((entry) {
                final routeKey = entry.key;
                final routeData = entry.value;
                final routeName = routeData["name"] ?? routeKey;
                final List<dynamic> points = routeData!['route'] ?? [];
                final latLngs = points
                    .map((p) => LatLng(
                          (p['lat'] as num).toDouble(),
                          (p['lng'] as num).toDouble(),
                        ))
                    .toList();

                return RouteCard(
                  routeName: routeName,
                  onTap: () {
                    Navigator.pop(context); 
                    Navigator.pushNamed(
                      context,
                      '/starred_route_details',
                      arguments: [latLngs,routeName],
                    );
                  },
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: () => {
              Navigator.pop(context),
              Navigator.pushNamed(
                context,
                '/new_starred_route',
              )
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text("${AppLocalizations.of(context).registerNewRoute}"),
          ),
        ],
      ),
    );
  }
}
