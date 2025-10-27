import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final uri = web.window.location.href;
    await _supabase.auth.getSessionFromUrl(Uri.parse(uri));
    web.window.location.replace('/');
    // try {
    //   await _supabase.auth.getSessionFromUrl(Uri.parse(uri));
    //   web.window.location.replace('/');
    // } catch (e) {
    //   debugPrint('Authentication error: $e');
    //   web.window.location.replace('/login');
    // }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
