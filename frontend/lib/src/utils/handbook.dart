import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The role handbook is a static page shipped from `web/handbook.html`, so
/// Flutter copies it into `build/web/` and it is served beside the app.
///
/// On web it resolves against the current origin (works on localhost, Netlify
/// previews and production alike); native builds use the production site.
Uri get handbookUri => kIsWeb
    ? Uri.base.resolve('/handbook.html')
    : Uri.parse('https://www.dagina.design/handbook.html');

/// Opens the handbook in a new browser tab (or the system browser on mobile).
Future<void> openHandbook(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await launchUrl(
    handbookUri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Could not open the handbook.')),
    );
  }
}
