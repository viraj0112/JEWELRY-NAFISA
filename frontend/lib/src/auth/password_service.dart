import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when Supabase requires a fresh verification code before it will
/// change the password (the project has `secure_password_change` enabled and
/// the session isn't recent). Call [PasswordService.sendVerificationCode],
/// then retry [PasswordService.setPassword] with the emailed code as `nonce`.
class VerificationRequired implements Exception {
  const VerificationRequired();

  @override
  String toString() => 'A verification code is required to change the password.';
}

/// Setting, changing and recovering the account password.
class PasswordService {
  PasswordService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Set when the user arrives from a "reset password" email link: the router
  /// then sends them to /set-password to choose a new one.
  static bool recoveryPending = false;

  /// user_metadata flag recorded once a Google-created account has chosen a
  /// password. Supabase doesn't add an "email" identity when an OAuth user sets
  /// a password, so the providers list alone can't tell us.
  static const passwordSetFlag = 'password_set';

  /// Whether [user] signed up with Google and has never chosen a password for
  /// this site. Such users are required to create one.
  static bool needsPasswordSetup(User? user) {
    if (user == null) return false;
    if (user.userMetadata?[passwordSetFlag] == true) return false;
    final providers = _providersOf(user);
    if (providers.contains('email')) return false; // signed up with a password
    return providers.contains('google');
  }

  /// Whether the user can already sign in with a password on this site.
  static bool hasPassword(User? user) =>
      user != null && !needsPasswordSetup(user) &&
      (_providersOf(user).contains('email') ||
          user.userMetadata?[passwordSetFlag] == true);

  static List<String> _providersOf(User user) {
    final list = user.appMetadata['providers'];
    if (list is List) return list.map((e) => '$e').toList();
    final single = user.appMetadata['provider'];
    return single == null ? const [] : ['$single'];
  }

  /// Sets (or replaces) the password and records that one exists.
  ///
  /// Throws [VerificationRequired] when Supabase wants a verification code
  /// first; other failures surface as an [AuthException] with a readable
  /// message.
  Future<void> setPassword(String password, {String? nonce}) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(
        password: password,
        nonce: (nonce ?? '').trim().isEmpty ? null : nonce!.trim(),
        data: {passwordSetFlag: true},
      ));
      recoveryPending = false;
    } on AuthException catch (e) {
      final code = e.code ?? '';
      final message = e.message.toLowerCase();
      if (code == 'reauthentication_needed' ||
          message.contains('requires reauthentication')) {
        throw const VerificationRequired();
      }
      if (code == 'same_password') {
        throw AuthException(
            'Choose a password different from your current one.',
            code: code);
      }
      if (code == 'reauthentication_not_valid') {
        throw AuthException(
            'That verification code is incorrect or has expired.',
            code: code);
      }
      rethrow;
    }
  }

  /// Emails the signed-in user a one-time code for [setPassword].
  Future<void> sendVerificationCode() => _supabase.auth.reauthenticate();

  /// Emails a password-reset link. The link signs the user in and the app
  /// takes them to /set-password (see [recoveryPending]).
  Future<void> sendResetEmail(String email) =>
      _supabase.auth.resetPasswordForEmail(email.trim());
}
