import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jewelry_nafisa/src/utils/user_profile_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabaseClient;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  bool _isProfileLoaded = false;
  String _username = 'Guest';
  bool _isMember = false;
  int _creditsRemaining = 0;
  String _role = 'member';
  String _approvalStatus = 'pending';
  String? _referralCode;
  String? _usedReferralCode;

  UserProfileProvider() : _supabaseClient = Supabase.instance.client;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isProfileLoaded => _isProfileLoaded;
  String get username => _username;
  String get role => _role;
  String get approvalStatus => _approvalStatus;
  String? get referralCode => _referralCode;
  String? get usedReferralCode => _usedReferralCode;
  bool get isDesigner => _role == 'designer';
  bool get isApproved => _approvalStatus == 'approved';
  int get creditsRemaining => _creditsRemaining;
  bool get isMember => _isMember;

  void _updateFromData(Map<String, dynamic>? data) {
    if (data == null) {
      reset();
      return;
    }
    _userProfile = data;
    _username = data['username'] ?? 'No Name';
    _isMember = data['is_member'] ?? false;
    _creditsRemaining = data['credits_remaining'] ?? 0;
    _role = data['role'] ?? 'member';
    _approvalStatus = data['approval_status'] ?? 'pending';
    _referralCode = data['referral_code'];
    _usedReferralCode = data['referred_by'];
    _isLoading = false;
    _isProfileLoaded = true;
    notifyListeners();
  }

  // UPDATED METHOD
  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();

    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      reset(); // Use reset to also cancel any lingering subscriptions
      return;
    }

    try {
      // *** FIX: Changed to call the renamed function ***
      // This will now check if the profile exists, relying on the DB trigger for creation.
      await UserProfileUtils.checkUserProfileExists(userId);

      // Step 2: Perform a one-time fetch for immediate data.
      final response = await _supabaseClient
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      // Step 3: Update state with this initial data.
      _updateFromData(response);

      // Step 4: Now, listen for any future real-time changes.
      await _profileSubscription?.cancel();
      _profileSubscription = _supabaseClient
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .listen((data) {
            if (data.isNotEmpty) {
              _updateFromData(data.first);
              final currentCode = data.first['referral_code'] as String?;
              if (currentCode == null || !currentCode.startsWith('DD-')) {
                generateAndSaveReferralCode();
              }
            }
          });
    } catch (e) {
      debugPrint("Error fetching profile, resetting state: $e");
      reset();
    }
  }

  Future<void> generateAndSaveReferralCode() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null || _referralCode != null) return;

    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomPart = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    final newCode = 'DD-$randomPart';

    try {
      await _supabaseClient
          .from('users')
          .update({'referral_code': newCode}).eq('id', userId);
      _referralCode = newCode;
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving referral code: $e");
    }
  }

  Future<String?> _uploadAvatar(XFile avatarFile) async {
    final userId = _supabaseClient.auth.currentUser!.id;
    final fileExt = avatarFile.path.split('.').last;
    final fileName = '$userId.${DateTime.now().toIso8601String()}.$fileExt';
    final filePath = '$userId/$fileName';
    try {
      final bytes = await avatarFile.readAsBytes();
      await _supabaseClient.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: avatarFile.mimeType,
            ),
          );
      return _supabaseClient.storage.from('avatars').getPublicUrl(filePath);
    } catch (e) {
      debugPrint("Error uploading avatar: $e");
      return null;
    }
  }

  Future<Map<String, int>> getQuoteStatistics() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
    try {
      // This assumes an RPC function 'get_user_quote_stats' exists in Supabase.
      // You will need to create this function in your Supabase project's SQL editor.
      final result = await _supabaseClient.rpc(
        'get_user_quote_stats',
        params: {'p_user_id': userId},
      );

      return {
        'total': (result['total'] as int? ?? 0),
        'valid': (result['valid'] as int? ?? 0),
        'expired': (result['expired'] as int? ?? 0),
      };
    } catch (e) {
      debugPrint("Error fetching quote statistics: $e");
      // Return zeroed data on error to prevent the UI from crashing
      return {'total': 0, 'valid': 0, 'expired': 0};
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String phone,
    String? birthdate,
    String? gender,
    XFile? avatarFile,
  }) async {
    final userId = _supabaseClient.auth.currentUser!.id;
    try {
      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(avatarFile);
      }
      final updates = {
        'username': name,
        'phone': phone,
        'birthdate': birthdate?.isNotEmpty == true ? birthdate : null,
        'gender': gender,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
      await _supabaseClient.from('users').update(updates).eq('id', userId);
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
    }
  }

  void reset() {
    _userProfile = null;
    _username = 'Guest';
    _creditsRemaining = 0;
    _isLoading = false;
    _isProfileLoaded = false;
    _role = 'member';
    _approvalStatus = 'pending';
    _referralCode = null;
    _isMember = false;
    _profileSubscription?.cancel();
    notifyListeners();
  }

  void decrementCredit() {
    if (_creditsRemaining > 0) {
      _creditsRemaining--;
      notifyListeners();
    }
  }
}
