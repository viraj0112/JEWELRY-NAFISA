import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure you have initialized Supabase in main.dart
final supabase = Supabase.instance.client;

enum UserTypeFilter { all, members, nonMembers }
enum StatusFilter { all, active, inactive }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone; // Added phone field
  final String? avatar;
  final int credits;
  final int boards;
  final int shares;
  final int referrals;
  final String tier;
  final String status;
  final bool isMember; // Added isMember field
  final DateTime? lastActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatar,
    this.credits = 0,
    this.boards = 0,
    this.shares = 0,
    this.referrals = 0,
    this.tier = 'Basic',
    this.status = 'Active',
    this.isMember = false,
    this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) {
    // Helper to extract count from Supabase relation response
    // Structure is usually: "boards": [{"count": 5}] or just 5 depending on API version,
    // but usually [{count: X}] when using select=*,boards(count)
    int getCount(dynamic val) {
      if (val is List && val.isNotEmpty && val[0] is Map) {
        return (val[0]['count'] as int?) ?? 0;
      }
      return 0;
    }

    return UserModel(
      id: m['id'].toString(),
      name: m['name'] ?? m['full_name'] ?? 'Unknown',
      email: m['email'] ?? '',
      phone: m['phone'] ?? '', // Map phone
      avatar: m['avatar_url'],
      // Map real columns
      credits: (m['credits_remaining'] ?? 0) as int,
      // Map counts from relations
      boards: getCount(m['boards']),
      shares: getCount(m['shares']),
      // For referrals, we look at the alias we use in the query
      referrals: getCount(m['referrals']),
      
      tier: (m['membership_plan'] ?? 'Basic') as String, // Map to actual plan
      status: (m['approval_status'] ?? 'pending') as String, // Map to actual status
      isMember: m['is_member'] ?? false, // Strict boolean check
      lastActive: m['created_at'] != null ? DateTime.tryParse(m['created_at']) : null, // Using created_at as fallback for now
    );
  }
}

class LeaderboardModel {
  final UserModel user;
  final int totalReferrals;
  final int successful;
  final int creditsEarned;

  LeaderboardModel({
    required this.user,
    required this.totalReferrals,
    required this.successful,
    required this.creditsEarned,
  });

  double get successRate => totalReferrals == 0 ? 0.0 : successful / totalReferrals;
}

class UsersProvider extends ChangeNotifier {
  // UI state
  UserTypeFilter userType = UserTypeFilter.all;
  StatusFilter status = StatusFilter.all;
  String search = '';
  Timer? _debounce;

  // Data
  List<UserModel> _members = [];
  List<UserModel> _nonMembers = [];
  List<LeaderboardModel> _leaderboard = [];

  bool loading = false;
  String error = '';

  List<UserModel> get members => _members;
  List<UserModel> get nonMembers => _nonMembers;
  List<LeaderboardModel> get leaderboard => _leaderboard;

  UsersProvider() {
    fetchAll(); // initial load
  }

  void setUserType(UserTypeFilter t) {
    userType = t;
    fetchAll();
    notifyListeners();
  }

  void setStatus(StatusFilter s) {
    status = s;
    fetchAll();
    notifyListeners();
  }

  void setSearch(String q) {
    search = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchAll();
    });
  }

  Future<void> fetchAll() async {
    loading = true;
    error = '';
    notifyListeners();

    try {
      // 1. Start the query.
      // We use select with counts for related tables.
      // boards(count), shares(count), referrals!referrer_id(count)
      var q = supabase.from('users').select('''
        *,
        boards:boards(count),
        shares:shares(count),
        referrals:referrals!referrer_id(count)
      ''');

      // 2. Apply Filters
      
      // User Type
      if (userType == UserTypeFilter.members) {
        q = q.eq('is_member', true);
      } else if (userType == UserTypeFilter.nonMembers) {
        q = q.eq('is_member', false);
      }

      // Status (filtering by approval_status based on schema)
      if (status == StatusFilter.active) {
        q = q.eq('approval_status', 'approved');
      } else if (status == StatusFilter.inactive) {
        q = q.neq('approval_status', 'approved');
      }

      // Search
      if (search.isNotEmpty) {
        final pattern = '%${search.replaceAll('%', '\\%')}%';
        q = q.or('full_name.ilike.$pattern,email.ilike.$pattern');
      }

      // 3. Execute Query
      final List<dynamic> rawData = await q.order('created_at', ascending: false);

      // 4. Parse Data
      final data = List<Map<String, dynamic>>.from(rawData);
      final users = data.map((m) => UserModel.fromMap(m)).toList();

      // STRICT Filtering based on is_member column
      _members = users.where((u) => u.isMember == true).toList();
      _nonMembers = users.where((u) => u.isMember == false).toList();

      // Calculate leaderboard based on real referral data
      final lb = users
          .where((u) => u.referrals > 0)
          .map((u) => LeaderboardModel(
                user: u,
                totalReferrals: u.referrals, // Total referrals made
                successful: u.referrals, // Assuming all counted are successful for now
                creditsEarned: u.referrals * 20, // Example calculation
              ))
          .toList();

      lb.sort((a, b) => b.successful.compareTo(a.successful));
      _leaderboard = lb.take(50).toList();

    } catch (e) {
      error = e.toString();
      debugPrint("Error fetching users: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> exportCsv() async {
    // implement server-side or client CSV building
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}