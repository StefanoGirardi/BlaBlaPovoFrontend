import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_user_flutter_app/routes.dart';
import 'package:provider/provider.dart';
import 'package:multi_user_flutter_app/models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp,]
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => LocaleProvider())
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel>(
      builder: (context, userModel, _) {
        return RoutesState(userModel: userModel);
      },
    );
  }
}
