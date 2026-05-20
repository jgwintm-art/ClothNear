import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer_home_screen.dart';
import 'screens/owner_home_screen.dart';
import 'screens/worker_home_screen.dart';
import 'models/user_model.dart';
import 'screens/force_password_change_screen.dart';
import 'config/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClothNear',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/worker-set-password': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as UserModel;
          return ForcePasswordChangeScreen(user);
        },
        '/': (context) => const LoginScreen(),
        '/customer-home': (context) => const CustomerHomeScreen(),
        '/owner-home': (context) => const OwnerHomeScreen(),
        '/worker-home': (context) => const WorkerHomeScreen(),
      },
    );
  }
}
