import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../models/new_admin_models.dart';
import '../widgets/admin_skeletons.dart';

enum _UserTypeFilter {
  all('All Users'),
  designers('Designers'),
  manufacturers('Manufacturers'),
  customers('Customers');

  const _UserTypeFilter(this.label);
  final String label;
}

enum _UserSort {
  lastActivity('Last Activity'),
  highestCredit('Highest Credit'),
  nameAZ('Name (A-Z)');

  const _UserSort(this.label);
  final String label;
}

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
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  bool _creatingAccount = false;
  final Set<String> _selectedUserIds = {};

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    var filtered = widget.rows.where((row) {
      if (!_matchesUserFilter(row, _userTypeFilter)) return false;

      if (_startDateFilter != null || _endDateFilter != null) {
        final joined = row.createdAt;
        if (joined == null) return false;
        final d = DateTime(joined.year, joined.month, joined.day);

        if (_startDateFilter != null) {
          final start = DateTime(_startDateFilter!.year,
              _startDateFilter!.month, _startDateFilter!.day);
          if (d.isBefore(start)) return false;
        }

        if (_endDateFilter != null) {
          final end = DateTime(
              _endDateFilter!.year, _endDateFilter!.month, _endDateFilter!.day);
          if (d.isAfter(end)) return false;
        }
      }

      if (query.isEmpty) return true;
      return row.name.toLowerCase().contains(query) ||
          row.email.toLowerCase().contains(query) ||
          row.role.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_userSort) {
        case _UserSort.lastActivity:
          final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        case _UserSort.highestCredit:
          return b.creditsRemaining.compareTo(a.creditsRemaining);
        case _UserSort.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    final totalCreditExposure = filtered.fold<int>(
      0,
      (sum, row) => sum + row.creditsRemaining,
    );
    final activeManufacturers = filtered
        .where((row) =>
            _userRoleType(row) == _UserTypeFilter.manufacturers &&
            row.approvalStatus.toLowerCase() == 'approved')
        .length;
    final pendingApprovals = filtered
        .where((row) => row.approvalStatus.toLowerCase() != 'approved')
        .length;
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageTitle(
          title: 'User & Credit Ledger',
          subtitle:
              'Oversee financial relationships with artisans, suppliers, and VIP clients.',
        ),
        if (_selectedUserIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCE0D8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF1B7A59), size: 18),
                const SizedBox(width: 10),
                Text(
                  '${_selectedUserIds.length} users selected',
                  style: const TextStyle(
                    color: Color(0xFF0A4F3F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedUserIds.clear()),
                  child: const Text('Clear Selection'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sync started for Google Sheets')),
                );
              },
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Sync Google Sheets'),
            ),
            FilledButton.icon(
              onPressed: _creatingAccount ? null : _showCreateAccountDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('New Account'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 700
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: columns == 1 ? 2.5 : 2.0,
              children: [
                _LedgerStatCard(
                  label: 'Total Credit Exposure',
                  value: _formatCredits(totalCreditExposure),
                  hint: '${filtered.length} accounts tracked',
                  accentColor: const Color(0xFF1B7A59),
                  icon: Icons.trending_up,
                ),
                _LedgerStatCard(
                  label: 'Active Manufacturers',
                  value: '$activeManufacturers',
                  hint: 'Verified manufacturing accounts',
                  accentColor: const Color(0xFF0A4F3F),
                  icon: Icons.factory_outlined,
                ),
                _LedgerStatCard(
                  label: 'Pending Approvals',
                  value: '$pendingApprovals',
                  hint: pendingApprovals > 0
                      ? 'Action required'
                      : 'No pending actions',
                  accentColor: const Color(0xFF9D6A00),
                  icon: Icons.schedule,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _UserTypeFilter.values
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(filter.label.toUpperCase()),
                          selected: _userTypeFilter == filter,
                          onSelected: (_) =>
                              setState(() => _userTypeFilter = filter),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.filter_list,
                        size: 18, color: Color(0xFF5D6D67)),
                    const SizedBox(width: 8),
                    const Text(
                      'Sort by:',
                      style: TextStyle(
                        color: Color(0xFF5D6D67),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<_UserSort>(
                      value: _userSort,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _userSort = value);
                      },
                      items: _UserSort.values
                          .map(
                            (sort) => DropdownMenuItem<_UserSort>(
                              value: sort,
                              child: Text(sort.label),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(width: 16),
                    InputChip(
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_startDateFilter == null
                          ? 'From'
                          : 'From: ${widget.dateFormat.format(_startDateFilter!)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _startDateFilter = picked);
                        }
                      },
                      onDeleted: _startDateFilter == null
                          ? null
                          : () {
                              setState(() => _startDateFilter = null);
                            },
                    ),
                    const SizedBox(width: 8),
                    InputChip(
                      avatar: const Icon(Icons.event, size: 16),
                      label: Text(_endDateFilter == null
                          ? 'To'
                          : 'To: ${widget.dateFormat.format(_endDateFilter!)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDateFilter ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _endDateFilter = picked);
                        }
                      },
                      onDeleted: _endDateFilter == null
                          ? null
                          : () {
                              setState(() => _endDateFilter = null);
                            },
                    ),
                    if (MediaQuery.of(context).size.width >= 1000) ...[
                      const Spacer(),
                      Text(
                        'Showing ${filtered.length} of ${widget.rows.length} accounts',
                        style: const TextStyle(
                          color: Color(0xFF5D6D67),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (MediaQuery.of(context).size.width < 1000) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Showing ${filtered.length} of ${widget.rows.length} accounts',
                    style: const TextStyle(
                      color: Color(0xFF5D6D67),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (!isCompact) ...[
                  _buildUserLedgerTable(filtered),
                ] else ...[
                  ...filtered.take(25).map(_buildUserLedgerMobileTile),
                ],
              ],
            ),
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
            return Row(
              children: [
                Expanded(flex: 2, child: insightCard),
                const SizedBox(width: 12),
                Expanded(child: syncCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildUserLedgerTable(List<UserLedgerRow> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 56,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 72,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: rows.isNotEmpty &&
                        _selectedUserIds.length >= rows.take(25).length &&
                        rows
                            .take(25)
                            .every((r) => _selectedUserIds.contains(r.id)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedUserIds
                              .addAll(rows.take(25).map((r) => r.id));
                        } else {
                          _selectedUserIds
                              .removeAll(rows.take(25).map((r) => r.id));
                        }
                      });
                    },
                  ),
                ),
                const DataColumn(label: Text('User Name')),
                const DataColumn(label: Text('Type')),
                const DataColumn(label: Text('Credit Balance')),
                const DataColumn(label: Text('Joined Date')),
                const DataColumn(label: Text('Last Activity')),
                const DataColumn(label: Text('Actions')),
              ],
              rows: rows
                  .take(25)
                  .map(
                    (row) => DataRow(
                      selected: _selectedUserIds.contains(row.id),
                      onSelectChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(row.id);
                          } else {
                            _selectedUserIds.remove(row.id);
                          }
                        });
                      },
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedUserIds.contains(row.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedUserIds.add(row.id);
                                } else {
                                  _selectedUserIds.remove(row.id);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                row.email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF61706A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(_UserTypeBadge(role: row.role)),
                        DataCell(
                          Text(
                            _formatCredits(row.creditsRemaining),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A4F3F),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.createdAt != null
                                ? widget.dateFormat.format(row.createdAt!)
                                : '-',
                            style: const TextStyle(color: Color(0xFF5E6F68)),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatLastActivity(
                              row.lastActivityAt ?? row.createdAt,
                            ),
                            style: const TextStyle(color: Color(0xFF5E6F68)),
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              InkWell(
                                onTap: () => _onAdjustCredits(row),
                                child: const Text(
                                  'Adjust Credits',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF7A6200),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _onViewLedger(row),
                                child: const Text(
                                  'View Ledger',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF495A53),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildUserLedgerMobileTile(UserLedgerRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _selectedUserIds.contains(row.id),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedUserIds.add(row.id);
                } else {
                  _selectedUserIds.remove(row.id);
                }
              });
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF153F34),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.email,
                  style:
                      const TextStyle(color: Color(0xFF61706A), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _UserTypeBadge(role: row.role),
                    const Spacer(),
                    Text(
                      _formatCredits(row.creditsRemaining),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A4F3F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Joined: ${row.createdAt != null ? widget.dateFormat.format(row.createdAt!) : '-'}',
                  style:
                      const TextStyle(color: Color(0xFF5E6F68), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last activity: ${_formatLastActivity(row.lastActivityAt ?? row.createdAt)}',
                  style:
                      const TextStyle(color: Color(0xFF5E6F68), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _onAdjustCredits(row),
                      child: const Text('Adjust Credits'),
                    ),
                    OutlinedButton(
                      onPressed: () => _onViewLedger(row),
                      child: const Text('View Ledger'),
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

  Widget _buildLedgerInsightCard(
    int totalCreditExposure,
    List<UserLedgerRow> filteredRows,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF032E26),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Ledger Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE9D08F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current tracked exposure is ${_formatCredits(totalCreditExposure)}. '
                  'Review high-balance accounts before the next appraisal cycle.',
                  style: const TextStyle(color: Color(0xFFD2DDD8)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE9C869),
                    foregroundColor: const Color(0xFF2F2B1F),
                  ),
                  onPressed: () => _downloadFilteredCsv(filteredRows),
                  child: Text(_selectedUserIds.isEmpty
                      ? 'Download All (Filtered)'
                      : 'Download Selected (${_selectedUserIds.length})'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(int activeManufacturers) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6E3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars, color: Color(0xFF9D6A00)),
              SizedBox(width: 8),
              Text(
                'Sync Status',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$activeManufacturers verified manufacturers detected.',
            style: const TextStyle(color: Color(0xFF5E6F68)),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Cloud Connected',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8A84),
            ),
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

  bool _matchesUserFilter(UserLedgerRow row, _UserTypeFilter filter) {
    if (filter == _UserTypeFilter.all) return true;
    return _userRoleType(row) == filter;
  }

  _UserTypeFilter _userRoleType(UserLedgerRow row) {
    final role = row.role.toLowerCase();
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
                        value: selectedType,
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
    if (normalized.isEmpty)
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
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
    final titleFontSize = screenWidth < 600 ? 28.0 : 40.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F312C),
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

class _LedgerStatCard extends StatelessWidget {
  const _LedgerStatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.accentColor,
    required this.icon,
  });

  final String label;
  final String value;
  final String hint;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Color(0xFF6D7D77),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTypeBadge extends StatelessWidget {
  const _UserTypeBadge({required this.role});

  final String role;

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
    } else {
      fg = const Color(0xFF1B7A59);
      bg = const Color(0xFFE8F7F1);
      border = const Color(0xFFCAE9DD);
      label = 'Customer';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
