import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart'; // Import provider
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart'; // Import provider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
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
    );
  }
}