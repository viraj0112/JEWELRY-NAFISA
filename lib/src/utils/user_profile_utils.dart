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

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      await _supabase.from('users').insert({
        'id': userId,
        'email': currentUser.email,
        'username':
            currentUser.userMetadata?['username'] ??
            currentUser.email?.split('@')[0] ??
            'User',
        'membership_plan': 'free',
        'is_member': false,
        'credits_remaining': 1,
        'role': currentUser.userMetadata?['role'] ?? 'member', 
      });
      debugPrint('Created new user profile with correct role.');
      return true;
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
      return false;
    }
  }
}