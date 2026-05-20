import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

import '../features/auth/presentation/create_store_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/main/presentation/main_shell_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'voicenote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/create-store': (_) => const CreateStoreScreen(),
        '/main': (_) => const MainShellScreen(),
      },
      initialRoute: '/',
    );
  }
}

