// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mixin that adds update-notification behaviour to any [StatefulWidget].
///
/// Usage:
///   class _MyShellState extends State<MyShell> with AppUpdateChecker {
///     @override
///     void initState() {
///       super.initState();
///       registerUpdateListener();
///     }
///   }
mixin AppUpdateChecker<T extends StatefulWidget> on State<T> {
  /// Call this from your [initState].
  void registerUpdateListener() {
    if (!kIsWeb) return;
    html.window.on['app_update_available'].listen((_) {
      if (mounted) _showUpdateBanner();
    });
  }

  void _showUpdateBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 365), // persistent until dismissed
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF1A3C2A),
        content: Row(
          children: [
            const Icon(Icons.system_update_alt,
                color: Color(0xFFB8860B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '✨ A new version is available!',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'REFRESH',
          textColor: const Color(0xFFB8860B),
          onPressed: () {
            // Force reload bypassing cache
            html.window.location.reload();
          },
        ),
      ),
    );
  }
}
