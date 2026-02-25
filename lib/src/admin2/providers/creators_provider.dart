import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Models
class CreatorModel {
  final String id;
  final String fullName;
  final String? email;
  final String? avatarUrl;
  String approvalStatus; // approved | pending | rejected
  final String businessType; // 3d_artist | sketch_designer or free-text
  final String? location;
  bool isApproved;
  final DateTime createdAt;
  final String role;

  int worksCount;
  int totalViews;
  double avgRating;

  CreatorModel({
    required this.id,
    required this.fullName,
    this.email,
    this.avatarUrl,
    required this.approvalStatus,
    required this.businessType,
    this.location,
    required this.isApproved,
    required this.createdAt,
    required this.role,
    this.worksCount = 0,
    this.totalViews = 0,
    this.avgRating = 0.0,
  });
}

class WorkModel {
  final String id;
  final String title;
  final String category; // 3D Model / Sketch
  final String mediaUrl;
  final String creatorId;
  final String status; // published / under_review / pending / approved
  final int views;
  final int saves;
  final int shares;
  final DateTime createdAt;

  WorkModel({
    required this.id,
    required this.title,
    required this.category,
    required this.mediaUrl,
    required this.creatorId,
    required this.status,
    required this.views,
    required this.saves,
    required this.shares,
    required this.createdAt,
  });
}

/// Provider
class CreatorsProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  List<CreatorModel> creators = [];
  List<WorkModel> works = [];

  // Categories fetched from designerproducts for filtering
  List<String> categories = [];

  bool loading = false;

  // filters
  String searchQuery = '';
  String? statusFilter;
  String categoryFilter = 'All Categories';

  Future<void> loadCreators() async {
    loading = true;
    notifyListeners();

    try {
      // 1. Load Categories for filter dropdown
      await _loadCategories();

      // 2. Fetch users with role 'designer'
      final res = await supabase.from('users').select('''
        id,
        full_name,
        email,
        avatar_url,
        approval_status,
        business_type,
        address,
        is_approved,
        created_at,
        role
      ''').inFilter('role', ['designer', 'manufacturer']);

      final List<dynamic> data = res;
      creators = [];

      for (var c in data) {
        creators.add(CreatorModel(
          id: c['id'],
          fullName: (c['full_name'] ?? 'Unknown').toString(),
          email: c['email'] as String?,
          avatarUrl: c['avatar_url'] as String?,
          approvalStatus: (c['approval_status'] ?? 'pending').toString(),
          businessType: (c['business_type'] ?? '3d_artist').toString(),
          location: c['address'] as String?,
          isApproved: c['is_approved'] ?? false,
          role: (c['role'] ?? 'designer').toString(),
          createdAt: DateTime.tryParse((c['created_at'] ?? '').toString()) ??
              DateTime.now(),
        ));
      }

      if (creators.isNotEmpty) {
        await loadWorks();
        // Works count is derived from loaded works for consistency
        _updateWorksCounts();
      } else {
        works = [];
      }
    } catch (e) {
      debugPrint('loadCreators error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      // Fetch distinct categories from designerproducts table
      final res = await supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Category'});

      if (res != null && res is List) {
        categories = ['All Categories', ...res.map((e) => e.toString())];
      } else {
        categories = ['All Categories'];
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      categories = [
        'All Categories',
        'Ring',
        'Necklace',
        'Earring',
        'Bracelet'
      ]; // Fallback
    }
  }

  Future<void> loadWorks() async {
    final result = <WorkModel>[];
    final List<String> designerIds = creators.map((c) => c.id).toList();

    if (designerIds.isEmpty) {
      works = [];
      notifyListeners();
      return;
    }

    try {
      // 1) Assets (3D models)
      final assets = await supabase
          .from('assets')
          .select('id,title,thumb_url,owner_id,status,category,created_at')
          .inFilter('owner_id', designerIds);

      for (var a in assets) {
        result.add(WorkModel(
          id: a['id'],
          title: (a['title'] ?? 'Untitled').toString(),
          category: (a['category'] ?? '3D Model').toString(),
          mediaUrl: (a['thumb_url'] ?? '').toString(),
          creatorId: (a['owner_id'] ?? '').toString(),
          status: (a['status'] ?? 'pending').toString(),
          views: 0,
          saves: 0,
          shares: 0,
          createdAt: DateTime.tryParse((a['created_at'] ?? '').toString()) ??
              DateTime.now(),
        ));
      }

      // 2) Designer-files (Sketches)
      final sketches = await supabase
          .from(
              'designer-files') // Quoting handled by postgres usually, but safe here
          .select('id,file_url,user_id,file_type,created_at')
          .eq('file_type', 'sketch')
          .inFilter('user_id', designerIds);

      for (var s in sketches) {
        result.add(WorkModel(
          id: s['id'],
          title: 'Sketch',
          category: 'Sketch',
          mediaUrl: (s['file_url'] ?? '').toString(),
          creatorId: (s['user_id'] ?? '').toString(),
          // Sketches in this table often don't have status, assuming published/approved if visible
          status: 'approved',
          views: 0,
          saves: 0,
          shares: 0,
          createdAt: DateTime.tryParse((s['created_at'] ?? '').toString()) ??
              DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('loadWorks error: $e');
    } finally {
      works = result;
      notifyListeners();
    }
  }

  void _updateWorksCounts() {
    for (var c in creators) {
      c.worksCount = works.where((w) => w.creatorId == c.id).length;
    }
  }

  // --- Filters ---
  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    statusFilter = status;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    categoryFilter = category;
    notifyListeners();
  }

  void resetFilters() {
    searchQuery = '';
    statusFilter = null;
    categoryFilter = 'All Categories';
    notifyListeners();
  }

  // Get creators filtered by search, status, AND category (based on their works)
  List<CreatorModel> get filteredCreators {
    final q = searchQuery.trim().toLowerCase();
    return creators.where((c) {
      // Status Filter
      if (statusFilter != null &&
          c.approvalStatus.toLowerCase() != statusFilter!.toLowerCase()) {
        return false;
      }

      // Category Filter - Check if creator has any work in this category
      if (categoryFilter != 'All Categories') {
        final hasMatchingWork = works.any((w) =>
            w.creatorId == c.id &&
            w.category.toLowerCase() == categoryFilter.toLowerCase());
        if (!hasMatchingWork) return false;
      }

      // Search Query
      if (q.isEmpty) return true;
      final matchName = c.fullName.toLowerCase().contains(q);
      final matchEmail = (c.email ?? '').toLowerCase().contains(q);
      // Also allow searching by specialization/business type text
      final matchType = c.businessType.toLowerCase().contains(q);

      return matchName || matchEmail || matchType;
    }).toList();
  }

  // Get all works for the "Uploaded Works" tab - ONLY APPROVED/PUBLISHED
  List<WorkModel> get approvedWorks {
    return works.where((w) {
      final s = w.status.toLowerCase();
      return s == 'approved' || s == 'published' || s == 'active';
    }).toList();
  }

  // Helper to get pending submissions for a specific creator (for the detail view)
  List<WorkModel> getPendingWorksForCreator(String creatorId) {
    return works
        .where((w) =>
            w.creatorId == creatorId &&
            (w.status.toLowerCase() == 'pending' ||
                w.status.toLowerCase() == 'under_review'))
        .toList();
  }

  // --- Actions ---
  Future<void> approveCreator(String id) async {
    try {
      await supabase.from('users').update(
          {'approval_status': 'approved', 'is_approved': true}).eq('id', id);
      final c = creators.firstWhere((e) => e.id == id);
      c.approvalStatus = 'approved';
      c.isApproved = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Approve error: $e");
    }
  }

  Future<void> rejectCreator(String id) async {
    try {
      await supabase.from('users').update(
          {'approval_status': 'rejected', 'is_approved': false}).eq('id', id);
      final c = creators.firstWhere((e) => e.id == id);
      c.approvalStatus = 'rejected';
      c.isApproved = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Reject error: $e");
    }
  }
}
