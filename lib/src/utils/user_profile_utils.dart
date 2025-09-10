import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileUtils {
  static final SupabaseClient _supabase = Supabase.instance.client;


  static Future<bool> ensureUserProfile(String userId) async {
    try {
      final userProfile = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userProfile != null) {
        debugPrint('User profile already exists');
        return true;
      }
      await _supabase.from('users').insert({
        'id': userId,
        'email': _supabase.auth.currentUser?.email,
        'username':
            _supabase.auth.currentUser?.userMetadata?['username'] ??
            _supabase.auth.currentUser?.email?.split('@')[0] ??
            'User',
        'membership_plan': 'free',
        'is_member': false,
        'credits_remaining': 0,
      });
      debugPrint('Created new user profile');
      return true;
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
      return false;
    }
  }
}
