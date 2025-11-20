import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/activity_logs_models.dart';
import '../providers/activity_logs_provider.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/analytics_widgets.dart';

class ActivityLogsSection extends ConsumerStatefulWidget {
  const ActivityLogsSection({super.key});

  @override
  ConsumerState<ActivityLogsSection> createState() =>
      _ActivityLogsSectionState();
}

class _ActivityLogsSectionState extends ConsumerState<ActivityLogsSection> {
  int selectedTab = 0;
  DateTimeRange? selectedDateRange;
  bool isExporting = false;

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(activitySummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        _showErrorSnackBar('Failed to load activity summary: $err');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading activity logs: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(activitySummaryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (summary) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildSummaryCards(summary),
              const SizedBox(height: 32),
              _buildTabs(),
              const SizedBox(height: 24),
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AdminPageHeader(
      title: 'Activity Logs',
      subtitle: 'Track all admin actions, user activities, and data exports.',
      actions: [
        ElevatedButton.icon(
          onPressed: _selectDateRange,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(selectedDateRange != null
              ? '${selectedDateRange!.start.toString().split(' ')[0]} - ${selectedDateRange!.end.toString().split(' ')[0]}'
              : 'Select Date Range'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isExporting ? null : _exportLogs,
          icon: isExporting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(FontAwesomeIcons.download, size: 16),
          label: const Text('Export Logs'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(ActivitySummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 768
                ? 2
                : 1;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            MetricCard(
              title: 'Admin Actions',
              value: '${summary.adminActions}',
              subtitle: '+${summary.adminActionsToday} today',
              icon: FontAwesomeIcons.userShield,
              color: Colors.blue,
            ),
            MetricCard(
              title: 'User Activities',
              value: '${summary.userActivities}',
              subtitle: '+${summary.userActivitiesToday} today',
              icon: FontAwesomeIcons.users,
              color: Colors.green,
            ),
            MetricCard(
              title: 'Exports Generated',
              value: '${summary.exportsGenerated}',
              subtitle: '+${summary.exportsToday} today',
              icon: FontAwesomeIcons.fileExport,
              color: Colors.orange,
            ),
            MetricCard(
              title: 'System Health',
              value: '${summary.systemHealth}%',
              subtitle: 'Uptime',
              icon: FontAwesomeIcons.server,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Admin Logs', FontAwesomeIcons.userShield),
          _buildTabButton(1, 'User Activities', FontAwesomeIcons.users),
          _buildTabButton(2, 'Export Logs', FontAwesomeIcons.fileExport),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: isSelected ? Colors.blue : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildAdminLogsTab();
      case 1:
        return _buildUserActivitiesTab();
      case 2:
        return _buildExportLogsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAdminLogsTab() {
    final logsAsync = ref.watch(currentActivityLogsProvider('admin'));

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (logs) => _buildLogsTable(logs, _adminColumns, _adminRowBuilder),
    );
  }

  Widget _buildUserActivitiesTab() {
    final logsAsync = ref.watch(currentActivityLogsProvider('user'));

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (logs) => _buildLogsTable(logs, _userColumns, _userRowBuilder),
    );
  }

  Widget _buildExportLogsTab() {
    final logsAsync = ref.watch(currentActivityLogsProvider('export'));

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (logs) => _buildLogsTable(logs, _exportColumns, _exportRowBuilder),
    );
  }

  Widget _buildLogsTable(List<ActivityLog> logs, List<DataColumn> columns,
      DataRow Function(ActivityLog) rowBuilder) {
    return CustomCard(
      child: Column(
        children: [
          _buildFilters(),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 48),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                columns: columns,
                rows: logs.map(rowBuilder).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) =>
                ref.read(activityLogsSearchProvider.notifier).state = value,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Filter by category',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _getCategoryItems(),
            onChanged: (value) =>
                ref.read(activityLogsCategoryProvider.notifier).state = value,
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Clear'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getCategoryItems() {
    switch (selectedTab) {
      case 0: // Admin
        return [
          const DropdownMenuItem(value: null, child: Text('All Actions')),
          const DropdownMenuItem(
              value: 'User Access', child: Text('User Access')),
          const DropdownMenuItem(value: 'Content', child: Text('Content')),
          const DropdownMenuItem(value: 'System', child: Text('System')),
          const DropdownMenuItem(value: 'Finance', child: Text('Finance')),
        ];
      case 1: // User
        return [
          const DropdownMenuItem(value: null, child: Text('All Actions')),
          const DropdownMenuItem(value: 'Login', child: Text('Login')),
          const DropdownMenuItem(value: 'Content', child: Text('Content')),
          const DropdownMenuItem(value: 'Purchases', child: Text('Purchases')),
          const DropdownMenuItem(value: 'Profile', child: Text('Profile')),
        ];
      case 2: // Export
        return [
          const DropdownMenuItem(value: null, child: Text('All Exports')),
          const DropdownMenuItem(value: 'CSV', child: Text('CSV')),
          const DropdownMenuItem(value: 'PDF', child: Text('PDF')),
          const DropdownMenuItem(value: 'Excel', child: Text('Excel')),
          const DropdownMenuItem(value: 'JSON', child: Text('JSON')),
        ];
      default:
        return [];
    }
  }

  List<DataColumn> get _adminColumns => [
        const DataColumn(
            label: Text('Timestamp',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Admin', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Action', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Details', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('Category',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('Severity',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('IP Address',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
      ];

  List<DataColumn> get _userColumns => [
        const DataColumn(
            label: Text('Timestamp',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('User', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Action', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Details', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('Category',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('IP Address',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
      ];

  List<DataColumn> get _exportColumns => [
        const DataColumn(
            label: Text('Timestamp',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('User', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('Export Type',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Format', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Records', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label: Text('File Size',
                style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
        const DataColumn(
            label:
                Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
      ];

  DataRow _adminRowBuilder(ActivityLog log) {
    return DataRow(cells: [
      DataCell(Text(log.timestamp.toString().split('.')[0])),
      DataCell(Text(log.adminId ?? 'Unknown')),
      DataCell(Text(log.actionType ?? '')),
      DataCell(Text(log.details ?? '')),
      DataCell(_buildCategoryBadge(log.category)),
      DataCell(_buildSeverityBadge(log.severity)),
      DataCell(Text(log.ipAddress ?? '')),
      DataCell(ElevatedButton(
        onPressed: () => _viewLogDetails(log),
        child: const Text('View'),
      )),
    ]);
  }

  DataRow _userRowBuilder(ActivityLog log) {
    return DataRow(cells: [
      DataCell(Text(log.timestamp.toString().split('.')[0])),
      DataCell(Text(log.userId ?? 'Unknown')),
      DataCell(Text(log.actionType ?? '')),
      DataCell(Text(log.details ?? '')),
      DataCell(_buildCategoryBadge(log.category)),
      DataCell(Text(log.ipAddress ?? '')),
      DataCell(ElevatedButton(
        onPressed: () => _viewLogDetails(log),
        child: const Text('View'),
      )),
    ]);
  }

  DataRow _exportRowBuilder(ActivityLog log) {
    return DataRow(cells: [
      DataCell(Text(log.timestamp.toString().split('.')[0])),
      DataCell(Text(log.userId ?? 'Unknown')),
      DataCell(Text(log.exportType ?? '')),
      DataCell(_buildFormatBadge(log.format)),
      DataCell(Text(log.recordCount?.toString() ?? '')),
      DataCell(Text(log.fileSize ?? '')),
      DataCell(_buildStatusBadge(log.status)),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (log.status == 'Completed')
            ElevatedButton.icon(
              onPressed: () => _downloadExport(log),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _viewLogDetails(log),
            child: const Text('Details'),
          ),
        ],
      )),
    ]);
  }

  Widget _buildCategoryBadge(String? category) {
    Color color;
    switch (category?.toLowerCase()) {
      case 'user access':
        color = Colors.blue;
        break;
      case 'content':
        color = Colors.green;
        break;
      case 'system':
        color = Colors.purple;
        break;
      case 'finance':
        color = Colors.orange;
        break;
      case 'login':
        color = Colors.teal;
        break;
      case 'purchases':
        color = Colors.red;
        break;
      case 'profile':
        color = Colors.indigo;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category ?? 'Unknown',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSeverityBadge(String? severity) {
    Color color;
    switch (severity?.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity ?? 'Unknown',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFormatBadge(String? format) {
    Color color;
    switch (format?.toLowerCase()) {
      case 'csv':
        color = Colors.green;
        break;
      case 'pdf':
        color = Colors.red;
        break;
      case 'excel':
        color = Colors.blue;
        break;
      case 'json':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        format ?? 'Unknown',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    switch (status?.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'processing':
        color = Colors.orange;
        break;
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status ?? 'Unknown',
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedDateRange,
    );
    if (picked != null) {
      setState(() => selectedDateRange = picked);
      ref.read(activityLogsDateRangeProvider.notifier).state = {
        'start': picked.start,
        'end': picked.end,
      };
    }
  }

  void _clearFilters() {
    ref.read(activityLogsSearchProvider.notifier).state = null;
    ref.read(activityLogsCategoryProvider.notifier).state = null;
    ref.read(activityLogsDateRangeProvider.notifier).state = null;
    ref.read(activityLogsFormatProvider.notifier).state = null;
    setState(() => selectedDateRange = null);
  }

  void _viewLogDetails(ActivityLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Timestamp: ${log.timestamp}'),
              Text('Action: ${log.actionType}'),
              Text('Details: ${log.details}'),
              Text('Category: ${log.category}'),
              if (log.severity != null) Text('Severity: ${log.severity}'),
              if (log.ipAddress != null) Text('IP Address: ${log.ipAddress}'),
              if (log.userAgent != null) Text('User Agent: ${log.userAgent}'),
              if (log.exportType != null)
                Text('Export Type: ${log.exportType}'),
              if (log.format != null) Text('Format: ${log.format}'),
              if (log.recordCount != null) Text('Records: ${log.recordCount}'),
              if (log.fileSize != null) Text('File Size: ${log.fileSize}'),
              if (log.status != null) Text('Status: ${log.status}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _downloadExport(ActivityLog log) {
    _showSuccessSnackBar('Download started for ${log.exportType}');
  }

  Future<void> _exportLogs() async {
    setState(() => isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    _showSuccessSnackBar('Logs exported successfully');
    setState(() => isExporting = false);
  }
}
