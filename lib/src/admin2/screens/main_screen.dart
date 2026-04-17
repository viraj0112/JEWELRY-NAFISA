
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';
import '../widgets/admin_skeletons.dart';
import 'inventory_screen.dart';
import 'analytics_screen.dart';
import 'moderation_screen.dart';
import 'system_controls_screen.dart';
import 'user_management_screen.dart';
import 'quote_tracking_screen.dart';

enum _AdminView {
  dashboard('Dashboard'),
  moderation('Moderation'),
  userManagement('User Management'),
  quoteTracking('Quote Tracking'),
  analytics('Analytics'),
  inventory('Inventory'),
  settings('Settings');

  const _AdminView(this.label);
  final String label;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NewAdminDataService _dataService = NewAdminDataService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  _AdminView _activeView = _AdminView.dashboard;
  String _selectedMetalSource = 'all';
  String _selectedMetalView = 'Type';

  late Future<DashboardViewData> _dashboardFuture;
  late Future<List<ModerationItem>> _moderationFuture;
  late Future<List<UserLedgerRow>> _usersFuture;
  late Future<List<QuoteRecord>> _quotesFuture;
  late Future<List<DailyAnalyticsPoint>> _analyticsFuture;
  late Future<List<InventoryItem>> _inventoryFuture;
  late Future<List<SystemSetting>> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    if (_activeView == _AdminView.dashboard ||
        _activeView == _AdminView.moderation ||
        _activeView == _AdminView.userManagement) {
      setState(() {});
    }
  }

  void _loadAll() {
    _dashboardFuture = _dataService.fetchDashboardViewData();
    _moderationFuture = _dataService.fetchModerationQueue();
    _usersFuture = _dataService.fetchUserLedger();
    _quotesFuture = _dataService.fetchQuoteTracking();
    _analyticsFuture = _dataService.fetchAnalytics();
    _inventoryFuture = _dataService.fetchInventory();
    _settingsFuture = _dataService.fetchSystemSettings();
  }

  void _refreshCurrentView() {
    setState(() {
      switch (_activeView) {
        case _AdminView.dashboard:
          _dashboardFuture = _dataService.fetchDashboardViewData();
          break;
        case _AdminView.moderation:
          _moderationFuture = _dataService.fetchModerationQueue();
          break;
        case _AdminView.userManagement:
          _usersFuture = _dataService.fetchUserLedger();
          break;
        case _AdminView.quoteTracking:
          _quotesFuture = _dataService.fetchQuoteTracking();
          break;
        case _AdminView.analytics:
          _analyticsFuture = _dataService.fetchAnalytics();
          break;
        case _AdminView.inventory:
          _inventoryFuture = _dataService.fetchInventory();
          break;
        case _AdminView.settings:
          _settingsFuture = _dataService.fetchSystemSettings();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isMobile = screenWidth < 768;
    final horizontalPadding = isMobile ? 12.0 : 20.0;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F5F4),
      drawer: isMobile
          ? Drawer(
              child: SafeArea(
                child: _Sidebar(
                  activeView: _activeView,
                  onSelect: (view) {
                    Navigator.of(context).pop();
                    setState(() => _activeView = view);
                  },
                  isDesktop: true,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              _Sidebar(
                activeView: _activeView,
                onSelect: (view) => setState(() => _activeView = view),
                isDesktop: isDesktop,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: _activeView.label,
                    searchController: _searchController,
                    onRefresh: _refreshCurrentView,
                    showMenuButton: isMobile,
                    onMenuTap: isMobile ? () => _scaffoldKey.currentState?.openDrawer() : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: _buildActivePage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePage() {
    switch (_activeView) {
      case _AdminView.dashboard:
        return FutureBuilder<DashboardViewData>(
          future: _dashboardFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildDashboard(data),
          ),
        );
      case _AdminView.moderation:
        return FutureBuilder<List<ModerationItem>>(
          future: _moderationFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildModeration(data),
          ),
        );
      case _AdminView.userManagement:
        return FutureBuilder<List<UserLedgerRow>>(
          future: _usersFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildUsers(data),
          ),
        );
      case _AdminView.quoteTracking:
        return FutureBuilder<List<QuoteRecord>>(
          future: _quotesFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildQuotes(data),
          ),
        );
      case _AdminView.analytics:
        return FutureBuilder<List<DailyAnalyticsPoint>>(
          future: _analyticsFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildAnalytics(data),
          ),
        );
      case _AdminView.inventory:
        return FutureBuilder<List<InventoryItem>>(
          future: _inventoryFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildInventory(data),
          ),
        );
      case _AdminView.settings:
        return FutureBuilder<List<SystemSetting>>(
          future: _settingsFuture,
          builder: (context, snapshot) => _buildAsyncShell(
            snapshot: snapshot,
            builder: (data) => _buildSettings(data),
          ),
        );
    }
  }

  Widget _buildAsyncShell<T>({
    required AsyncSnapshot<T> snapshot,
    required Widget Function(T data) builder,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return AdminSkeletonView(
        variant: switch (_activeView) {
          _AdminView.dashboard => AdminSkeletonVariant.dashboard,
          _AdminView.moderation => AdminSkeletonVariant.cards,
          _AdminView.userManagement => AdminSkeletonVariant.table,
          _AdminView.quoteTracking => AdminSkeletonVariant.table,
          _AdminView.analytics => AdminSkeletonVariant.dashboard,
          _AdminView.inventory => AdminSkeletonVariant.cards,
          _AdminView.settings => AdminSkeletonVariant.list,
        },
      );
    }
    if (snapshot.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load admin data: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    final data = snapshot.data;
    if (data == null) {
      return const Text('No data found.');
    }
    return builder(data);
  }

  Widget _buildDashboard(DashboardViewData dashboard) {
    final snapshot = dashboard.snapshot;
    final query = _searchController.text.trim().toLowerCase();
    final filteredCuration = _filterCurationFeed(dashboard.curationFeed, query);
    final filteredAppraisal =
        _filterAppraisalQueue(dashboard.appraisalQueue, query);
    final cards = [
      ('Total Users', snapshot.totalUsers.toString(), Icons.people),
      ('Total Quotes', snapshot.totalQuotes.toString(), Icons.request_quote),
      ('Pending Approvals', snapshot.pendingApprovals.toString(), Icons.rule),
      ('Total Assets', snapshot.totalAssets.toString(), Icons.inventory_2),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetalAnalyticsCard(dashboard),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final actionButton = FilledButton.icon(
              onPressed: () => _exportDashboardReport(dashboard),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export Report'),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PageTitle(
                    title: 'Dagina Design Overview',
                    subtitle:
                        'Core operational snapshot powered by live database values.',
                  ),
                  const SizedBox(height: 10),
                  actionButton,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: _PageTitle(
                    title: 'Dagina Design Overview',
                    subtitle:
                        'Core operational snapshot powered by live database values.',
                  ),
                ),
                const SizedBox(width: 12),
                actionButton,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => _KpiCard(
                  title: card.$1,
                  value: card.$2,
                  icon: card.$3,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1100;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCurationFeed(filteredCuration),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _buildAppraisalQueue(filteredAppraisal),
                        const SizedBox(height: 12),
                        _buildMarketPulse(dashboard.marketPulse),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _buildCurationFeed(filteredCuration),
                const SizedBox(height: 12),
                _buildAppraisalQueue(filteredAppraisal),
                const SizedBox(height: 12),
                _buildMarketPulse(dashboard.marketPulse),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurationFeed(List<CurationFeedItem> items) {
    final previewItems = items.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Curation Feed',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: previewItems
                  .map(
                    (item) => _CurationCard(
                      item: item,
                      showNewTag: true,
                      onTap: () => _showCurationDetails(item),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showAllCurationDialog(items),
                child: const Text('View all submissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppraisalQueue(List<AppraisalQueueItem> items) {
    final previewItems = items.take(3).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appraisal Queue',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...previewItems.map(
              (item) => _AppraisalTile(
                item: item,
                dateFormat: _dateFormat,
                showNewTag: true,
                onTap: () => _showAppraisalDetails(item),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showAllAppraisalDialog(items),
                child: const Text('View all submissions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurationDetails(CurationFeedItem item) {
    _showDetailsDialog(
      title: item.title,
      imageUrl: item.imageUrl,
      fields: {
        'Table': item.sourceTable,
        'Price': item.priceLabel.isEmpty ? 'N/A' : item.priceLabel,
        'Quote Requests': '${item.quoteRequests}',
        'Created': item.createdAt == null ? '-' : _dateFormat.format(item.createdAt!),
      },
    );
  }

  void _showAppraisalDetails(AppraisalQueueItem item) {
    _showDetailsDialog(
      title: item.title,
      imageUrl: item.imageUrl,
      fields: {
        'Table': item.sourceTable,
        'Uploader': item.uploaderName,
        'Email': item.uploaderEmail.isEmpty ? 'N/A' : item.uploaderEmail,
        'Price': item.priceLabel.isEmpty ? 'N/A' : item.priceLabel,
        'Created': item.createdAt == null ? '-' : _dateFormat.format(item.createdAt!),
      },
    );
  }

  void _showDetailsDialog({
    required String title,
    required Map<String, String> fields,
    String? imageUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFFF7FAF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0A4F3F),
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          color: const Color(0xFFE9EFEC),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E6DF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Color(0xFF0A4F3F),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${entry.key}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF084638),
                                      ),
                                    ),
                                    TextSpan(
                                      text: entry.value,
                                      style: const TextStyle(
                                        color: Color(0xFF11614D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Color(0xFF0A4F3F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAllCurationDialog(List<CurationFeedItem> items) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF7FAF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'All Curation Submissions',
          style: TextStyle(
            color: Color(0xFF0A4F3F),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 900,
          height: 520,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final item = items[index];
              return ListTile(
                onTap: () {
                  Navigator.of(context).pop();
                  _showCurationDetails(item);
                },
                leading: _Thumb(imageUrl: item.imageUrl),
                title: Text(item.title),
                subtitle: Text('${item.sourceTable} • ${item.quoteRequests} quotes'),
                trailing: const Icon(Icons.chevron_right),
              );
            },
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

  void _showAllAppraisalDialog(List<AppraisalQueueItem> items) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF7FAF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'All Upload Submissions',
          style: TextStyle(
            color: Color(0xFF0A4F3F),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 900,
          height: 520,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, index) {
              final item = items[index];
              return ListTile(
                onTap: () {
                  Navigator.of(context).pop();
                  _showAppraisalDetails(item);
                },
                leading: _Thumb(imageUrl: item.imageUrl),
                title: Text(item.title),
                subtitle: Text(
                  '${item.sourceTable}\n${item.uploaderName}${item.uploaderEmail.isEmpty ? '' : ' • ${item.uploaderEmail}'}',
                ),
                trailing: Text(
                  item.createdAt == null ? '-' : _dateFormat.format(item.createdAt!),
                ),
              );
            },
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

  Widget _buildMarketPulse(MarketPulse pulse) {
    return Card(
      color: const Color(0xFF0A4F3F),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Pulse',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            _MarketPulseRow(point: pulse.gold),
            const SizedBox(height: 8),
            _MarketPulseRow(point: pulse.silver),
            const SizedBox(height: 8),
            const Text(
              'Note: prices shown are per ounce.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Source: ${pulse.source} • Updated: ${DateFormat('MMM d, hh:mm a').format(pulse.updatedAt)}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CurationFeedItem> _filterCurationFeed(
    List<CurationFeedItem> items,
    String query,
  ) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final haystack = [
        item.title,
        item.sourceTable,
        item.priceLabel,
        item.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<AppraisalQueueItem> _filterAppraisalQueue(
    List<AppraisalQueueItem> items,
    String query,
  ) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final haystack = [
        item.title,
        item.sourceTable,
        item.uploaderName,
        item.uploaderEmail,
        item.priceLabel,
        item.id,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _exportDashboardReport(DashboardViewData dashboard) async {
    final now = DateTime.now();
    final rows = <List<dynamic>>[
      ['Dashboard Report', 'Generated At', now.toIso8601String()],
      [],
      ['Summary', 'Value'],
      ['Total Users', dashboard.snapshot.totalUsers],
      ['Total Quotes', dashboard.snapshot.totalQuotes],
      ['Pending Approvals', dashboard.snapshot.pendingApprovals],
      ['Total Assets', dashboard.snapshot.totalAssets],
      [],
      ['Curation Feed'],
      ['Title', 'Table', 'Price', 'Quote Requests', 'Created'],
      ...dashboard.curationFeed.map(
        (item) => [
          item.title,
          item.sourceTable,
          item.priceLabel,
          item.quoteRequests,
          item.createdAt?.toIso8601String() ?? '',
        ],
      ),
      [],
      ['Appraisal Queue'],
      ['Title', 'Table', 'Uploader', 'Email', 'Price', 'Created'],
      ...dashboard.appraisalQueue.map(
        (item) => [
          item.title,
          item.sourceTable,
          item.uploaderName,
          item.uploaderEmail,
          item.priceLabel,
          item.createdAt?.toIso8601String() ?? '',
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final fileName =
        'dashboard_report_${now.toIso8601String().replaceAll(':', '-')}.csv';

    if (kIsWeb) {
      final uri = Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8);
      final anchor = html.AnchorElement(href: uri.toString())
        ..setAttribute('download', fileName)
        ..click();
      return;
    }

    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report copied to clipboard (CSV). Use it to save as .csv.',
          ),
        ),
      );
    }
  }

  Widget _buildModeration(List<ModerationItem> items) {
    return ModerationScreen(
      pendingItems: items,
      searchQuery: _searchController.text,
      dateFormat: _dateFormat,
      dataService: _dataService,
      onRefreshRequested: _refreshCurrentView,
    );
  }

  Widget _buildUsers(List<UserLedgerRow> rows) {
    return UserManagementScreen(
      rows: rows,
      searchQuery: _searchController.text,
      dateFormat: _dateFormat,
      onRequestRefresh: _refreshCurrentView,
    );
  }

  Widget _buildQuotes(List<QuoteRecord> rows) {
    return QuoteTrackingScreen(
      quotes: rows,
      dataService: _dataService,
      onRefreshRequested: _refreshCurrentView,
    );
  }

  Widget _buildAnalytics(List<DailyAnalyticsPoint> points) {
    return AnalyticsScreen(
      dailyPoints: points,
      dataService: _dataService,
      onRefreshRequested: _refreshCurrentView,
    );
  }

  Widget _buildInventory(List<InventoryItem> items) {
    return InventoryScreen(
      items: items,
      searchQuery: _searchController.text,
      dateFormat: _dateFormat,
      dataService: _dataService,
      onRefreshRequested: _refreshCurrentView,
    );
  }

  Widget _buildSettings(List<SystemSetting> settings) {
    return SystemControlsScreen(
      settings: settings,
      dateFormat: _dateFormat,
      dataService: _dataService,
      onRefreshRequested: _refreshCurrentView,
    );
  }

  Widget _buildResponsiveTable(DataTable table) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: table,
          ),
        );
      },
    );
  }

  Widget _buildMetalAnalyticsCard(DashboardViewData dashboard) {
    final insights = _selectedMetalView == 'Type'
        ? dashboard.metalTypeInsights
        : dashboard.metalColorInsights;

    final List<MetalInsight> filtered;
    if (_selectedMetalSource == 'all') {
      final Map<String, int> aggregated = {};
      for (final i in insights) {
        aggregated[i.label] = (aggregated[i.label] ?? 0) + i.count;
      }
      filtered = aggregated.entries
          .map((e) =>
              MetalInsight(label: e.key, count: e.value, sourceTable: 'all'))
          .toList();
    } else {
      filtered = insights
          .where((i) => i.sourceTable == _selectedMetalSource)
          .toList();
    }
    filtered.sort((a, b) => b.count.compareTo(a.count));

    final total = filtered.isEmpty
        ? 0
        : filtered.map((e) => e.count).reduce((a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metal Distribution',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B3D2F),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Product breakdown by metal $_selectedMetalView',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  // View Selection (Type vs Color)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['Type', 'Color'].map((view) {
                        final isSelected = _selectedMetalView == view;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedMetalView = view),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              view,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF1B3D2F)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Source Filter
                  SizedBox(
                    width: 160,
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      value: _selectedMetalSource,
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Sources')),
                        DropdownMenuItem(
                            value: 'products', child: Text('Main Products')),
                        DropdownMenuItem(
                            value: 'designerproducts', child: Text('Designer')),
                        DropdownMenuItem(
                            value: 'manufacturerproducts',
                            child: Text('Manufacturer')),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedMetalSource = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No data found for the selected filter.'),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual Chart (Progressive Bars)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: filtered.take(8).map((item) {
                      final percentage = total > 0 ? (item.count / total) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                Text(
                                  '${item.count} items (${(percentage * 100).toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: percentage,
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getMetalDisplayColor(item.label),
                                          _getMetalDisplayColor(item.label)
                                              .withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 48),
                // Detailed Breakdown List
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detailed Breakdown',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1B3D2F)),
                        ),
                        const SizedBox(height: 16),
                        ...filtered.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _getMetalDisplayColor(item.label),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    '${item.count}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            )),
                        if (total > 0) ...[
                          const Divider(height: 24, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '$total',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF916A2D),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getMetalDisplayColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('gold')) {
      if (l.contains('rose')) return const Color(0xFFE5B1A1);
      if (l.contains('white')) return const Color(0xFFC4C4C4);
      return const Color(0xFFD4AF37); // Classic Gold
    }
    if (l.contains('silver')) return const Color(0xFFC0C0C0);
    if (l.contains('platinum')) return const Color(0xFFE5E4E2);
    if (l.contains('yellow')) return const Color(0xFFD4AF37);
    if (l.contains('white')) return const Color(0xFFC4C4C4);
    if (l.contains('rose')) return const Color(0xFFE5B1A1);
    if (l.contains('black')) return const Color(0xFF333333);
    if (l.contains('red')) return Colors.red.shade400;
    if (l.contains('green')) return Colors.green.shade400;
    if (l.contains('blue')) return Colors.blue.shade400;
    return const Color(0xFF916A2D); // Default brand-ish bronze
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeView,
    required this.onSelect,
    required this.isDesktop,
  });

  final _AdminView activeView;
  final ValueChanged<_AdminView> onSelect;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: isDesktop ? 240 : 84,
      color: const Color(0xFF022E25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: Text(
              'Dagina Design',
              style: TextStyle(
                color: Color(0xFFEBCB85),
                fontWeight: FontWeight.w600,
                fontSize: 24,
              ),
            ),
          ),
          ..._AdminView.values.map(
            (view) => _SidebarItem(
              label: view.label,
              selected: view == activeView,
              compact: !isDesktop,
              onTap: () => onSelect(view),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3C36B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDesktop ? 'Appraise Collection' : 'Appraise',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected ? const Color(0xFF0A4F3F) : Colors.transparent,
            border: selected
                ? const Border(
                    right: BorderSide(color: Color(0xFFE3C36B), width: 3),
                  )
                : null,
          ),
          child: Text(
            compact && label.isNotEmpty ? label[0] : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? const Color(0xFFE3C36B) : Colors.white70,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.searchController,
    required this.onRefresh,
    this.showMenuButton = false,
    this.onMenuTap,
  });

  final String title;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9F8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final search = Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search records...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMenuButton) ...[
                IconButton(
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
              const Icon(Icons.notifications_none),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                actions,
                const SizedBox(height: 10),
                search,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
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

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 600
        ? (screenWidth - 48).clamp(180.0, 260.0).toDouble()
        : 260.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        width: cardWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFF8FFFC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? const Color(0xFF9CCDBA) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? const Color(0xFF0A4F3F).withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _hovered ? 20 : 8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: const Color(0xFF0A4F3F)),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF71827A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF153F34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurationCard extends StatelessWidget {
  const _CurationCard({
    required this.item,
    required this.onTap,
    this.showNewTag = false,
  });

  final CurationFeedItem item;
  final VoidCallback onTap;
  final bool showNewTag;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 600
        ? (screenWidth - 48).clamp(180.0, 300.0).toDouble()
        : 260.0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: item.imageUrl == null || item.imageUrl!.isEmpty
                      ? Container(
                          color: const Color(0xFFE9EFEC),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.diamond_outlined,
                            color: Color(0xFF6A7A73),
                          ),
                        )
                      : Container(
                          color: Colors.white,
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE9EFEC),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFF6A7A73),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              if (showNewTag)
                const Positioned(
                  left: 8,
                  top: 8,
                  child: _NewTag(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.sourceTable,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5E6F68)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.priceLabel.isEmpty ? 'Price N/A' : item.priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A4F3F),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6EF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.quoteRequests} quotes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF256745),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _AppraisalTile extends StatelessWidget {
  const _AppraisalTile({
    required this.item,
    required this.dateFormat,
    required this.onTap,
    this.showNewTag = false,
  });

  final AppraisalQueueItem item;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final bool showNewTag;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Stack(
              children: [
                _Thumb(imageUrl: item.imageUrl),
                if (showNewTag)
                  const Positioned(
                    left: -2,
                    top: -2,
                    child: _NewTag(compact: true),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    item.sourceTable,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5E6F68)),
                  ),
                  Text(
                    item.uploaderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4E5F58)),
                  ),
                  if (item.uploaderEmail.isNotEmpty)
                    Text(
                      item.uploaderEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6D7D76)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.priceLabel.isNotEmpty)
                  Text(
                    item.priceLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                Text(
                  item.createdAt == null ? '-' : dateFormat.format(item.createdAt!),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5E6F68)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Container(
                color: const Color(0xFFE9EFEC),
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined, size: 18),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE9EFEC),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
      ),
    );
  }
}

class _NewTag extends StatelessWidget {
  const _NewTag({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A4F3F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: const Color(0xFFEBCB85),
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MarketPulseRow extends StatelessWidget {
  const _MarketPulseRow({required this.point});

  final MetalPricePoint point;

  @override
  Widget build(BuildContext context) {
    final isPositive = point.changePercent >= 0;
    final isGold = point.symbol.toUpperCase() == 'XAU';
    final trendColor = isGold ? const Color(0xFFD7A93C) : const Color(0xFFC8CDD3);
    final barFill = point.changePercent == 0
        ? (isGold ? 0.72 : 0.48)
        : ((point.changePercent.abs() / 5).clamp(0, 1)).toDouble();
    final priceText = point.priceUsd <= 0
        ? 'N/A'
        : '₹${point.priceUsd.toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                point.label.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Text(
              priceText,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isPositive ? '+' : ''}${point.changePercent.toStringAsFixed(2)}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: point.priceUsd <= 0 ? 0 : barFill,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(trendColor),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final isGood = normalized == 'approved' || normalized == 'active';
    final isWarning = normalized == 'pending' || normalized == 'review';
    final Color bg = isGood
        ? const Color(0xFFDDF7E5)
        : (isWarning ? const Color(0xFFFFF3D1) : const Color(0xFFE8ECEA));
    final Color fg = isGood
        ? const Color(0xFF17603A)
        : (isWarning ? const Color(0xFF886300) : const Color(0xFF4F605A));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
