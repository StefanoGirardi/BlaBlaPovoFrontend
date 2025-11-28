import 'package:flutter/material.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';

class DrawerMenu extends StatelessWidget {
  final UserModel userModel;

  const DrawerMenu({super.key, required this.userModel});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration:
                BoxDecoration(color: const Color.fromARGB(156, 244, 67, 8)),
            child: Text('Menu',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            onTap: () {
              Navigator.popUntil(context,ModalRoute.withName('/'));
              Navigator.pushNamed(context, '/home_page');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.popUntil(context,ModalRoute.withName('/'));
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('History'),
            onTap: () {
              Navigator.popUntil(context,ModalRoute.withName('/'));
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: Icon(Icons.key_off_outlined),
            title: Text('Logout'),
            onTap: () async {
              userModel.logout();
              Navigator.pop(context);
              await Future.delayed(Duration(milliseconds: 50));
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
