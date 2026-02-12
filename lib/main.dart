// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'main_screen.dart';
import 'register_page.dart';
import 'profile_page.dart';
import 'services/supabase_service.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const IchambaApp());
}

class IchambaApp extends StatelessWidget {
  const IchambaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ichamba',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SupabaseService.waitForInitialAuth(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final authenticated = snap.data == true;
        if (authenticated) {
          return const MainScreen();
        }
        return const LoginPage();
      },
    );
  }
}
