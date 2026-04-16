import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';
import '../widgets/admin_skeletons.dart';

enum _ModerationTab { pending, verification, archive }

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({
    super.key,
    required this.pendingItems,
    required this.searchQuery,
    required this.dateFormat,
    required this.dataService,
    required this.onRefreshRequested,
  });

  final List<ModerationItem> pendingItems;
  final String searchQuery;
  final DateFormat dateFormat;
  final NewAdminDataService dataService;
  final VoidCallback onRefreshRequested;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  _ModerationTab _activeTab = _ModerationTab.pending;
  bool _loadingArchive = false;
  bool _loadingVerifications = false;
  bool _actionBusy = false;
  List<ModerationItem> _archive = const [];
  List<VerificationRequest> _verification = const [];

  @override
  void initState() {
    super.initState();
    _loadVerification();
    _loadArchive();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    final filteredPending = widget.pendingItems.where((item) {
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.category,
        item.ownerName,
        item.ownerEmail,
        item.source,
        item.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    final filteredArchive = _archive.where((item) {
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.category,
        item.ownerName,
        item.ownerEmail,
        item.status,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    final filteredVerification = _verification.where((item) {
      if (query.isEmpty) return true;
      final haystack = [
        item.name,
        item.subtitle,
        item.email,
        item.role,
        item.country,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Curatorial Review',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        const Text(
          'Validate and approve new artisan submissions, high-fidelity 3D prototypes, and designer sketches.',
          style: TextStyle(color: Color(0xFF586963)),
        ),
        const SizedBox(height: 16),
        _buildTabs(
          pendingCount: filteredPending.length,
          verificationCount: filteredVerification.length,
          archiveCount: filteredArchive.length,
        ),
        const SizedBox(height: 14),
        if (_activeTab == _ModerationTab.pending)
          _buildPendingGrid(filteredPending),
        if (_activeTab == _ModerationTab.verification)
          _buildVerificationList(filteredVerification),
        if (_activeTab == _ModerationTab.archive)
          _buildArchiveGrid(filteredArchive),
      ],
    );
  }

  Widget _buildTabs({
    required int pendingCount,
    required int verificationCount,
    required int archiveCount,
  }) {
    return Row(
      children: [
        _tabButton(
          tab: _ModerationTab.pending,
          label: 'Pending Submissions',
          count: pendingCount,
        ),
        const SizedBox(width: 16),
        _tabButton(
          tab: _ModerationTab.verification,
          label: 'Verification Requests',
          count: verificationCount,
        ),
        const SizedBox(width: 16),
        _tabButton(
          tab: _ModerationTab.archive,
          label: 'Archive',
          count: archiveCount,
        ),
      ],
    );
  }

  Widget _tabButton({
    required _ModerationTab tab,
    required String label,
    required int count,
  }) {
    final selected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF034033) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? const Color(0xFF034033) : const Color(0xFF60716A),
              ),
            ),
            if (tab == _ModerationTab.pending) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF034033) : const Color(0xFFE8ECEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : const Color(0xFF50615B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingGrid(List<ModerationItem> items) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No pending submissions found.'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 3
            : constraints.maxWidth > 700
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 0.96 : 0.72,
          children: items
              .map(
                (item) => _SubmissionCard(
                  item: item,
                  dateFormat: widget.dateFormat,
                  busy: _actionBusy,
                  onApprove: () => _moderate(item, approve: true),
                  onReject: () => _moderate(item, approve: false),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildArchiveGrid(List<ModerationItem> items) {
    if (_loadingArchive && items.isEmpty) {
      return const AdminSkeletonView(variant: AdminSkeletonVariant.cards);
    }
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No archived moderation items.'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 3
            : constraints.maxWidth > 700
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 0.8 : 0.72,
          children: items
              .map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _itemImage(item),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          '${item.ownerName} • ${item.category}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B75)),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.status == 'approved'
                                  ? const Color(0xFFDDF4E8)
                                  : const Color(0xFFFFE9E6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.status == 'approved'
                                    ? const Color(0xFF1E6B42)
                                    : const Color(0xFFB1261A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildVerificationList(List<VerificationRequest> items) {
    if (_loadingVerifications && items.isEmpty) {
      return const AdminSkeletonView(variant: AdminSkeletonVariant.list);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'New Verification Requests',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('No verification requests.')
            else
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E8E6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F0E8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials(item.name),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              item.subtitle.isEmpty ? item.email : item.subtitle,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6C7C76)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 16,
                            color: item.hasBusinessType
                                ? const Color(0xFF0A4F3F)
                                : const Color(0xFF9FAEAA),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_user,
                            size: 16,
                            color: item.hasGst
                                ? const Color(0xFF0A4F3F)
                                : const Color(0xFF9FAEAA),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: item.hasAddress
                                ? const Color(0xFF0A4F3F)
                                : const Color(0xFF9FAEAA),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _verificationAction(item, approve: false),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _actionBusy
                            ? null
                            : () => _verificationAction(item, approve: true),
                        child: const Text('Verify Partner'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moderate(ModerationItem item, {required bool approve}) async {
    setState(() => _actionBusy = true);
    try {
      await widget.dataService.moderateAsset(assetId: item.id, approve: approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${item.title} approved'
                : '${item.title} rejected',
          ),
        ),
      );
      widget.onRefreshRequested();
      _loadArchive();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed moderation action: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _verificationAction(
    VerificationRequest item, {
    required bool approve,
  }) async {
    setState(() => _actionBusy = true);
    try {
      await widget.dataService.updateVerificationStatus(
        userId: item.userId,
        approve: approve,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${item.name} verified'
                : '${item.name} rejected',
          ),
        ),
      );
      await _loadVerification();
      widget.onRefreshRequested();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed verification action: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _loadArchive() async {
    setState(() => _loadingArchive = true);
    try {
      final rows = await widget.dataService.fetchModerationArchive(limit: 80);
      if (!mounted) return;
      setState(() => _archive = rows);
    } finally {
      if (mounted) setState(() => _loadingArchive = false);
    }
  }

  Future<void> _loadVerification() async {
    setState(() => _loadingVerifications = true);
    try {
      final rows = await widget.dataService.fetchVerificationRequests(limit: 80);
      if (!mounted) return;
      setState(() => _verification = rows);
    } finally {
      if (mounted) setState(() => _loadingVerifications = false);
    }
  }

  String _initials(String text) {
    final parts = text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.item,
    required this.dateFormat,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ModerationItem item;
  final DateFormat dateFormat;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = _badgeLabel(item);
    final badgeColor = _badgeColor(item);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _itemImage(item),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              'Ref: ${item.id.substring(0, item.id.length.clamp(0, 8))}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6A7A74)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.ownerName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A6200),
                    ),
                  ),
                ),
                Text(
                  item.ownerLocation,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF6A7A74)),
                ),
              ],
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .take(2)
                    .map(
                      (tag) => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4ED),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F6A46),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _badgeLabel(ModerationItem item) {
    final source = item.source.toLowerCase();
    if (source.contains('sketch')) return 'CONCEPT SKETCH';
    if (source.contains('3d')) return '3D MODEL';
    if (source.contains('finished') || source.contains('product')) {
      return 'FINISHED PRODUCT';
    }
    if (item.category.toLowerCase().contains('sketch')) return 'CONCEPT SKETCH';
    return item.category.toUpperCase();
  }

  static Color _badgeColor(ModerationItem item) {
    final label = _badgeLabel(item).toLowerCase();
    if (label.contains('sketch')) return const Color(0xFFB87700);
    if (label.contains('3d')) return const Color(0xFF0A4F3F);
    if (label.contains('finished')) return const Color(0xFF1A7D57);
    return const Color(0xFF2D5D50);
  }
}

Widget _itemImage(ModerationItem item) {
  final imageUrl = (item.thumbUrl?.isNotEmpty ?? false)
      ? item.thumbUrl!
      : (item.mediaUrl?.isNotEmpty ?? false ? item.mediaUrl! : '');
  if (imageUrl.isEmpty) {
    return Container(
      color: const Color(0xFFE5EBE8),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF6D7E77)),
    );
  }
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      color: const Color(0xFFE5EBE8),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF6D7E77)),
    ),
  );
}
