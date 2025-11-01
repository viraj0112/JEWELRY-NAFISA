import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        GoRouter.of(context).go('/home');
      }
    } catch (e) {
      if (mounted) {
        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Dagina Designs!'),
            backgroundColor: Colors.green,
          ),
        );

        GoRouter.of(context).go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
