import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    try {
      final uri = Uri.parse(Uri.base.toString());
      await _supabase.auth.getSessionFromUrl(uri);

      // If successful, redirect to the profile loader
      if (mounted) {
        // Use this method instead of context.go()
        GoRouter.of(context).go('/profile-loader'); 
      }
    } catch (e) {
      // If it fails (e.g., "Code verifier not found"), we catch it
      if (mounted) {
        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired login session. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Use this method instead of context.go()
        GoRouter.of(context).go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
