import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabaseClient;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String _username = 'Guest';
  String _membershipStatus = 'free';
  String _role = 'member';
  String _approvalStatus = 'pending';
  bool _isMember = false;
  int _creditsRemaining = 0;

  UserProfileProvider() : _supabaseClient = Supabase.instance.client;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String get username => _username;
  String get membershipStatus => _membershipStatus;
  String get role => _role;
  String get approvalStatus => _approvalStatus;
  bool get isDesigner => _role == 'designer';
  bool get isApproved => _approvalStatus == 'approved';
  int get creditsRemaining => _creditsRemaining;
  bool get isMember => _isMember;

  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await _supabaseClient
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      _userProfile = data;
      _username = data['username'] ?? 'No Name';
      _membershipStatus = data['membership_plan'] ?? 'free';
      _creditsRemaining = data['credits_remaining'] ?? 0;
      _role = data['role'] ?? 'member';
      _approvalStatus = data['approval_status'] ?? 'pending';
      _isMember = data['is_member'] ?? false;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _username = 'Guest';
      _membershipStatus = 'free';
      _creditsRemaining = 0;
      _isMember = false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      await fetchProfile();
    } catch (error) {
      if (kDebugMode) {
        print(error);
      }
    }
  }

  void reset() {
    _username = 'Guest';
    _membershipStatus = 'free';
    _creditsRemaining = 0;
    _isLoading = false;
    _role = 'member';
    _approvalStatus = 'pending';
    _isMember = false;
    notifyListeners();
  }

  void decrementCredit() {
    if (_creditsRemaining > 0) {
      _creditsRemaining--;
      notifyListeners();
    }
  }
}
