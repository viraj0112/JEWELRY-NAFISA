import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _username = 'Guest';
  String _membershipStatus = 'free';
  String _role = 'member';
  String _approvalStatus = 'pending';
  bool _isMember = false;

  int _creditsRemaining = 0;
  bool _isLoading = true;

  String get username => _username;
  String get membershipStatus => _membershipStatus;
  String get role => _role;
  String get approvalStatus => _approvalStatus;
  bool get isDesigner => _role == 'designer';
  bool get isApproved => _approvalStatus == 'approved';
  int get creditsRemaining => _creditsRemaining;
  bool get isMember => _isMember;
  bool get isLoading => _isLoading;

  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

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