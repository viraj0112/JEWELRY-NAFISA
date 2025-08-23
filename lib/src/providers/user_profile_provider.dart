// lib/src/providers/user_profile_provider.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _username = 'Guest';
  String _membershipStatus = 'free';
  String _role = 'member';
  String _approvalStatus = 'pending';

  int _creditsRemaining = 0;
  bool _isLoading = true;

  // Public getters
  String get username => _username;
  String get membershipStatus => _membershipStatus;
  String get role => _role;
  String get approvalStatus => _approvalStatus;
  bool get isDesigner => _role == 'designer';
  bool get isApproved => _approvalStatus == 'approved';
  int get creditsRemaining => _creditsRemaining;
  bool get isMember => _membershipStatus == 'member';
  bool get isLoading => _isLoading;

  // Fetch the user's profile from the 'Users' table in Supabase
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
      _membershipStatus = data['membership_status'] ?? 'free';
      _creditsRemaining = data['credits_remaining'] ?? 0;
      _role = data['role'] ?? 'member';
      _approvalStatus = data['approval_status'] ?? 'pending';
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      // Handle error case, maybe set default values
      _username = 'Guest';
      _membershipStatus = 'free';
      _creditsRemaining = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset provider to default (used after sign out)
  void reset() {
    _username = 'Guest';
    _membershipStatus = 'free';
    _creditsRemaining = 0;
    _isLoading = false;
    _role = 'member';
    _approvalStatus = 'pending';
    notifyListeners();
  }

  // Method to manually decrement credit in the UI after a successful quote
  void decrementCredit() {
    if (_creditsRemaining > 0) {
      _creditsRemaining--;
      notifyListeners();
    }
  }
}
