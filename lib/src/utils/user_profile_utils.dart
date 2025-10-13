import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileUtils {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // This function's only job is now to check if the profile exists.
  // The database trigger you created handles the actual creation logic.
  static Future<bool> checkUserProfileExists(String userId) async {
    try {
      final userProfile = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile != null) {
        debugPrint('User profile found.');
        return true;
      } else {
        debugPrint('User profile not found yet. The database trigger will handle it.');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking user profile: $e');
      return false;
    }
  }
}