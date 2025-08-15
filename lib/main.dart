import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import "package:supabase_flutter/supabase_flutter.dart";
import "package:jewelry_nafisa/src/auth/signup_screen.dart";
import 'firebase_options.dart';
// import 'package:jewelry_nafisa/src/ui/screens/home/home_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Get variables from the compile-time environment
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Initialize Supabase with the variables
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
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
      // home:const SignUpScreen(),
    );
  }
}
