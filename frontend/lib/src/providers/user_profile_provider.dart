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
  UserProfileProvider({SupabaseClient? client}) : _injectedClient = client;

  /// Set only by tests. Production constructs this with no argument and gets
  /// the global client.
  final SupabaseClient? _injectedClient;

  /// Resolved lazily, on use rather than at construction.
  ///
  /// This was `final _supabase = Supabase.instance.client`, a field
  /// initialiser - so merely calling `UserProfileProvider()` asserted that
  /// Supabase.initialize() had already run. That made the provider impossible
  /// to construct in a unit test, and it is why referral_screen_test could
  /// never get past setUp() even though it had a perfectly good mock client
  /// ready to pass in.
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  Set<String> _unlockedItemIds = {};
  bool isItemUnlocked(String itemId) => _unlockedItemIds.contains(itemId);
  String get username => _userProfile?.username ?? '';

  /// The name to show for the user: their full name, else their username.
  String get displayName {
    final fullName = _userProfile?.fullName?.trim() ?? '';
    return fullName.isNotEmpty ? fullName : username;
  }

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
      return;
    }

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final userId = _supabase.auth.currentUser!.id;

      // Deliberately NOT combined with the unlocked-items query below. These
      // used to share a Future.wait, so a failure on the secondary query - and
      // `user_unlocked_items` does not exist in the migrations at all - took
      // the profile down with it. ProfileLoader awaits this before routing, so
      // that turned a missing side table into "the app never gets past login".
      final profileData = await _supabase
          .from('users')
          .select('*, designer_profiles(*), manufacturer_profiles(*)')
          .eq('id', userId)
          .maybeSingle();

      if (profileData == null) {
        throw StateError('No public.users row for $userId');
      }
      debugPrint('🔍 ProfileData keys: ${profileData.keys}');
      debugPrint('🔍 ProfileData role field: ${profileData['role']}');
      debugPrint('🔍 Full profileData: $profileData');

      try {
        _userProfile = UserProfile.fromMap(profileData);

        debugPrint('✅ UserProfile created successfully');
        debugPrint('✅ UserProfile.role: ${_userProfile?.role}');
        debugPrint(
            '✅ UserProfile.designerProfile: ${_userProfile?.designerProfile}');
        debugPrint(
            '✅ UserProfile.manufacturerProfile: ${_userProfile?.manufacturerProfile}');
      } catch (e) {
        debugPrint('❌ Error creating UserProfile: $e');
        rethrow;
      }
      // --- Override with Local Storage ---
      final int localStage = prefs.getInt(LocalKeys.onboardingStage) ?? 0;
      final bool localComplete =
          prefs.getBool(LocalKeys.isSetupComplete) ?? false;

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
      }

      // Best-effort: an unavailable unlocked-items table degrades the
      // "already revealed" markers, it must not block signing in.
      try {
        final unlockedData = await _supabase
            .from('user_unlocked_items')
            .select('item_id')
            .eq('user_id', userId) as List<dynamic>;
        _unlockedItemIds =
            unlockedData.map((e) => e['item_id'] as String).toSet();
      } catch (e) {
        debugPrint('Could not load unlocked items (continuing): $e');
        _unlockedItemIds = {};
      }
    } catch (e) {
      _userProfile = null;
      _unlockedItemIds = {};
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
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
    final nextStage = isFinalSubmission
        ? 5
        : (currentStage < 5 ? currentStage + 1 : currentStage);

    try {
      // 1. Write to Local Storage
      if (country != null) await prefs.setString(LocalKeys.country, country);
      if (zipCode != null) await prefs.setString(LocalKeys.zipCode, zipCode);
      if (phone != null) await prefs.setString(LocalKeys.phone, phone);
      if (occasions != null) {
        await prefs.setStringList(LocalKeys.occasions, occasions);
      }
      if (categories != null) {
        await prefs.setStringList(LocalKeys.categories, categories.toList());
      }
      if (gender != null) await prefs.setString(LocalKeys.gender, gender);
      if (age != null) await prefs.setInt(LocalKeys.age, age);

      await prefs.setInt(LocalKeys.onboardingStage, nextStage);
      if (isFinalSubmission) {
        await prefs.setBool(LocalKeys.isSetupComplete, true);
      }

      // 2. Update Local Profile State (Provider)
      _userProfile = _userProfile!.copyWith(
          onboardingStage: nextStage,
          isSetupComplete: isFinalSubmission,
          country: country ?? _userProfile!.country,
          zipCode: zipCode ?? _userProfile!.zipCode,
          phone: phone ?? _userProfile!.phone,
          selectedOccasions: occasions ?? _userProfile!.selectedOccasions,
          selectedCategories:
              categories?.toList() ?? _userProfile!.selectedCategories,
          age: age ?? _userProfile!.age,
          gender: gender ?? _userProfile!.gender);

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
    } catch (e) {
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

  void deductCredits(int amount) {
    if (_userProfile != null && _userProfile!.credits >= amount) {
      _userProfile =
          _userProfile!.copyWith(credits: _userProfile!.credits - amount);
      notifyListeners();
    }
  }

  void syncCredits(int remainingCredits) {
    if (_userProfile != null) {
      _userProfile = _userProfile!.copyWith(credits: remainingCredits);
      notifyListeners();
    }
  }

  Future<void> spendCreditToUnlockItem(String itemId) async {
    if (_userProfile == null ||
        _userProfile!.credits <= 0 ||
        isItemUnlocked(itemId)) {
      return;
    }
    final userId = _userProfile!.id;
    final newCredits = _userProfile!.credits - 1;

    try {
      await _supabase
          .from('users')
          .update({'credits': newCredits}).eq('id', userId);
      await _supabase
          .from('user_unlocked_items')
          .insert({'user_id': userId, 'item_id': itemId});
      decrementCredit();
      _unlockedItemIds.add(itemId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Saves the Edit Profile form.
  ///
  /// Only fields that changed are written, and a cleared field is stored as
  /// null (Postgres rejects '' for the `date` birthdate column). The name goes
  /// to `full_name`: `username` is a unique handle, so two people choosing the
  /// same display name made the whole save fail.
  ///
  /// The picture is uploaded on its own. If that fails the other changes are
  /// still saved, and an [AvatarUploadException] says what went wrong.
  Future<void> updateUserProfile({
    required String name,
    required String phone,
    DateTime? birthdate,
    String? bio,
    String? gender,
    XFile? avatarFile,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final current = _userProfile;

    String? orNull(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    String? isoDate(DateTime? date) =>
        date?.toIso8601String().substring(0, 10); // yyyy-MM-dd

    final updates = <String, dynamic>{};
    void changed(String column, Object? value, Object? previous) {
      if (value != previous) updates[column] = value;
    }

    changed('full_name', orNull(name), current?.fullName);
    changed('phone', orNull(phone), current?.phone);
    changed('birthdate', isoDate(birthdate), isoDate(current?.birthdate));
    changed('gender', orNull(gender), current?.gender);
    changed('bio', orNull(bio), current?.bio);

    Object? avatarError;
    if (avatarFile != null) {
      try {
        updates['avatar_url'] = await _uploadAvatar(userId, avatarFile);
      } catch (e) {
        debugPrint('Avatar upload failed: $e');
        avatarError = e;
      }
    }

    if (updates.isNotEmpty) {
      // RLS turns a refused update into "0 rows changed" rather than an
      // error, so ask for the row back to tell the two apart.
      final saved = await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select('id');
      if (saved.isEmpty) {
        throw Exception('You do not have permission to update this profile.');
      }
    }
    await loadUserProfile();

    if (avatarError != null) throw AvatarUploadException(avatarError);
  }

  /// Uploads [file] as the user's picture and returns its public URL.
  Future<String> _uploadAvatar(String userId, XFile file) async {
    // Use the file name, not the path: on web the path is a blob: URL with
    // no extension.
    final name = file.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    var ext = dot == -1 ? '' : name.substring(dot + 1);
    if (!const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      ext = 'jpg';
    }
    final path = '$userId/avatar.$ext';
    final storage = _supabase.storage.from('avatars');
    await storage.uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: FileOptions(
        upsert: true,
        contentType: file.mimeType ?? 'image/${ext == 'jpg' ? 'jpeg' : ext}',
      ),
    );
    // The path never changes, so version the URL or the old picture stays in
    // the image cache.
    return '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<Map<String, dynamic>>> getQuoteHistory() async {
    if (_supabase.auth.currentUser == null) {
      throw Exception('Not authenticated');
    }
    final response = await _supabase
        .from('quotes')
        .select()
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> getQuoteStatistics() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'total': 0, 'valid': 0, 'expired': 0};
    try {
      final response = await _supabase
          .rpc('get_user_quote_statistics', params: {'p_user_id': userId});
      return Map<String, int>.from(response[0]);
    } catch (e) {
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
  }

  Future<void> requestBusinessAccount() async {
    if (_userProfile == null) throw Exception("User not loaded");
    await _supabase.from('users').update(
        {'role': 'designer', 'is_approved': false}).eq('id', _userProfile!.id);
    await loadUserProfile();
  }

  void reset() {
    _userProfile = null;
    _unlockedItemIds = {};
    clearOnboardingLocalData();
    notifyListeners();
  }
}

/// The profile was saved, but the new picture could not be uploaded.
class AvatarUploadException implements Exception {
  AvatarUploadException(this.cause);

  final Object cause;

  @override
  String toString() => 'Your profile was saved, but the photo could not be '
      'uploaded: $cause';
}
