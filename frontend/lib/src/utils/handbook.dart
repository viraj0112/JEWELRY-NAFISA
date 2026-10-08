import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The role handbook is a static page shipped from `web/handbook.html`, so
/// Flutter copies it into `build/web/` and it is served beside the app.
///
/// On web it resolves against the current origin (works on localhost, Netlify
/// previews and production alike); native builds use the production site.
Uri get handbookUri => kIsWeb
    ? Uri.base.resolve('/handbook.html')
    : Uri.parse('https://www.dagina.design/handbook.html');

/// The handbook link for [role]: `?role=<role>` limits the page to that
/// role's guide. Admins support every role, so they get the whole handbook.
Uri handbookUriFor(UserRole? role) {
  if (role == null || role == UserRole.admin) return handbookUri;
  return handbookUri.replace(queryParameters: {'role': role.name});
}

/// Opens the signed-in user's handbook in a new browser tab (or the system
/// browser on mobile).
Future<void> openHandbook(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final role = Provider.of<UserProfileProvider>(context, listen: false)
      .userProfile
      ?.role;
  final opened = await launchUrl(
    handbookUriFor(role),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Could not open the handbook.')),
    );
  }
}
