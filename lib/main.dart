import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jewelry_nafisa/src/auth/auth_callback_screen.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment-specific .env file
  const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
  final envFile = isDebug ? '.env.local' : '.env.production';
  try {
    await dotenv.load(fileName: envFile);
  } catch (e) {
    debugPrint('Warning: $envFile file not found, skipping dotenv load.');
  }

  // Always prefer --dart-define for production
  final supabaseUrl =
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty
      ? const String.fromEnvironment('SUPABASE_URL')
      : dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey =
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      ).isNotEmpty
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Validate that we have the required values
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase URL and Anon Key must be provided');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Wrap the app in the provider
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProfileProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Designs by AKD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, 
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/auth-callback': (context) => const AuthCallbackScreen(),
      },
    );
  }
}