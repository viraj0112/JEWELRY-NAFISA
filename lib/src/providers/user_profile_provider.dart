import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

// --- Local Storage Keys ---
abstract class LocalKeys {
  static const String onboardingStage = 'onboarding_stage_key'; 
  static const String isSetupComplete = 'onboarding_complete_key'; 
  
  static const String country = 'onboarding_country'; 
  static const String zipCode = 'onboarding_region'; 
  static const String occasions = 'onboarding_occasions'; 
  static const String categories = 'onboarding_categories'; 
  static const String phone = 'onboarding_phone'; 
  static const String gender = 'onboarding_gender'; 
  static const String age = 'onboarding_age';
}

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  Set<String> _unlockedItemIds = {};
  bool isItemUnlocked(String itemId) => _unlockedItemIds.contains(itemId);
  String get username => _userProfile?.username ?? '';
  bool get isMember => _userProfile?.isMember ?? false;
  int get creditsRemaining => _userProfile?.credits ?? 0;
  String? get referralCode => _userProfile?.referralCode;
  String get userId => _userProfile?.id ?? '';

  int get onboardingStage => _userProfile?.onboardingStage ?? 0;
  bool get isSetupComplete => _userProfile?.isSetupComplete ?? false;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --------------------------------------------------------------------------
  // --- Profile Loading with Local Data Sync ---
  // --------------------------------------------------------------------------

  Future<void> loadUserProfile() async {
    if (_supabase.auth.currentUser == null) {
      print('❌ loadUserProfile: No current user');
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final userId = _supabase.auth.currentUser!.id;
      print('📥 Loading profile for user: $userId');

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

      final profileData = responses[0] as Map<String, dynamic>;
      _userProfile = UserProfile.fromMap(profileData);
      print('✅ Profile loaded from DB: ${_userProfile!.username}');

      // --- Override with Local Storage ---
      final int localStage = prefs.getInt(LocalKeys.onboardingStage) ?? 0;
      final bool localComplete = prefs.getBool(LocalKeys.isSetupComplete) ?? false;
      
      print('📦 Local storage - stage: $localStage, complete: $localComplete');
      print('📦 DB storage - stage: ${_userProfile!.onboardingStage}, complete: ${_userProfile!.isSetupComplete}');
      
      if (localComplete || localStage > _userProfile!.onboardingStage) {
         _userProfile = _userProfile!.copyWith(
           onboardingStage: localStage,
           isSetupComplete: localComplete,
           // RESTORING AGE/GENDER/LOCATION FROM LOCAL
           age: prefs.getInt(LocalKeys.age) ?? _userProfile!.age,
           gender: prefs.getString(LocalKeys.gender) ?? _userProfile!.gender,
           country: prefs.getString(LocalKeys.country) ?? _userProfile!.country,
           zipCode: prefs.getString(LocalKeys.zipCode) ?? _userProfile!.zipCode,
           phone: prefs.getString(LocalKeys.phone) ?? _userProfile!.phone,
         );
         print('✅ Profile updated with local storage data');
      }
      
      final unlockedData = responses[1] as List<dynamic>;
      _unlockedItemIds = unlockedData.map((e) => e['item_id'] as String).toSet();
      print('✅ Loaded ${_unlockedItemIds.length} unlocked items');
      
    } catch (e) {
      debugPrint("❌ Error loading user profile: $e");
      _userProfile = null;
      _unlockedItemIds = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------------------
  // --- Onboarding Save Logic (Supports 5 Stages) ---
  // --------------------------------------------------------------------------

  Future<void> saveOnboardingData({
    String? country,
    String? zipCode,
    String? phone,
    List<String>? occasions,
    Set<String>? categories,
    int? age,
    String? gender,
    required bool isFinalSubmission,
  }) async {
    if (_userProfile == null) throw Exception('Profile not loaded.');

    final userId = _userProfile!.id;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // PROGRESSION LOGIC (UP TO 5)
    final currentStage = _userProfile!.onboardingStage;
    final nextStage = isFinalSubmission ? 5 : (currentStage < 5 ? currentStage + 1 : currentStage);
    
    print('💾 Saving onboarding - current: $currentStage, next: $nextStage, final: $isFinalSubmission');
    
    try {
      // 1. Write to Local Storage
      if (country != null) await prefs.setString(LocalKeys.country, country);
      if (zipCode != null) await prefs.setString(LocalKeys.zipCode, zipCode);
      if (phone != null) await prefs.setString(LocalKeys.phone, phone);
      if (occasions != null) await prefs.setStringList(LocalKeys.occasions, occasions);
      if (categories != null) await prefs.setStringList(LocalKeys.categories, categories.toList());
      if (gender != null) await prefs.setString(LocalKeys.gender, gender);    
      if (age != null) await prefs.setInt(LocalKeys.age, age);

      await prefs.setInt(LocalKeys.onboardingStage, nextStage);
      if (isFinalSubmission) await prefs.setBool(LocalKeys.isSetupComplete, true);

      // 2. Update Local Profile State (Provider)
      _userProfile = _userProfile!.copyWith(
        onboardingStage: nextStage,
        isSetupComplete: isFinalSubmission,
        country: country ?? _userProfile!.country,
        zipCode: zipCode ?? _userProfile!.zipCode,
        phone: phone ?? _userProfile!.phone,
        selectedOccasions: occasions ?? _userProfile!.selectedOccasions,
        selectedCategories: categories?.toList() ?? _userProfile!.selectedCategories,
        age: age ?? _userProfile!.age,  
        gender: gender ?? _userProfile!.gender
      );

      notifyListeners();

      // 3. Write to Supabase
      final Map<String, dynamic> updates = {
        'setup_stage': nextStage,
        if (isFinalSubmission) 'setup_complete': true,
        if (country != null) 'country': country,
        if (zipCode != null) 'zip_code': zipCode,
        if (phone != null) 'phone': phone,
        if (occasions != null) 'occasions': occasions,
        if (categories != null) 'jewelry_categories': categories.toList(),
        if (gender != null) 'gender': gender,
        if (age != null) 'age': age 
      };

      await _supabase.from('users').update(updates).eq('id', userId);
      print('✅ Onboarding data saved to Supabase');
      
    } catch (e) {
      debugPrint('❌ Error saving onboarding: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // --- Cleanup & Finalization ---
  // --------------------------------------------------------------------------

  Future<void> finalizeOnboardingMigration() async {
    if (_userProfile == null || _userProfile!.isSetupComplete == false) return;

    try {
      await _supabase.from('users').update({
        'setup_complete': true,
        'setup_stage': 5,
      }).eq('id', _userProfile!.id);

      await clearOnboardingLocalData();
    } catch (e) {
      debugPrint('Error finalizing onboarding: $e');
      rethrow;
    }
  }

  Future<void> clearOnboardingLocalData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(LocalKeys.onboardingStage),
      prefs.remove(LocalKeys.isSetupComplete),
      prefs.remove(LocalKeys.country),
      prefs.remove(LocalKeys.zipCode),
      prefs.remove(LocalKeys.phone),
      prefs.remove(LocalKeys.occasions),
      prefs.remove(LocalKeys.categories),
      prefs.remove(LocalKeys.gender),
      prefs.remove(LocalKeys.age),
    ]);
  }

  // --------------------------------------------------------------------------
  // --- Remaining Business Logic (Credits, Profile Update, Stats) ---
  // --------------------------------------------------------------------------

  void updateCredits(int newCredits) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(credits: newCredits);
      notifyListeners();
    }
  }

  void decrementCredit() {
    if (_userProfile != null && _userProfile!.credits > 0) {
      _userProfile = _userProfile!.copyWith(credits: _userProfile!.credits - 1);
    }
  }

  Future<void> spendCreditToUnlockItem(String itemId) async {
    if (_userProfile == null || _userProfile!.credits <= 0 || isItemUnlocked(itemId)) return;
    final userId = _userProfile!.id;
    final newCredits = _userProfile!.credits - 1;

    try {
      await _supabase.from('users').update({'credits': newCredits}).eq('id', userId);
      await _supabase.from('user_unlocked_items').insert({'user_id': userId, 'item_id': itemId});
      decrementCredit();
      _unlockedItemIds.add(itemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error spending credit: $e');
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
    final userId = _supabase.auth.currentUser!.id;
    String? avatarUrl;

    if (avatarFile != null) {
      final bytes = await avatarFile.readAsBytes();
      final fileName = '$userId/avatar.${avatarFile.path.split('.').last}';
      await _supabase.storage.from('avatars').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
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

  Future<List<Map<String, dynamic>>> getQuoteHistory() async {
    if (_supabase.auth.currentUser == null) throw Exception('Not authenticated');
    final response = await _supabase.from('quotes').select().eq('user_id', _supabase.auth.currentUser!.id).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> getQuoteStatistics() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'total': 0, 'valid': 0, 'expired': 0};
    try {
      final response = await _supabase.rpc('get_user_quote_statistics', params: {'p_user_id': userId});
      return Map<String, int>.from(response[0]);
    } catch (e) {
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
  }

  Future<void> requestBusinessAccount() async {
    if (_userProfile == null) throw Exception("User not loaded");
    await _supabase.from('users').update({'role': 'designer', 'is_approved': false}).eq('id', _userProfile!.id);
    await loadUserProfile();
  }

  void reset() {
    print('🔄 Resetting UserProfileProvider');
    _userProfile = null;
    _unlockedItemIds = {};
    clearOnboardingLocalData();
    notifyListeners();
  }
}