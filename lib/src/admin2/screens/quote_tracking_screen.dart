import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';

/// Quote Request Viewer — matches the "The Atelier" admin design.
class QuoteTrackingScreen extends StatefulWidget {
  const QuoteTrackingScreen({
    super.key,
    required this.quotes,
    required this.dataService,
    required this.onRefreshRequested,
  });

  final List<QuoteRecord> quotes;
  final NewAdminDataService dataService;
  final VoidCallback onRefreshRequested;

  @override
  State<QuoteTrackingScreen> createState() => _QuoteTrackingScreenState();
}

class _QuoteTrackingScreenState extends State<QuoteTrackingScreen> {
  static const int _pageSize = 10;
  int _currentPage = 0;
  String _statusFilter = 'all'; // all | pending | responded | closed
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final DateFormat _fmt = DateFormat('MMM dd, yyyy');

  // Multi-selection state
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  // ── Derived computations ────────────────────────────────────────────────

  List<QuoteRecord> get _filtered {
    var list = widget.quotes;
    if (_statusFilter != 'all') {
      list = list.where((q) => q.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        return r.userName.toLowerCase().contains(q) ||
            r.userEmail.toLowerCase().contains(q) ||
            r.productTitle.toLowerCase().contains(q) ||
            r.creatorName.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  int get _totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 9999);

  List<QuoteRecord> get _pageRows {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    if (start >= _filtered.length) return [];
    return _filtered.sublist(start, end);
  }

  int get _totalQuotes => widget.quotes.length;
  int get _activePending =>
      widget.quotes.where((q) => q.status == 'pending').length;
  int get _closedThisMonth {
    final now = DateTime.now();
    return widget.quotes
        .where((q) =>
            q.status == 'closed' &&
            q.createdAt != null &&
            q.createdAt!.year == now.year &&
            q.createdAt!.month == now.month)
        .length;
  }

  double get _responseRate {
    final responded = widget.quotes
        .where((q) => q.status == 'responded' || q.status == 'closed')
        .length;
    if (_totalQuotes == 0) return 0;
    return (responded / _totalQuotes) * 100;
  }

  // Queue capacity: % of designer vs manufacturer requests
  double get _designerCapacity {
    if (_totalQuotes == 0) return 0;
    final d = widget.quotes
        .where((q) => q.productTable.contains('designer'))
        .length;
    return (d / _totalQuotes).clamp(0.0, 1.0);
  }

  double get _manufacturerCapacity {
    if (_totalQuotes == 0) return 0;
    final m = widget.quotes
        .where((q) => q.productTable.contains('manufacturer'))
        .length;
    return (m / _totalQuotes).clamp(0.0, 1.0);
  }

  // Most requested metal type for the insight card
  String get _topMetalInsight {
    final counts = <String, int>{};
    for (final q in widget.quotes) {
      if (q.metalType.isNotEmpty) {
        counts[q.metalType] = (counts[q.metalType] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '';
    final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return top.key;
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  void _toggleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.addAll(_pageRows.map((r) => r.id));
      } else {
        for (final r in _pageRows) {
          _selectedIds.remove(r.id);
        }
      }
    });
  }

  void _toggleSelect(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _bulkUpdateStatus(String status) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      await widget.dataService
          .updateQuoteRequestsStatus(_selectedIds.toList(), status);
      _selectedIds.clear();
      widget.onRefreshRequested();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleReply(QuoteRecord q, String message) async {
    if (message.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      // 1. Update status to responded
      await widget.dataService.updateQuoteRequestsStatus([q.id], 'responded');
      // 2. Send notification to user
      // Assuming QuoteRecord should have user_id. Let's check NewAdminDataService logic.
      // In fetchQuoteTracking, we have userId.
      // Wait, let's verify if QuoteRecord has userId. 
      // Checking snippet from earlier: productId, userId, status...
      
      // We'll need a way to get userId if it's not in QuoteRecord.
      // Actually, I'll update QuoteRecord model to include userId if it's missing.
      
      await widget.dataService.sendUserNotification(
        userId: q.userId, // I will add this to the model
        title: 'New Response to your Quote Request',
        body: message,
        relatedItemId: q.productId,
      );
      
      widget.onRefreshRequested();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send response: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ──────────────────────────────────────────────────
            const _PageHeader(),
            const SizedBox(height: 24),

            // ── KPI cards ────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return isMobile
                    ? Column(
                        children: _buildKpiCards(),
                      )
                    : Row(
                        children: _buildKpiCards()
                            .map((c) => Expanded(child: c))
                            .toList(),
                      );
              },
            ),
            const SizedBox(height: 28),

            // ── Search + filter bar ──────────────────────────────────────────
            _SearchFilterBar(
              controller: _searchCtrl,
              statusFilter: _statusFilter,
              onSearch: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 0;
              }),
              onFilterChanged: (v) => setState(() {
                _statusFilter = v;
                _currentPage = 0;
              }),
            ),
            const SizedBox(height: 16),

            // ── Main table ───────────────────────────────────────────────────
            _QuoteTable(
              rows: _pageRows,
              dateFormat: _fmt,
              currentPage: _currentPage,
              totalPages: _totalPages,
              totalCount: _filtered.length,
              pageSize: _pageSize,
              selectedIds: _selectedIds,
              onPageChanged: (p) => setState(() => _currentPage = p),
              onSelectAll: _toggleSelectAll,
              onSelectRow: _toggleSelect,
              onActionTap: _showQuoteDetail,
            ),
            const SizedBox(height: 28),

            // ── Bottom section: Queue capacity + Insight card ────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _QueueCapacityCard(
                          designerCapacity: _designerCapacity,
                          manufacturerCapacity: _manufacturerCapacity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(topMetal: _topMetalInsight),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _QueueCapacityCard(
                      designerCapacity: _designerCapacity,
                      manufacturerCapacity: _manufacturerCapacity,
                    ),
                    const SizedBox(height: 16),
                    _InsightCard(topMetal: _topMetalInsight),
                  ],
                );
              },
            ),
          ],
        ),
        
        // ── Floating Bulk Action Bar ─────────────────────────────────────
        if (_selectedIds.isNotEmpty)
          _BulkActionBar(
            selectedCount: _selectedIds.length,
            isProcessing: _isProcessing,
            onClose: () => _bulkUpdateStatus('closed'),
            onRespond: () => _bulkUpdateStatus('responded'),
            onCancel: () => setState(() => _selectedIds.clear()),
          ),
      ],
    );
  }

  List<Widget> _buildKpiCards() {
    return [
      _KpiCard(
        label: 'TOTAL QUOTES',
        value: NumberFormat('#,###').format(_totalQuotes),
        valueColor: const Color(0xFF1B3D2F),
        isHighlight: false,
      ),
      _KpiCard(
        label: 'ACTIVE PENDING',
        value: '$_activePending',
        valueColor: const Color(0xFFC49A1D),
        isHighlight: true,
      ),
      _KpiCard(
        label: 'RESPONSE RATE',
        value: '${_responseRate.toStringAsFixed(1)}%',
        valueColor: const Color(0xFF1B3D2F),
        isHighlight: false,
      ),
      _KpiCard(
        label: 'CLOSED THIS MONTH',
        value: NumberFormat('#,###').format(_closedThisMonth),
        valueColor: const Color(0xFF1B3D2F),
        isHighlight: false,
      ),
    ];
  }

  void _showQuoteDetail(QuoteRecord q) {
    showDialog<void>(
      context: context,
      builder: (_) => _QuoteDetailDialog(
        quote: q,
        dateFormat: _fmt,
        onReply: (msg) {
          Navigator.pop(context);
          _handleReply(q, msg);
        },
        onStatusUpdate: (st) {
          Navigator.pop(context);
          _bulkUpdateStatus(st); // Use same logic even for single
        },
      ),
    );
  }
}

// ── Page Header ─────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quote Request Viewer',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B3D2F),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review and manage interaction records between clients and artisans within the digital vault.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isHighlight,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E8E4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search + Filter Bar ──────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.controller,
    required this.statusFilter,
    required this.onSearch,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final String statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search by user, product or creator…',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDE5E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDE5E0)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StatusChip(
          label: 'All',
          value: 'all',
          current: statusFilter,
          onTap: onFilterChanged,
        ),
        _StatusChip(
          label: 'Pending',
          value: 'pending',
          current: statusFilter,
          onTap: onFilterChanged,
          activeColor: const Color(0xFFF5A623),
        ),
        _StatusChip(
          label: 'Responded',
          value: 'responded',
          current: statusFilter,
          onTap: onFilterChanged,
          activeColor: const Color(0xFF3AA876),
        ),
        _StatusChip(
          label: 'Closed',
          value: 'closed',
          current: statusFilter,
          onTap: onFilterChanged,
          activeColor: Colors.grey,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final isActive = current == value;
    final color = activeColor ?? const Color(0xFF1B3D2F);
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(20) : Colors.transparent,
          border: Border.all(
            color: isActive ? color : const Color(0xFFDDE5E0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ── Quote Table ──────────────────────────────────────────────────────────────

class _QuoteTable extends StatelessWidget {
  const _QuoteTable({
    required this.rows,
    required this.dateFormat,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.pageSize,
    required this.onPageChanged,
    required this.onActionTap,
    required this.selectedIds,
    required this.onSelectAll,
    required this.onSelectRow,
  });

  final List<QuoteRecord> rows;
  final DateFormat dateFormat;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<QuoteRecord> onActionTap;
  final Set<String> selectedIds;
  final ValueChanged<bool?> onSelectAll;
  final void Function(String, bool?) onSelectRow;

  @override
  Widget build(BuildContext context) {
    final allSelected = rows.isNotEmpty &&
        rows.every((r) => selectedIds.contains(r.id));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E8E4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // ── Table header ───────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8EEE9))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: onSelectAll,
                    activeColor: const Color(0xFF1B3D2F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Expanded(flex: 3, child: _HeaderCell('USER')),
                Expanded(flex: 2, child: _HeaderCell('CREATOR')),
                Expanded(flex: 3, child: _HeaderCell('PRODUCT / DESIGN')),
                Expanded(flex: 2, child: _HeaderCell('DATE')),
                Expanded(flex: 2, child: _HeaderCell('STATUS')),
                SizedBox(width: 48, child: _HeaderCell('ACTIONS')),
              ],
            ),
          ),

          // ── Rows ───────────────────────────────────────────────────────
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No quote requests found.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...rows.map((q) => _QuoteRow(
                  quote: q,
                  dateFormat: dateFormat,
                  isSelected: selectedIds.contains(q.id),
                  onSelect: (v) => onSelectRow(q.id, v),
                  onActionTap: () => onActionTap(q),
                )),

          // ── Pagination ─────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8EEE9))),
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${rows.isEmpty ? 0 : currentPage * pageSize + 1}–'
                  '${(currentPage * pageSize + rows.length)} of $totalCount entries',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Spacer(),
                _PaginationControls(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Color(0xFF8A9E94),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.quote,
    required this.dateFormat,
    required this.onActionTap,
    required this.isSelected,
    required this.onSelect,
  });

  final QuoteRecord quote;
  final DateFormat dateFormat;
  final bool isSelected;
  final ValueChanged<bool?> onSelect;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(quote.userName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF2F6F4))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isSelected,
              onChanged: onSelect,
              activeColor: const Color(0xFF1B3D2F),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          // USER
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _Avatar(initials: initials),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        quote.userEmail,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CREATOR
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.creatorName.isNotEmpty ? quote.creatorName : '—',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _tableLabel(quote.productTable),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // PRODUCT
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.productTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (quote.metalType.isNotEmpty)
                  Text(
                    quote.metalType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // DATE
          Expanded(
            flex: 2,
            child: Text(
              quote.createdAt != null
                  ? dateFormat.format(quote.createdAt!)
                  : '—',
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // STATUS badge
          Expanded(
            flex: 2,
            child: _StatusBadge(status: quote.status),
          ),

          // ACTIONS
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.more_vert, size: 18),
              onPressed: onActionTap,
              tooltip: 'View details',
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _tableLabel(String table) {
    if (table.contains('designer')) return 'Designer';
    if (table.contains('manufacturer')) return 'Manufacturer';
    return 'Standard';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8E2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1B3D2F),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'responded' => ('Responded', const Color(0xFFE6F6EE), const Color(0xFF1E7C4A)),
      'closed' => ('Closed', const Color(0xFFF0F0F0), const Color(0xFF666666)),
      _ => ('Pending', const Color(0xFFFFF3DC), const Color(0xFF96730A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Pagination ───────────────────────────────────────────────────────────────

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    // Show prev, up to 3 page numbers, next
    final pages = <int>[];
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i >= 0 && i < totalPages) pages.add(i);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PageBtn(
          icon: Icons.chevron_left,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        ...pages.map((p) => _PageNumBtn(
              page: p,
              isActive: p == currentPage,
              onTap: () => onPageChanged(p),
            )),
        _PageBtn(
          icon: Icons.chevron_right,
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE5E0)),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? const Color(0xFF1B3D2F) : Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _PageNumBtn extends StatelessWidget {
  const _PageNumBtn({
    required this.page,
    required this.isActive,
    required this.onTap,
  });
  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1B3D2F) : Colors.white,
          border: Border.all(
            color: isActive ? const Color(0xFF1B3D2F) : const Color(0xFFDDE5E0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          '${page + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF1B3D2F),
          ),
        ),
      ),
    );
  }
}

// ── Queue Capacity Card ──────────────────────────────────────────────────────

class _QueueCapacityCard extends StatelessWidget {
  const _QueueCapacityCard({
    required this.designerCapacity,
    required this.manufacturerCapacity,
  });

  final double designerCapacity;
  final double manufacturerCapacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E8E4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue Capacity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF1B3D2F),
            ),
          ),
          const SizedBox(height: 20),
          _CapacityBar(
            label: 'DESIGNER PRODUCTS',
            value: designerCapacity,
          ),
          const SizedBox(height: 16),
          _CapacityBar(
            label: 'MANUFACTURER PRODUCTS',
            value: manufacturerCapacity,
          ),
        ],
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.label, required this.value});
  final String label;
  final double value; // 0.0 – 1.0

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Color(0xFF668A73),
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B3D2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: const Color(0xFFEEF3F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC49A1D)),
          ),
        ),
      ],
    );
  }
}

// ── Insight Card ─────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.topMetal});
  final String topMetal;

  @override
  Widget build(BuildContext context) {
    final hasData = topMetal.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3D2F),
        borderRadius: BorderRadius.circular(10),
        image: const DecorationImage(
          image: AssetImage('assets/jewel_pattern.png'),
          fit: BoxFit.cover,
          opacity: 0.07,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSIGHT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Color(0xFF93C5A8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasData
                ? '$topMetal inquiries are leading this period.'
                : 'No inquiry data available yet.',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasData
                ? 'Consider prioritizing quote requests involving $topMetal designs to capitalise on current collector interest.'
                : 'More data will appear as quote requests come in.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFB3CEBC),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quote Detail Dialog ──────────────────────────────────────────────────────

class _QuoteDetailDialog extends StatefulWidget {
  const _QuoteDetailDialog({
    required this.quote,
    required this.dateFormat,
    required this.onReply,
    required this.onStatusUpdate,
  });

  final QuoteRecord quote;
  final DateFormat dateFormat;
  final Function(String) onReply;
  final Function(String) onStatusUpdate;

  @override
  State<_QuoteDetailDialog> createState() => _QuoteDetailDialogState();
}

class _QuoteDetailDialogState extends State<_QuoteDetailDialog> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _showReplyBox = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF7FAF8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.quote.productTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF1B3D2F),
                      ),
                    ),
                  ),
                  _StatusBadge(status: widget.quote.status),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'User', value: widget.quote.userName),
              _DetailRow(label: 'Email', value: widget.quote.userEmail),
              if (widget.quote.creatorName.isNotEmpty)
                _DetailRow(label: 'Creator', value: widget.quote.creatorName),
              _DetailRow(label: 'Product table', value: widget.quote.productTable),
              if (widget.quote.metalType.isNotEmpty)
                _DetailRow(label: 'Metal type', value: widget.quote.metalType),
              _DetailRow(
                label: 'Requested on',
                value: widget.quote.createdAt != null
                    ? widget.dateFormat.format(widget.quote.createdAt!)
                    : '—',
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),

              if (!_showReplyBox)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.quote.status == 'pending')
                      _ActionBtn(
                        label: 'Mark as Closed',
                        onTap: () => widget.onStatusUpdate('closed'),
                        isSecondary: true,
                      ),
                    const SizedBox(width: 12),
                    _ActionBtn(
                      label: widget.quote.status == 'responded'
                          ? 'Send Another Response'
                          : 'Respond to Request',
                      onTap: () => setState(() => _showReplyBox = true),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Compose Response',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3D2F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _msgCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type your message to the user here…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDE5E0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _showReplyBox = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        _ActionBtn(
                          label: 'Send Response',
                          onTap: () => widget.onReply(_msgCtrl.text),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: isSecondary ? Colors.white : const Color(0xFF1B3D2F),
        foregroundColor: isSecondary ? const Color(0xFF1B3D2F) : Colors.white,
        side: isSecondary ? const BorderSide(color: Color(0xFFDDE5E0)) : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

// ── Bulk Action Bar ──────────────────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.isProcessing,
    required this.onClose,
    required this.onRespond,
    required this.onCancel,
  });

  final int selectedCount;
  final bool isProcessing;
  final VoidCallback onClose;
  final VoidCallback onRespond;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3D2F),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$selectedCount selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 24),
              _BulkBtn(
                label: 'Close',
                onTap: isProcessing ? null : onClose,
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(width: 12),
              _BulkBtn(
                label: 'Respond',
                onTap: isProcessing ? null : onRespond,
                icon: Icons.reply_all_rounded,
              ),
              const VerticalDivider(color: Colors.white24, width: 24, indent: 8, endIndent: 8),
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.label,
    required this.onTap,
    required this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Color(0xFF1B3D2F)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
