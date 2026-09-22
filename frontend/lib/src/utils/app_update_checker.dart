// package:universal_html rather than dart:html. A bare dart:html import is
// unavailable on the Dart VM, so it broke compilation of every widget test
// that reaches main.dart -> MainShell -> this mixin, and it is deprecated in
// favour of package:web. universal_html is already this project's cross-
// platform shim (main.dart uses it) and ships a VM implementation, so the
// mixin now compiles under flutter test while behaving identically on web.
import 'package:universal_html/html.dart' as html;
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
