import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MSG91 OTP Service
//
// This service acts as a thin client-side bridge that calls two Supabase
// Edge Functions:
//   • send-otp   → calls MSG91 REST API to deliver OTP via SMS
//   • verify-otp → validates the OTP entered by the user
//
// Credentials (server-side only — NEVER in the Flutter bundle):
//   Set these in your Supabase project via:
//     supabase secrets set MSG91_AUTH_KEY=<your_key>
//     supabase secrets set MSG91_SENDER_ID=<e.g. DAGINA>
//     supabase secrets set MSG91_TEMPLATE_ID=<your_template_id>
//
//  TODO: ADD MSG91 CREDENTIALS:
//    1. Log in to https://msg91.com/in/sms
//    2. Go to: API Keys → Generate Auth Key  → paste as MSG91_AUTH_KEY
//    3. Go to: SMS → Sender ID               → paste as MSG91_SENDER_ID (e.g. DAGINA)
//    4. Go to: SMS → Templates → OTP template → copy Template ID → MSG91_TEMPLATE_ID
//    5. Run: supabase secrets set MSG91_AUTH_KEY=xxx MSG91_SENDER_ID=xxx MSG91_TEMPLATE_ID=xxx
//    6. Deploy edge functions: supabase functions deploy send-otp
//                              supabase functions deploy verify-otp
// ─────────────────────────────────────────────────────────────────────────────

enum OtpResult {
  success,
  alreadySent, // MSG91: OTP already sent, please wait
  invalidPhone,
  networkError,
  unknownError,
}

enum OtpVerifyResult {
  success,
  invalid, // Wrong OTP
  expired, // OTP has expired
  networkError,
  unknownError,
}

class Msg91OtpService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sends an OTP to [phoneNumber].
  /// [phoneNumber] must be in E.164 format, e.g. "+919876543210"
  Future<OtpResult> sendOtp(String phoneNumber) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-otp',
        body: {'phone': phoneNumber},
      );

      if (response.status == 200) {
        return OtpResult.success;
      }

      // Parse MSG91 error messages
      final body = response.data;
      final message = (body is Map ? body['message'] : body.toString())
          .toString()
          .toLowerCase();

      if (message.contains('already sent') || message.contains('wait')) {
        return OtpResult.alreadySent;
      }
      if (message.contains('invalid mobile') ||
          message.contains('invalid number')) {
        return OtpResult.invalidPhone;
      }

      debugPrint('[MSG91] sendOtp error: $body');
      return OtpResult.unknownError;
    } catch (e) {
      debugPrint('[MSG91] sendOtp exception: $e');
      return OtpResult.networkError;
    }
  }

  /// Verifies [otp] for [phoneNumber].
  /// Returns [OtpVerifyResult.success] on match, otherwise an error enum.
  Future<OtpVerifyResult> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _supabase.functions.invoke(
        'verify-otp',
        body: {'phone': phoneNumber, 'otp': otp},
      );

      if (response.status == 200) {
        return OtpVerifyResult.success;
      }

      final body = response.data;
      final message = (body is Map ? body['message'] : body.toString())
          .toString()
          .toLowerCase();

      if (message.contains('invalid') || message.contains('mismatch')) {
        return OtpVerifyResult.invalid;
      }
      if (message.contains('expir')) {
        return OtpVerifyResult.expired;
      }

      debugPrint('[MSG91] verifyOtp error: $body');
      return OtpVerifyResult.unknownError;
    } catch (e) {
      debugPrint('[MSG91] verifyOtp exception: $e');
      return OtpVerifyResult.networkError;
    }
  }

  /// Resends the OTP by calling sendOtp again (MSG91 handles rate limiting).
  Future<OtpResult> resendOtp(String phoneNumber) => sendOtp(phoneNumber);
}
