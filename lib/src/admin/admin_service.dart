import 'package:jewelry_nafisa/src/admin/models/admin_quote.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, int>> getDashboardSummary() async {
    // This can also be converted to a real query later
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'todaysQuotes': 15,
      'newSignups': 8,
      'pendingApprovals': 3,
    };
  }

  // ✨ UPDATED: Fetches real users from Supabase
  Future<List<AdminUser>> getUsers(String filter) async {
    try {
      PostgrestFilterBuilder query = _supabase.from('users').select();

      if (filter == 'Members') {
        query = query.eq('is_member', true);
      } else if (filter == 'Non-Members') {
        query = query.eq('is_member', false);
      }

      final response = await query.order('created_at', ascending: false);

      final users = (response as List<dynamic>)
          .map((data) => AdminUser.fromMap(data as Map<String, dynamic>))
          .toList();

      return users;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<List<AdminQuote>> getQuotes() async {

    await Future.delayed(const Duration(milliseconds: 600));
    return [
      AdminQuote(id: 'q1', userName: 'Alice', isUserMember: true, imageUrls: ['https://placehold.co/150'], message: 'Need price for this ring.', status: 'Pending', createdAt: DateTime.now()),
      AdminQuote(id: 'q2', userName: 'Bob', isUserMember: false, imageUrls: ['https://placehold.co/150', 'https://placehold.co/150'], message: 'Bulk order inquiry.', status: 'Responded', createdAt: DateTime.now().subtract(const Duration(days: 1))),
    ];
  }
}