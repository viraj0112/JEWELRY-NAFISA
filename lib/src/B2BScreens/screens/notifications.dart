import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  late TabController _tabController;

  // Activity tab
  bool _isLoadingNotifs = true;
  List<Map<String, dynamic>> _notifications = [];

  // Approvals tab
  bool _isLoadingApprovals = true;
  List<Map<String, dynamic>> _approvalItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchNotifications();
    _fetchApprovals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Activity ────────────────────────────────────────────────────────────────

  Future<void> _fetchNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingNotifs = false);
        return;
      }

      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoadingNotifs = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) setState(() => _isLoadingNotifs = false);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read')),
        );
      }
    }
  }

  // ── Approvals ───────────────────────────────────────────────────────────────

  Future<void> _fetchApprovals() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingApprovals = false);
        return;
      }

      // Determine which table to query
      final profile =
          Provider.of<UserProfileProvider>(context, listen: false).userProfile;
      final table = profile?.manufacturerProfile != null
          ? 'manufacturerproducts'
          : 'designerproducts';

      final data = await _supabase
          .from(table)
          .select('id, product_title, status, images_arr, updated_at')
          .eq('user_id', user.id)
          .inFilter('status', ['approved', 'rejected', 'pending'])
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _approvalItems = List<Map<String, dynamic>>.from(data);
          _isLoadingApprovals = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching approval items: $e');
      if (mounted) setState(() => _isLoadingApprovals = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] == false).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 40, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Product updates & activity',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.outfit(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Tab Bar ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF6B7280),
                    labelStyle: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle:
                        GoogleFonts.outfit(fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Activity'),
                            if (unread > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Approvals'),
                            if (_approvalItems.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_approvalItems.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Tab Views ───────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActivityTab(),
                    _buildApprovalsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Activity Tab ─────────────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    if (_isLoadingNotifs) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No activity yet',
        subtitle: 'Your engagement updates will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: Colors.teal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildNotificationCard(_notifications[i]),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final bool isRead = data['is_read'] ?? false;
    final String type = data['type'] ?? 'default';
    final String title = data['title'] ?? 'Notification';
    final String body = data['body'] ?? '';
    final String timestamp = data['created_at'] ?? '';

    final (Color iconBg, Color iconFg, IconData iconData) = switch (type) {
      'trending' => (
          const Color(0xFFD1FAE5),
          const Color(0xFF059669),
          Icons.show_chart_rounded
        ),
      'milestone' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB),
          Icons.check_circle_outline_rounded
        ),
      'engagement' => (
          const Color(0xFFFFE4E6),
          const Color(0xFFE11D48),
          Icons.favorite_border_rounded
        ),
      'saved' => (
          const Color(0xFFEDE9FE),
          const Color(0xFF7C3AED),
          Icons.bookmark_border_rounded
        ),
      'opportunity' => (
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
          Icons.lightbulb_outline_rounded
        ),
      'rising' => (
          const Color(0xFFE0F2FE),
          const Color(0xFF0284C7),
          Icons.trending_up_rounded
        ),
      _ => (
          const Color(0xFFF3F4F6),
          const Color(0xFF6B7280),
          Icons.notifications_none_rounded
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? const Color(0xFFE5E7EB)
              : Colors.teal.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconFg, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatTime(timestamp),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Approvals Tab ────────────────────────────────────────────────────────────

  Widget _buildApprovalsTab() {
    if (_isLoadingApprovals) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    if (_approvalItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No items in review',
        subtitle: 'Approved and rejected products will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovals,
      color: Colors.teal,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        itemCount: _approvalItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildApprovalCard(_approvalItems[i]),
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> data) {
    final String title =
        data['product_title'] ?? data['title'] ?? 'Unnamed product';
    final String status = data['status'] ?? 'pending';
    final String updatedAt = data['updated_at'] ?? '';

    // Parse first image
    String? imageUrl;
    final imgs = data['images_arr'];
    if (imgs is List && imgs.isNotEmpty) {
      imageUrl = imgs.first?.toString();
    }

    final (Color statusBg, Color statusFg, IconData statusIcon,
        String statusLabel, String statusMsg) = switch (status) {
      'approved' => (
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          Icons.check_circle_rounded,
          'Approved',
          'Your product is now live on the marketplace.',
        ),
      'rejected' => (
          const Color(0xFFFFE4E6),
          const Color(0xFF9F1239),
          Icons.cancel_rounded,
          'Rejected',
          'This product did not meet our quality guidelines.',
        ),
      _ => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.schedule_rounded,
          'In Review',
          'Our team is reviewing your submission.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusFg.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusMsg,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: statusFg.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 11, color: statusFg),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(updatedAt),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: Colors.teal.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF9CA3AF),
        size: 24,
      ),
    );
  }
}
