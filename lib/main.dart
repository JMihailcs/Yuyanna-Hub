import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

import 'services/habilidades_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await HabilidadesStore.instance.init();
  runApp(const YuyannaHubApp());
}

class YuyannaHubApp extends StatelessWidget {
  const YuyannaHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yuyanna Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
