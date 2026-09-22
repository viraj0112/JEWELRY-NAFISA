import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';
import '../widgets/admin_skeletons.dart';

enum _UserTypeFilter {
  all('All Users'),
  designers('Designers'),
  manufacturers('Manufacturers'),
  customers('Customers'),
  admins('Admins');

  const _UserTypeFilter(this.label);
  final String label;
}

enum _UserSort {
  lastActivity('Last Activity'),
  newest('Newest Joined'),
  highestCredit('Highest Credit'),
  nameAZ('Name (A-Z)'),
  highestViews('Most Views'),
  highestLikes('Most Likes'),
  highestShares('Most Shares');

  const _UserSort(this.label);
  final String label;
}

// Shared palette for this screen.
const _ink = Color(0xFF1F312C);
const _muted = Color(0xFF5D6D67);
const _accent = Color(0xFF0A4F3F);
const _border = Color(0xFFE0E6E3);
const _panel = Color(0xFFF6F9F7);

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.rows,
    required this.searchQuery,
    required this.dateFormat,
    required this.onRequestRefresh,
  });

  final List<UserLedgerRow> rows;
  final String searchQuery;
  final DateFormat dateFormat;
  final VoidCallback onRequestRefresh;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final NumberFormat _creditsFormat = NumberFormat.decimalPattern('en_IN');

  _UserTypeFilter _userTypeFilter = _UserTypeFilter.all;
  _UserSort _userSort = _UserSort.lastActivity;
  // Filters on the account's join date (users.created_at).
  DateTimeRange? _joinedRange;

  // Engagement filters
  int _minViews = 0;
  int _minLikes = 0;
  int _minShares = 0;

  // Only designer / manufacturer accounts still awaiting a decision.
  bool _pendingOnly = false;

  bool _creatingAccount = false;
  final Set<String> _selectedUserIds = {};

  static const int _pageSize = 25;
  int _page = 0;

  @override
  void didUpdateWidget(covariant UserManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new search (typed in the admin top bar) starts from the first page.
    if (oldWidget.searchQuery != widget.searchQuery) _page = 0;
  }

  /// Applies a filter change and jumps back to the first page.
  void _updateFilters(VoidCallback change) {
    setState(() {
      change();
      _page = 0;
    });
  }

  bool get _hasActiveFilters =>
      _userTypeFilter != _UserTypeFilter.all ||
      _joinedRange != null ||
      _minViews > 0 ||
      _minLikes > 0 ||
      _minShares > 0 ||
      _pendingOnly;

  void _resetFilters() => _updateFilters(() {
        _userTypeFilter = _UserTypeFilter.all;
        _joinedRange = null;
        _minViews = 0;
        _minLikes = 0;
        _minShares = 0;
        _pendingOnly = false;
      });

  // Every filter except the user type; the type tabs show counts over this.
  bool _matchesNonTypeFilters(UserLedgerRow row, String query) {
    if (_pendingOnly && !_needsApproval(row)) return false;
    if (row.totalViews < _minViews) return false;
    if (row.totalLikes < _minLikes) return false;
    if (row.totalShares < _minShares) return false;

    final range = _joinedRange;
    if (range != null) {
      final joined = row.createdAt?.toLocal();
      if (joined == null) return false;
      final d = DateTime(joined.year, joined.month, joined.day);
      final start =
          DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }

    if (query.isEmpty) return true;
    return row.name.toLowerCase().contains(query) ||
        row.email.toLowerCase().contains(query) ||
        row.phone.toLowerCase().contains(query) ||
        row.role.toLowerCase().contains(query);
  }

  DateTime _activityOf(UserLedgerRow row) =>
      row.lastActivityAt ??
      row.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    final base =
        widget.rows.where((row) => _matchesNonTypeFilters(row, query)).toList();
    final typeCounts = <_UserTypeFilter, int>{
      _UserTypeFilter.all: base.length,
      for (final t in _UserTypeFilter.values.skip(1))
        t: base.where((r) => _userRoleType(r) == t).length,
    };
    final filtered =
        base.where((row) => _matchesUserFilter(row, _userTypeFilter)).toList();

    filtered.sort((a, b) {
      switch (_userSort) {
        case _UserSort.lastActivity:
          return _activityOf(b).compareTo(_activityOf(a));
        case _UserSort.newest:
          final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        case _UserSort.highestCredit:
          return b.creditsRemaining.compareTo(a.creditsRemaining);
        case _UserSort.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _UserSort.highestViews:
          return b.totalViews.compareTo(a.totalViews);
        case _UserSort.highestLikes:
          return b.totalLikes.compareTo(a.totalLikes);
        case _UserSort.highestShares:
          return b.totalShares.compareTo(a.totalShares);
      }
    });

    final pageCount =
        filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final pageRows = filtered.skip(page * _pageSize).take(_pageSize).toList();

    final visibleIds = filtered.map((r) => r.id).toSet();
    final selectedVisible = _selectedUserIds.where(visibleIds.contains).length;

    final totalCreditExposure = filtered.fold<int>(
      0,
      (sum, row) => sum + row.creditsRemaining,
    );
    final activeManufacturers = filtered
        .where((row) =>
            _userRoleType(row) == _UserTypeFilter.manufacturers &&
            row.approvalStatus.toLowerCase() == 'approved')
        .length;
    final pendingApprovals = filtered.where(_needsApproval).length;
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _selectedUserIds.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildSelectionBar(selectedVisible),
                ),
        ),
        const SizedBox(height: 18),
        _buildStatCards(
          totalCreditExposure: totalCreditExposure,
          accounts: filtered.length,
          activeManufacturers: activeManufacturers,
          pendingApprovals: pendingApprovals,
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildTypeTabs(typeCounts),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: _buildToolbar(filtered.length),
              ),
              const Divider(height: 1, color: _border),
              if (filtered.isEmpty)
                _buildEmptyState()
              else if (!isCompact)
                _buildUserLedgerTable(pageRows)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                  child: Column(
                    children: pageRows.map(_buildUserLedgerMobileTile).toList(),
                  ),
                ),
              if (filtered.isNotEmpty) ...[
                const Divider(height: 1, color: _border),
                _buildPager(page, pageCount, filtered.length, pageRows.length),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 920;
            final insightCard =
                _buildLedgerInsightCard(totalCreditExposure, filtered);
            final syncCard = _buildSyncStatusCard(activeManufacturers);
            if (stacked) {
              return Column(
                children: [
                  insightCard,
                  const SizedBox(height: 12),
                  syncCard,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: insightCard),
                  const SizedBox(width: 12),
                  Expanded(child: syncCard),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sync started for Google Sheets')),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('Sync Google Sheets'),
        ),
        FilledButton.icon(
          onPressed: _creatingAccount ? null : _showCreateAccountDialog,
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          icon: _creatingAccount
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('New Account'),
        ),
      ],
    );
    const title = _PageTitle(
      title: 'User & Credit Ledger',
      subtitle:
          'Oversee financial relationships with artisans, suppliers, and VIP clients.',
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 14), actions],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(child: title),
          const SizedBox(width: 16),
          actions,
        ],
      );
    });
  }

  Widget _buildSelectionBar(int selectedVisible) {
    final hidden = _selectedUserIds.length - selectedVisible;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCE0D8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1B7A59), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hidden > 0
                  ? '${_selectedUserIds.length} users selected · $hidden hidden by filters'
                  : '${_selectedUserIds.length} users selected',
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedUserIds.clear()),
            child: const Text('Clear selection'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards({
    required int totalCreditExposure,
    required int accounts,
    required int activeManufacturers,
    required int pendingApprovals,
  }) {
    final cards = [
      _LedgerStatCard(
        label: 'Total Credit Exposure',
        value: _formatCredits(totalCreditExposure),
        hint: '$accounts accounts tracked',
        accentColor: const Color(0xFF1B7A59),
        icon: Icons.trending_up,
      ),
      _LedgerStatCard(
        label: 'Active Manufacturers',
        value: '$activeManufacturers',
        hint: 'Verified manufacturing accounts',
        accentColor: _accent,
        icon: Icons.factory_outlined,
      ),
      _LedgerStatCard(
        label: 'Pending Approvals',
        value: '$pendingApprovals',
        hint: pendingApprovals > 0
            ? 'Designer & manufacturer accounts awaiting review'
            : 'No pending actions',
        accentColor: const Color(0xFF9D6A00),
        icon: Icons.schedule,
        onTap: pendingApprovals > 0 || _pendingOnly
            ? () => _updateFilters(() => _pendingOnly = !_pendingOnly)
            : null,
        active: _pendingOnly,
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 3
          : constraints.maxWidth >= 640
              ? 2
              : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in cards) SizedBox(width: width, child: c)],
      );
    });
  }

  Widget _buildTypeTabs(Map<_UserTypeFilter, int> counts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _UserTypeFilter.values.map((filter) {
            final active = _userTypeFilter == filter;
            final count = counts[filter] ?? 0;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _updateFilters(() => _userTypeFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : _muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: active ? null : Border.all(color: _border),
                        ),
                        child: Text(
                          _creditsFormat.format(count),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildToolbar(int shown) {
    final range = _joinedRange;
    final rangeLabel = range == null
        ? 'Joined: any time'
        : 'Joined: ${widget.dateFormat.format(range.start)} – ${widget.dateFormat.format(range.end)}';

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ToolbarMenu<_UserSort>(
          icon: Icons.swap_vert_rounded,
          label: 'Sort: ${_userSort.label}',
          value: _userSort,
          values: _UserSort.values,
          labelOf: (s) => s.label,
          onSelected: (s) => _updateFilters(() => _userSort = s),
        ),
        _FilterPill(
          icon: Icons.pending_actions_outlined,
          label: 'Pending approval',
          active: _pendingOnly,
          onTap: () => _updateFilters(() => _pendingOnly = !_pendingOnly),
          onClear: _pendingOnly
              ? () => _updateFilters(() => _pendingOnly = false)
              : null,
        ),
        _FilterPill(
          icon: Icons.calendar_month_outlined,
          label: rangeLabel,
          active: range != null,
          onTap: _pickJoinedRange,
          onClear: range == null
              ? null
              : () => _updateFilters(() => _joinedRange = null),
        ),
        _EngagementThresholdChip(
          label: 'Min Views',
          value: _minViews,
          onChanged: (v) => _updateFilters(() => _minViews = v),
        ),
        _EngagementThresholdChip(
          label: 'Min Likes',
          value: _minLikes,
          onChanged: (v) => _updateFilters(() => _minLikes = v),
        ),
        _EngagementThresholdChip(
          label: 'Min Shares',
          value: _minShares,
          onChanged: (v) => _updateFilters(() => _minShares = v),
        ),
        if (_hasActiveFilters)
          TextButton.icon(
            onPressed: _resetFilters,
            style: TextButton.styleFrom(foregroundColor: _muted),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset filters'),
          ),
      ],
    );

    final count = Text(
      'Showing ${_creditsFormat.format(shown)} of ${_creditsFormat.format(widget.rows.length)} accounts',
      style: const TextStyle(
        color: _muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 1000) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [controls, const SizedBox(height: 10), count],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: controls),
          const SizedBox(width: 12),
          count,
        ],
      );
    });
  }

  Future<void> _pickJoinedRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _joinedRange,
      helpText: 'Filter by join date',
      saveText: 'Apply',
    );
    if (picked != null) _updateFilters(() => _joinedRange = picked);
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: _panel,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_search_outlined,
                  color: _muted, size: 26),
            ),
            const SizedBox(height: 12),
            const Text(
              'No accounts match these filters',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 4),
            Text(
              widget.searchQuery.trim().isEmpty
                  ? 'Try widening the date range or lowering the engagement minimums.'
                  : 'Nothing matches “${widget.searchQuery.trim()}” with the current filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _resetFilters,
                child: const Text('Reset filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPager(int page, int pageCount, int total, int onPage) {
    final start = page * _pageSize + 1;
    final end = page * _pageSize + onPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$start–$end of ${_creditsFormat.format(total)}',
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed:
                page == 0 ? null : () => setState(() => _page = page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            'Page ${page + 1} of $pageCount',
            style: const TextStyle(
                color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page >= pageCount - 1
                ? null
                : () => setState(() => _page = page + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  void _toggleSelected(String id, bool? value) {
    setState(() {
      if (value == true) {
        _selectedUserIds.add(id);
      } else {
        _selectedUserIds.remove(id);
      }
    });
  }

  Widget _buildUserLedgerTable(List<UserLedgerRow> rows) {
    final pageIds = rows.map((r) => r.id).toList();
    final selectedOnPage = pageIds.where(_selectedUserIds.contains).length;
    final bool? headerValue = selectedOnPage == 0
        ? false
        : selectedOnPage == pageIds.length
            ? true
            : null;
    const numStyle = TextStyle(color: Color(0xFF5E6F68));

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 46,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 72,
              horizontalMargin: 16,
              columnSpacing: 24,
              dividerThickness: 0.6,
              headingRowColor: const WidgetStatePropertyAll(_panel),
              headingTextStyle: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
              columns: [
                DataColumn(
                  label: Checkbox(
                    tristate: true,
                    value: headerValue,
                    activeColor: _accent,
                    onChanged: (_) {
                      setState(() {
                        if (headerValue == true) {
                          _selectedUserIds.removeAll(pageIds);
                        } else {
                          _selectedUserIds.addAll(pageIds);
                        }
                      });
                    },
                  ),
                ),
                const DataColumn(label: Text('USER')),
                const DataColumn(label: Text('TYPE')),
                const DataColumn(label: Text('CREDITS'), numeric: true),
                const DataColumn(label: Text('DOCUMENTS')),
                const DataColumn(label: Text('VIEWS'), numeric: true),
                const DataColumn(label: Text('LIKES'), numeric: true),
                const DataColumn(label: Text('SHARES'), numeric: true),
                const DataColumn(label: Text('LAST ACTIVITY')),
                const DataColumn(label: Text('ACTIONS')),
              ],
              rows: rows
                  .map(
                    (row) => DataRow(
                      selected: _selectedUserIds.contains(row.id),
                      color: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFFEFF6F2);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return const Color(0xFFF7FAF8);
                        }
                        return null;
                      }),
                      onSelectChanged: (val) => _toggleSelected(row.id, val),
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedUserIds.contains(row.id),
                            activeColor: _accent,
                            onChanged: (val) => _toggleSelected(row.id, val),
                          ),
                        ),
                        DataCell(_UserIdentity(row: row)),
                        DataCell(_UserTypeBadge(
                          role: row.role,
                          pending: _needsApproval(row),
                        )),
                        DataCell(
                          Text(
                            _creditsFormat.format(row.creditsRemaining),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _accent,
                            ),
                          ),
                        ),
                        DataCell(_DocumentsCell(
                          row: row,
                          onOpen: () => _showDocumentsDialog(row),
                        )),
                        DataCell(Text(_creditsFormat.format(row.totalViews),
                            style: numStyle)),
                        DataCell(Text(_creditsFormat.format(row.totalLikes),
                            style: numStyle)),
                        DataCell(Text(_creditsFormat.format(row.totalShares),
                            style: numStyle)),
                        DataCell(
                          Text(
                            _formatLastActivity(
                              row.lastActivityAt ?? row.createdAt,
                            ),
                            style: numStyle,
                          ),
                        ),
                        DataCell(_buildRowActions(row)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowActions(UserLedgerRow row) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_needsApproval(row)) ...[
          FilledButton(
            onPressed: () => _onUpdateApproval(row, approve: true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF006435),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('Approve'),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _onUpdateApproval(row, approve: false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9D241B),
              visualDensity: VisualDensity.compact,
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          tooltip: 'Adjust credits',
          visualDensity: VisualDensity.compact,
          onPressed: () => _onAdjustCredits(row),
          icon: const Icon(Icons.account_balance_wallet_outlined,
              size: 19, color: Color(0xFF7A6200)),
        ),
        IconButton(
          tooltip: 'View ledger',
          visualDensity: VisualDensity.compact,
          onPressed: () => _onViewLedger(row),
          icon: const Icon(Icons.receipt_long_outlined,
              size: 19, color: Color(0xFF495A53)),
        ),
      ],
    );
  }

  Widget _buildUserLedgerMobileTile(UserLedgerRow row) {
    final selected = _selectedUserIds.contains(row.id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6F2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                selected ? const Color(0xFFBBD7CA) : const Color(0xFFE2E8E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            activeColor: _accent,
            onChanged: (val) => _toggleSelected(row.id, val),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _UserIdentity(row: row)),
                    const SizedBox(width: 8),
                    _UserTypeBadge(
                        role: row.role, pending: _needsApproval(row)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      _formatCredits(row.creditsRemaining),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                    const Spacer(),
                    _EngagementStat(
                        icon: Icons.visibility_outlined, value: row.totalViews),
                    const SizedBox(width: 12),
                    _EngagementStat(
                        icon: Icons.thumb_up_outlined, value: row.totalLikes),
                    const SizedBox(width: 12),
                    _EngagementStat(
                        icon: Icons.share_outlined, value: row.totalShares),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DocumentsCell(
                        row: row,
                        onOpen: () => _showDocumentsDialog(row),
                      ),
                    ),
                    Text(
                      _formatLastActivity(row.lastActivityAt ?? row.createdAt),
                      style: const TextStyle(
                          color: Color(0xFF5E6F68), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildRowActions(row),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerInsightCard(
    int totalCreditExposure,
    List<UserLedgerRow> filteredRows,
  ) {
    final selectedInView =
        filteredRows.where((r) => _selectedUserIds.contains(r.id)).length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF032E26), Color(0xFF0A4F3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Ledger Insights',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE9D08F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current tracked exposure is ${_formatCredits(totalCreditExposure)} '
            'across ${filteredRows.length} accounts. '
            'Review high-balance accounts before the next appraisal cycle.',
            style: const TextStyle(color: Color(0xFFD2DDD8), height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE9C869),
              foregroundColor: const Color(0xFF2F2B1F),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: filteredRows.isEmpty
                ? null
                : () => _downloadFilteredCsv(filteredRows),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(selectedInView == 0
                ? 'Download all (${filteredRows.length} filtered)'
                : 'Download selected ($selectedInView)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(int activeManufacturers) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.stars_rounded,
                    color: Color(0xFF9D6A00), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sync Status',
                style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$activeManufacturers verified manufacturers detected.',
            style: const TextStyle(color: Color(0xFF5E6F68)),
          ),
          const SizedBox(height: 12),
          const Divider(color: _border),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF1B7A59)),
              SizedBox(width: 6),
              Text(
                'CLOUD CONNECTED',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A8A84),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onAdjustCredits(UserLedgerRow row) {
    _showAdjustCreditsDialog(row);
  }

  void _onViewLedger(UserLedgerRow row) {
    _showLedgerDialog(row);
  }

  // Only business accounts go through approval; customers and admins keep the
  // column's default 'pending' value but never need a decision.
  bool _needsApproval(UserLedgerRow row) {
    final type = _userRoleType(row);
    if (type != _UserTypeFilter.designers &&
        type != _UserTypeFilter.manufacturers) {
      return false;
    }
    return row.approvalStatus.toLowerCase() == 'pending';
  }

  Future<void> _onUpdateApproval(
    UserLedgerRow row, {
    required bool approve,
  }) async {
    try {
      await Supabase.instance.client.from('users').update({
        'approval_status': approve ? 'approved' : 'rejected',
        'is_approved': approve,
      }).eq('id', row.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? '${row.name} approved' : '${row.name} rejected',
          ),
        ),
      );
      widget.onRequestRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Failed to approve ${row.name}: $e'
                : 'Failed to reject ${row.name}: $e',
          ),
        ),
      );
    }
  }

  bool _matchesUserFilter(UserLedgerRow row, _UserTypeFilter filter) {
    if (filter == _UserTypeFilter.all) return true;
    return _userRoleType(row) == filter;
  }

  _UserTypeFilter _userRoleType(UserLedgerRow row) {
    final role = row.role.toLowerCase();
    if (role.contains('admin')) return _UserTypeFilter.admins;
    if (role.contains('designer')) return _UserTypeFilter.designers;
    if (role.contains('manufacturer') || role.contains('supplier')) {
      return _UserTypeFilter.manufacturers;
    }
    return _UserTypeFilter.customers;
  }

  String _formatLastActivity(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inHours < 48) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    }
    return widget.dateFormat.format(date);
  }

  String _formatCredits(int value) {
    return '${_creditsFormat.format(value)} credits';
  }

  Future<void> _showAdjustCreditsDialog(UserLedgerRow row) async {
    final adjustmentController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Adjust Credits - ${row.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: adjustmentController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Credits delta',
                hintText: 'Use positive or negative value',
              ),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null) return 'Enter a valid number';
                if (parsed == 0) return 'Adjustment cannot be zero';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.of(dialogContext)
                    .pop(int.parse(adjustmentController.text.trim()));
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    try {
      final updatedCredits = (row.creditsRemaining + result).clamp(0, 9999999);
      await Supabase.instance.client
          .from('users')
          .update({'credits_remaining': updatedCredits}).eq('id', row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credits updated for ${row.name}')),
      );
      widget.onRequestRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update credits: $e')),
      );
    }
  }

  /// Registration documents for one user, with links that open in a new tab.
  ///
  /// Pending documents have no public URL, so a short-lived signed URL is
  /// minted on demand. Deliberately not pre-generated for every row: that
  /// would create dozens of live links to private business documents on every
  /// page load, most of which nobody opens.
  Future<void> _showDocumentsDialog(UserLedgerRow row) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Documents - ${row.name}'),
        content: SizedBox(
          width: 460,
          child: row.documents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No registration documents found for this user.\n\n'
                    'Customers do not upload any. For a designer or '
                    'manufacturer, this usually means the signup did not '
                    'complete the document step.',
                    style: TextStyle(color: Color(0xFF5D6D67)),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: row.documents
                      .map((doc) => _documentTile(row, doc))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(UserLedgerRow row, UserDocument doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            doc.fileType == 'business_card'
                ? Icons.badge_outlined
                : Icons.description_outlined,
            size: 20,
            color: const Color(0xFF0A4F3F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  doc.isPending
                      ? 'Awaiting account activation'
                      : 'Verified upload',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: doc.isPending
                        ? const Color(0xFF9D6A00)
                        : const Color(0xFF5D6D67),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _openDocument(doc),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(UserDocument doc) async {
    // Always prefer a signed URL. The bucket is private, so the stored
    // getPublicUrl() links on finalised documents do not resolve - the object
    // path is the only thing that reliably opens the file.
    final path =
        doc.objectPath ?? NewAdminDataService.objectPathFromUrl(doc.url);

    String? url;
    if (path != null && path.isNotEmpty) {
      url = await NewAdminDataService().createDocumentSignedUrl(path);
    }
    url ??= doc.url;

    if (url == null || url.isEmpty) {
      _snack('Could not open the document. It may have been moved.');
      return;
    }
    if (kIsWeb) {
      html.window.open(url, '_blank');
    } else {
      await Clipboard.setData(ClipboardData(text: url));
      _snack('Document link copied to clipboard.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLedgerDialog(UserLedgerRow row) async {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchUserLedgerSummary(row.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  width: 420,
                  height: 220,
                  child: AdminSkeletonView(
                    variant: AdminSkeletonVariant.detail,
                    padding: EdgeInsets.zero,
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Ledger'),
                content: Text('Failed to load ledger: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            final data = snapshot.data ?? {};
            return AlertDialog(
              title: Text('Ledger - ${row.name}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ledgerLine('Current Credits', '${data['credits'] ?? 0}'),
                    _ledgerLine(
                      'Quote Requests',
                      '${data['quoteRequests'] ?? 0}',
                    ),
                    _ledgerLine(
                      'Referral Credits Earned',
                      '${data['referralCredits'] ?? 0}',
                    ),
                    _ledgerLine(
                      'Last Referral',
                      data['lastReferral'] ?? '-',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _ledgerLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5D6D67),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchUserLedgerSummary(String userId) async {
    final client = Supabase.instance.client;
    final userRows = await client
        .from('users')
        .select('credits_remaining')
        .eq('id', userId)
        .limit(1);
    final credits = userRows.isEmpty
        ? 0
        : _parseCredits(userRows.first['credits_remaining']);

    final quoteRows =
        await client.from('quote_requests').select('id').eq('user_id', userId);

    final referralRows = await client
        .from('referrals')
        .select('credits_awarded,created_at')
        .eq('referrer_id', userId)
        .order('created_at', ascending: false);

    final referralCredits = referralRows.fold<int>(
      0,
      (sum, item) => sum + _parseCredits(item['credits_awarded']),
    );
    String? lastReferral;
    if (referralRows.isNotEmpty) {
      final rawDate = referralRows.first['created_at'];
      DateTime? parsed;
      if (rawDate is String) {
        parsed = DateTime.tryParse(rawDate);
      } else if (rawDate is DateTime) {
        parsed = rawDate;
      }
      if (parsed != null) {
        lastReferral = DateFormat('MMM d, yyyy').format(parsed);
      }
    }

    return {
      'credits': credits,
      'quoteRequests': quoteRows.length,
      'referralCredits': referralCredits,
      'lastReferral': lastReferral ?? '-',
    };
  }

  int _parseCredits(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  Future<void> _downloadFilteredCsv(List<UserLedgerRow> filteredRows) async {
    final rowsToExport = _selectedUserIds.isEmpty
        ? filteredRows
        : filteredRows.where((r) => _selectedUserIds.contains(r.id)).toList();

    final now = DateTime.now();
    final exportDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final rows = <List<dynamic>>[
      ['User Management Ledger Report'],
      ['Generated At', exportDate],
      ['Filter', _userTypeFilter.label],
      [
        'Joined',
        _joinedRange == null
            ? 'Any time'
            : '${widget.dateFormat.format(_joinedRange!.start)} - ${widget.dateFormat.format(_joinedRange!.end)}'
      ],
      ['Pending Approval Only', _pendingOnly ? 'Yes' : 'No'],
      ['Min Views / Likes / Shares', '$_minViews / $_minLikes / $_minShares'],
      ['Sort', _userSort.label],
      [
        'Search Query',
        widget.searchQuery.trim().isEmpty ? '-' : widget.searchQuery.trim()
      ],
      ['Total Rows', rowsToExport.length],
      [
        'Selection Status',
        _selectedUserIds.isEmpty ? 'All Filtered' : 'Manually Selected'
      ],
      [],
      [
        'User ID',
        'Name',
        'Email',
        'Phone',
        'Role',
        'Membership',
        'Credits Remaining',
        'Approval Status',
        'Last Credit Refresh',
        'Created At',
      ],
      ...rowsToExport.map(
        (row) => [
          row.id,
          row.name,
          row.email,
          row.phone,
          row.role,
          row.isMember ? 'Member' : 'Non-member',
          row.creditsRemaining,
          row.approvalStatus,
          row.lastCreditRefresh?.toIso8601String() ?? '',
          row.createdAt?.toIso8601String() ?? '',
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final fileName =
        'user_ledger_${now.toIso8601String().replaceAll(':', '-')}.csv';

    if (kIsWeb) {
      final uri = Uri.dataFromString(
        csv,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      html.AnchorElement(href: uri.toString())
        ..setAttribute('download', fileName)
        ..click();
      return;
    }

    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard (web download is automatic).'),
      ),
    );
  }

  Future<void> _showCreateAccountDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final creditsController = TextEditingController(text: '0');
    _UserTypeFilter selectedType = _UserTypeFilter.customers;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Create New Account'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter valid email'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Min 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<_UserTypeFilter>(
                        initialValue: selectedType,
                        decoration:
                            const InputDecoration(labelText: 'Account type'),
                        items: const [
                          DropdownMenuItem(
                            value: _UserTypeFilter.customers,
                            child: Text('Customer'),
                          ),
                          DropdownMenuItem(
                            value: _UserTypeFilter.designers,
                            child: Text('Designer'),
                          ),
                          DropdownMenuItem(
                            value: _UserTypeFilter.manufacturers,
                            child: Text('Manufacturer'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() => selectedType = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: creditsController,
                        decoration: const InputDecoration(
                          labelText: 'Initial credits',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final parsed = int.tryParse(v?.trim() ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Enter 0 or higher';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'password': passwordController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'credits': int.parse(creditsController.text.trim()),
                      'type': selectedType,
                    });
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || payload == null) return;

    setState(() => _creatingAccount = true);
    try {
      final userType = payload['type'] as _UserTypeFilter;
      final role = switch (userType) {
        _UserTypeFilter.designers => 'designer',
        _UserTypeFilter.manufacturers => 'manufacturer',
        _ => 'member',
      };

      final fullName = payload['name'] as String;
      final email = payload['email'] as String;
      final password = payload['password'] as String;
      final phone = payload['phone'] as String;
      final credits = payload['credits'] as int;
      final username = _usernameFromName(fullName);

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Failed to create auth user');
      }

      await Supabase.instance.client.from('users').upsert({
        'id': user.id,
        'full_name': fullName,
        'username': username,
        'email': email,
        'phone': phone.isEmpty ? null : phone,
        'role': role,
        'approval_status': 'approved',
        'credits_remaining': credits,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account created for $fullName')),
      );
      widget.onRequestRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingAccount = false);
      }
    }
  }

  String _usernameFromName(String fullName) {
    final normalized = fullName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) {
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '${normalized}_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth < 600 ? 26.0 : 34.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: titleFontSize,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF4D5F57), fontSize: 14),
        ),
      ],
    );
  }
}

class _LedgerStatCard extends StatefulWidget {
  const _LedgerStatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.accentColor,
    required this.icon,
    this.onTap,
    this.active = false,
  });

  final String label;
  final String value;
  final String hint;
  final Color accentColor;
  final IconData icon;

  /// When set the card acts as a filter toggle.
  final VoidCallback? onTap;
  final bool active;

  @override
  State<_LedgerStatCard> createState() => _LedgerStatCardState();
}

class _LedgerStatCardState extends State<_LedgerStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final interactive = widget.onTap != null;
    final highlighted = widget.active || (interactive && _hovered);
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 132,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:
                widget.active ? accent.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? accent.withValues(alpha: 0.45) : _border,
            ),
            boxShadow: [
              if (_hovered && interactive)
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: Color(0xFF6D7D77),
                      ),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 17, color: accent),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                  if (interactive)
                    Text(
                      widget.active ? 'Filtering ✓' : 'Filter →',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
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

/// Avatar initial + name + email.
class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.row});

  final UserLedgerRow row;

  @override
  Widget build(BuildContext context) {
    final name = row.name.trim().isEmpty ? row.email : row.name;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFE8F1ED),
          child: Text(
            initial,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _accent,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, color: _ink),
              ),
              if (row.email.isNotEmpty && row.email != name)
                Text(
                  row.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF61706A)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded toolbar pill used for every filter control, so they share one look.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final fg = active ? _accent : _muted;
    return Material(
      color: active ? const Color(0xFFE8F1ED) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: active ? const Color(0xFF9CC5B3) : _border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, onClear == null ? 14 : 6, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 15, color: fg),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A [_FilterPill] that opens a single-choice menu.
class _ToolbarMenu<T> extends StatelessWidget {
  const _ToolbarMenu({
    required this.icon,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Sort accounts',
      position: PopupMenuPosition.under,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => values
          .map((v) => PopupMenuItem<T>(
                value: v,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: v == value
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: _accent)
                          : null,
                    ),
                    Text(labelOf(v)),
                  ],
                ),
              ))
          .toList(),
      child: IgnorePointer(
        child: _FilterPill(
          icon: icon,
          label: label,
          active: false,
          onTap: () {},
        ),
      ),
    );
  }
}

class _UserTypeBadge extends StatelessWidget {
  const _UserTypeBadge({required this.role, this.pending = false});

  final String role;

  /// B2B account still awaiting approval.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final normalized = role.toLowerCase();
    late final Color fg;
    late final Color bg;
    late final Color border;
    late final String label;

    if (normalized.contains('designer')) {
      fg = const Color(0xFF255EBA);
      bg = const Color(0xFFEAF1FF);
      border = const Color(0xFFCEE0FF);
      label = 'Designer';
    } else if (normalized.contains('manufacturer') ||
        normalized.contains('supplier')) {
      fg = const Color(0xFF8A5A00);
      bg = const Color(0xFFFFF4DF);
      border = const Color(0xFFF9DFB1);
      label = 'Manufacturer';
    } else if (normalized.contains('admin')) {
      fg = const Color(0xFF5B3FA8);
      bg = const Color(0xFFF1ECFF);
      border = const Color(0xFFDCD0FA);
      label = 'Admin';
    } else {
      fg = const Color(0xFF1B7A59);
      bg = const Color(0xFFE8F7F1);
      border = const Color(0xFFCAE9DD);
      label = 'Customer';
    }

    Widget pill(String text, Color fg, Color bg, Color border) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(label, fg, bg, border),
        if (pending) ...[
          const SizedBox(width: 6),
          pill('Pending', const Color(0xFF9D6A00), const Color(0xFFFFF8E6),
              const Color(0xFFF3DDA6)),
        ],
      ],
    );
  }
}

class _EngagementThresholdChip extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _EngagementThresholdChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterPill(
      icon: value > 0 ? Icons.filter_alt : Icons.filter_alt_outlined,
      label: value > 0 ? '$label: $value+' : label,
      active: value > 0,
      onTap: () async {
        final result = await showDialog<int>(
          context: context,
          builder: (context) => _ThresholdDialog(
            label: label,
            initialValue: value,
          ),
        );
        if (result != null) onChanged(result);
      },
      onClear: value > 0 ? () => onChanged(0) : null,
    );
  }
}

/// Compact document indicator. Amber when something still needs attention
/// (missing documents on a B2B account, or uploads not yet finalised), so the
/// admin can spot incomplete registrations while scanning the approval queue.
class _DocumentsCell extends StatelessWidget {
  const _DocumentsCell({required this.row, required this.onOpen});

  final UserLedgerRow row;
  final VoidCallback onOpen;

  bool get _isB2b {
    final role = row.role.toLowerCase();
    return role.contains('designer') ||
        role.contains('manufacturer') ||
        role.contains('supplier');
  }

  @override
  Widget build(BuildContext context) {
    final docs = row.documents;

    if (docs.isEmpty) {
      // Customers never upload anything, so an empty list is only noteworthy
      // for a business account.
      return Text(
        _isB2b ? 'None uploaded' : '—',
        style: TextStyle(
          fontSize: 12,
          fontWeight: _isB2b ? FontWeight.w600 : FontWeight.w400,
          color: _isB2b ? const Color(0xFFA33A32) : const Color(0xFF9AA8A3),
        ),
      );
    }

    final pending = docs.where((d) => d.isPending).length;
    final color =
        pending > 0 ? const Color(0xFF9D6A00) : const Color(0xFF1B7A59);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pending > 0
                  ? Icons.pending_actions
                  : Icons.folder_shared_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              pending > 0
                  ? '${docs.length} file${docs.length == 1 ? '' : 's'} · $pending pending'
                  : '${docs.length} file${docs.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementStat extends StatelessWidget {
  final IconData icon;
  final int value;

  const _EngagementStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF5E6F68)),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5E6F68),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ThresholdDialog extends StatefulWidget {
  final String label;
  final int initialValue;

  const _ThresholdDialog({required this.label, required this.initialValue});

  @override
  State<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<_ThresholdDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == 0 ? '' : widget.initialValue.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Filter by ${widget.label}'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Minimum ${widget.label}',
          hintText: 'e.g. 100',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final val =
                (int.tryParse(_controller.text.trim()) ?? 0).clamp(0, 1 << 31);
            Navigator.pop(context, val);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
