import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabaseClient;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
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
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _profileSubscription?.cancel();

    _profileSubscription = _supabaseClient
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            _updateFromData(data.first);
            final currentCode = data.first['referral_code'] as String?;
            if (currentCode == null || !currentCode.startsWith('AKD-')) {
              generateAndSaveReferralCode();
            }
          }
        });
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
    final newCode = 'AKD-$randomPart';

    try {
      await _supabaseClient
          .from('users')
          .update({'referral_code': newCode})
          .eq('id', userId);
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
      await _supabaseClient.storage
          .from('avatars')
          .uploadBinary(
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
