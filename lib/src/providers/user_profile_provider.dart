import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- REQUIRED IMPORT
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

// --- Local Storage Keys ---
abstract class LocalKeys {
  static const String onboardingStage = 'onboarding_stage_key'; // Stores int (1, 2, 3)
  static const String isSetupComplete = 'onboarding_complete_key'; // Stores bool
  
  // Data collected during the flow (if needed)
  static const String country = 'onboarding_country'; 
  static const String zipCode = 'onboarding_region'; 
  static const String occasions = 'onboarding_occasions'; 
  static const String categories = 'onboarding_categories'; 
}

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  // --- Existing Getters ---
  Set<String> _unlockedItemIds = {};
  bool isItemUnlocked(String itemId) => _unlockedItemIds.contains(itemId);
  String get username => _userProfile?.username ?? '';
  bool get isMember => _userProfile?.isMember ?? false;
  int get creditsRemaining => _userProfile?.credits ?? 0;
  String? get referralCode => _userProfile?.referralCode;
  String get userId => _userProfile?.id ?? '';

// --------------------------------------------------------------------------
// --- Onboarding Status Getters ---
// --------------------------------------------------------------------------
  int get onboardingStage => _userProfile?.onboardingStage ?? 0;
  bool get isSetupComplete => _userProfile?.isSetupComplete ?? false;

// --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getQuoteHistory() async {
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

// --------------------------------------------------------------------------
// --- MODIFIED: loadUserProfile to read from local storage ---
// --------------------------------------------------------------------------

  Future<void> loadUserProfile() async {
    if (_supabase.auth.currentUser == null) return;
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();

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

      // 1. Process user profile (initial load from DB)
      final profileData = responses[0] as Map<String, dynamic>;
      _userProfile = UserProfile.fromMap(profileData); // Loads data from Supabase

      // 2. --- Override with Local Onboarding State ---
      final int localStage = prefs.getInt(LocalKeys.onboardingStage) ?? 0;
      final bool localComplete = prefs.getBool(LocalKeys.isSetupComplete) ?? false;
      
      // Override if the DB state shows incomplete and local data exists.
      if (_userProfile!.isSetupComplete == false && (localStage > 0 || localComplete == true)) {
        
        // Retrieve all collected data from local storage
        final String? localCountry = prefs.getString(LocalKeys.country);
        final String? localZipCode = prefs.getString(LocalKeys.zipCode);
        final List<String> localOccasions = prefs.getStringList(LocalKeys.occasions) ?? [];
        final Set<String> localCategories = (prefs.getStringList(LocalKeys.categories) ?? []).toSet();

        // Create a new UserProfile object with local data to resume the flow.
        _userProfile = _userProfile!.copyWith(
          onboardingStage: localStage,
          isSetupComplete: localComplete,
          country: localCountry,
          zipCode: localZipCode,
          selectedOccasions: localOccasions,
selectedCategories: (localCategories?.toList() ?? _userProfile!.selectedCategories),        );
      }

      // 3. Process unlocked items (unchanged)
      final unlockedData = responses[1] as List<dynamic>;
      _unlockedItemIds =
          unlockedData.map((e) => e['item_id'] as String).toSet();
      
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      _userProfile = null;
      _unlockedItemIds = {};
    } finally {
      notifyListeners();
    }
  }


  // This function just updates local state.
  void decrementCredit() {
    if (_userProfile != null && _userProfile!.credits > 0) {
      // NOTE: Using copyWith here for cleaner state update
      _userProfile = _userProfile!.copyWith(
        credits: _userProfile!.credits - 1,
      );
      // Note: notifyListeners() will be called by the parent function
    }
  }

  // --- Core logic function for spending a credit (UNCHANGED) ---
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
      rethrow;
    }
  }

// --------------------------------------------------------------------------
// --- NEW: saveOnboardingData (Writes to Local Storage) ---
// --------------------------------------------------------------------------

/// Saves the collected data for the current step and advances the stage counter
/// using local storage.
Future<void> saveOnboardingData({
  String? country,
  String? zipCode,
  List<String>? occasions,
  Set<String>? categories,
  required bool isFinalSubmission,
}) async {
  if (_userProfile == null) {
    throw Exception('User profile not loaded or authenticated.');
  }

  // 1. Get the local storage instance
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // ✅ FIXED: Automatic stage progression
  final currentStage = _userProfile!.onboardingStage;
  final nextStage = isFinalSubmission ? 3 : (currentStage < 3 ? currentStage + 1 : currentStage);
  
  try {
    // 2. --- Write Collected Data to Local Storage ---
    if (country != null) await prefs.setString(LocalKeys.country, country);
    if (zipCode != null) await prefs.setString(LocalKeys.zipCode, zipCode);
    if (occasions != null) await prefs.setStringList(LocalKeys.occasions, occasions);
    if (categories != null) await prefs.setStringList(LocalKeys.categories, categories.toList());

    // 3. --- Write Stage and Completion Flags ---
    await prefs.setInt(LocalKeys.onboardingStage, nextStage);
    if (isFinalSubmission) {
      await prefs.setBool(LocalKeys.isSetupComplete, true);
    }

    // 4. --- Update Local Profile State and Notify Listeners ---
    _userProfile = _userProfile!.copyWith(
      onboardingStage: nextStage,
      isSetupComplete: isFinalSubmission,
      // Update collected data fields
      country: country ?? _userProfile!.country,
      zipCode: zipCode ?? _userProfile!.zipCode,
      selectedOccasions: occasions ?? _userProfile!.selectedOccasions,
      selectedCategories: categories?.toList() ?? _userProfile!.selectedCategories,
    );

    notifyListeners();
    
  } catch (e) {
    debugPrint('Error saving onboarding data to local storage: $e');
    rethrow;
  }
}

// --------------------------------------------------------------------------
// --- NEW: finalizeOnboardingMigration (Supabase WRITE DISABLED) ---
// --------------------------------------------------------------------------

/// FINAL STEP: Writes collected local data to Supabase and clears local cache.
/// *SUPABASE WRITE IS CURRENTLY DISABLED BECAUSE SCHEMA IS UNAVAILABLE.*
Future<void> finalizeOnboardingMigration() async {
  if (_userProfile == null || _userProfile!.isSetupComplete == false) {
    throw Exception("Onboarding not yet complete or user not loaded.");
  }

  // NOTE: userId is still needed for future implementation
  final userId = _userProfile!.id; 

  try {
    // 1. Construct the final updates map from the current local profile state
    // (Kept for future reference when Supabase is updated)
    final updates = {
      'country': _userProfile!.country,
      'zipCode': _userProfile!.zipCode,
      'occasions': _userProfile!.selectedOccasions,
      'jewelry_categories': _userProfile!.selectedCategories.toList(),
      'setup_complete': true,
      'setup_stage': 3,
    };

    // 2. ❌ TEMPORARILY DISABLED: Supabase write operation is removed. ❌
    // await _supabase
    //     .from('users') 
    //     .update(updates)
    //     .eq('id', userId);

    // 3. Clear the local storage cache for onboarding
    await clearOnboardingLocalData();
    
    // 4. The router will now rely on _userProfile!.isSetupComplete being true 
    // (set in saveOnboardingData) and the local cache being cleared.
    // We don't need to call loadUserProfile here as we didn't write to the DB.

  } catch (e) {
    debugPrint('Error finalizing onboarding migration: $e');
    rethrow;
  }
}

/// Helper function to clear all local onboarding keys.
Future<void> clearOnboardingLocalData() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove(LocalKeys.onboardingStage);
  await prefs.remove(LocalKeys.isSetupComplete);
  await prefs.remove(LocalKeys.country);
  await prefs.remove(LocalKeys.zipCode);
  await prefs.remove(LocalKeys.occasions);
  await prefs.remove(LocalKeys.categories);
}
// --------------------------------------------------------------------------

  void updateCredits(int newCredits) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(
        credits: newCredits,
      );
      notifyListeners();
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
    clearOnboardingLocalData(); // Clear local onboarding state on logout/reset
    notifyListeners();
  }
}
