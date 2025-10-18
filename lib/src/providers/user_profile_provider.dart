import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String get username => _userProfile?.username ?? '';
  bool get isMember => _userProfile?.isMember ?? false;
  int get creditsRemaining => _userProfile?.credits ?? 0;
  String? get referralCode => _userProfile?.referralCode;

  Future<List<Map<String, dynamic>>> getQuoteHistory() async {
    // FIX: Changed _supabaseClient to _supabase
    if (_supabase.auth.currentUser == null) {
      throw Exception('Not authenticated');
    }
    // FIX: Changed _supabaseClient to _supabase
    final userId = _supabase.auth.currentUser!.id;
    
    try {
      // FIX: Changed _supabaseClient to _supabase
      final response = await _supabase
          .from('quotes') 
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching quote history: $e');
      rethrow;
    }
  }

  Future<void> loadUserProfile() async {
    if (_supabase.auth.currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser!.id;
      final data =
          await _supabase.from('users').select().eq('id', userId).single();
      _userProfile = UserProfile.fromMap(data);
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void decrementCredit() {
    if (_userProfile != null && _userProfile!.credits > 0) {
      _userProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        username: _userProfile!.username,
        role: _userProfile!.role,
        isApproved: _userProfile!.isApproved,
        credits: _userProfile!.credits - 1,
        referralCode: _userProfile!.referralCode,
        avatarUrl: _userProfile!.avatarUrl,
        isMember: _userProfile!.isMember,
      );
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String phone,
    required String birthdate,
    String? gender,
    XFile? avatarFile,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    String? avatarUrl;

    if (avatarFile != null) {
      final bytes = await avatarFile.readAsBytes();
      final fileExt = avatarFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      await _supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      avatarUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
    }

    final updates = {
      'username': name,
      'phone': phone,
      'birthdate': birthdate,
      'gender': gender,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    await _supabase.from('users').update(updates).eq('id', userId);
    await loadUserProfile();
  }

  Future<Map<String, int>> getQuoteStatistics() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
    try {
      final response = await _supabase
          .rpc('get_user_quote_statistics', params: {'p_user_id': userId});
      final data = response[0];
      return Map<String, int>.from(data);
    } catch (e) {
      debugPrint('Error fetching quote statistics: $e');
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
  }

  void reset() {
    _userProfile = null;
    notifyListeners();
  }
}