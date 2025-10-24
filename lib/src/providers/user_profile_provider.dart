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

  // --- NEW: Set to store unlocked item IDs ---
  Set<String> _unlockedItemIds = {};

  // --- NEW: Public getter to check unlock status ---
  bool isItemUnlocked(String itemId) => _unlockedItemIds.contains(itemId);

  String get username => _userProfile?.username ?? '';
  bool get isMember => _userProfile?.isMember ?? false;
  int get creditsRemaining => _userProfile?.credits ?? 0;
  String? get referralCode => _userProfile?.referralCode;

  Future<List<Map<String, dynamic>>> getQuoteHistory() async {
    // ... (rest of the function is unchanged)
    if (_supabase.auth.currentUser == null) {
      throw Exception('Not authenticated');
    }
    final userId = _supabase.auth.currentUser!.id;

    try {
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

      final responses = await Future.wait<dynamic>([
        _supabase
            .from('users')
            .select('*, designer_profiles(*)')
            .eq('id', userId)
            .single() as Future<dynamic>,
        _supabase
            .from('user_unlocked_items')
            .select('item_id')
            .eq('user_id', userId) as Future<dynamic>,
      ]);

      // Process user profile
      final profileData = responses[0] as Map<String, dynamic>;
      _userProfile = UserProfile.fromMap(profileData);

      // Process unlocked items
      final unlockedData = responses[1] as List<dynamic>;
      _unlockedItemIds =
          unlockedData.map((e) => e['item_id'] as String).toSet();
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      _userProfile = null;
      _unlockedItemIds = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // This function just updates local state.
  // We'll call this from our new 'spendCreditToUnlockItem' function.
  void decrementCredit() {
    if (_userProfile != null && _userProfile!.credits > 0) {
      _userProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        username: _userProfile!.username,
        role: _userProfile!.role,
        isApproved: _userProfile!.isApproved,
        credits: _userProfile!.credits - 1, // Decrement
        referralCode: _userProfile!.referralCode,
        avatarUrl: _userProfile!.avatarUrl,
        isMember: _userProfile!.isMember,
        bio: _userProfile!.bio,
        fullName: _userProfile!.fullName,
        birthdate: _userProfile!.birthdate,
        gender: _userProfile!.gender,
        phone: _userProfile!.phone,
        membershipPlan: _userProfile!.membershipPlan,
        lastCreditRefresh: _userProfile!.lastCreditRefresh,
        referredBy: _userProfile!.referredBy,
        createdAt: _userProfile!.createdAt,
        designerProfile: _userProfile!.designerProfile,
      );
      // Note: notifyListeners() will be called by the parent function
    }
  }

  // --- NEW: Core logic function for spending a credit ---
  Future<void> spendCreditToUnlockItem(String itemId) async {
    if (_userProfile == null) {
      throw Exception('User profile not loaded.');
    }
    if (_userProfile!.credits <= 0) {
      throw Exception('No credits remaining.');
    }
    if (isItemUnlocked(itemId)) {
      throw Exception('Item already unlocked.');
    }

    final userId = _userProfile!.id;
    final newCredits = _userProfile!.credits - 1;

    try {
      // 1. Update the credit count in the database
      await _supabase
          .from('users')
          .update({'credits': newCredits}).eq('id', userId);

      // 2. Insert the unlock record in the new table
      await _supabase
          .from('user_unlocked_items')
          .insert({'user_id': userId, 'item_id': itemId});

      // 3. Update local state
      decrementCredit(); // Update local credit count
      _unlockedItemIds.add(itemId); // Add to local unlock set

      notifyListeners(); // Notify all listeners of the changes
    } catch (e) {
      debugPrint('Error spending credit: $e');
      // If error, we don't update local state
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String phone,
    required String birthdate,
    String? bio,
    String? gender,
    XFile? avatarFile,
  }) async {
    // ... (rest of the function is unchanged)
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
      'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    await _supabase.from('users').update(updates).eq('id', userId);
    await loadUserProfile();
  }

  Future<Map<String, int>> getQuoteStatistics() async {
    // ... (rest of the function is unchanged)
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

  Future<void> requestBusinessAccount() async {
    // ... (rest of the function is unchanged)
    if (_userProfile == null) throw Exception("User not loaded");

    final userId = _userProfile!.id;
    try {
      await _supabase.from('users').update({
        'role': 'designer',
        'is_approved': false,
      }).eq('id', userId);

      await loadUserProfile();
    } catch (e) {
      debugPrint('Error requesting business account: $e');
      rethrow;
    }
  }

  void reset() {
    _userProfile = null;
    _unlockedItemIds = {}; // Reset unlocked items
    notifyListeners();
  }
}
