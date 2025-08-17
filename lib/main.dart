import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart'; // Import provider
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load();
  
  // Get Supabase URL and Anon Key with fallback to environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? const String.fromEnvironment('SUPABASE_ANON_KEY');
  
  // Validate that we have the required values
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase URL and Anon Key must be provided');
  }
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthGate(),
      // home: HomeScreen(),
    );
  }
}