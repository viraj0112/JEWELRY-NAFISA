import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, compute; // <-- MODIFIED
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
// Conditional imports for web (when kIsWeb is true)
import 'dart:html' as html show AnchorElement, Blob, Url;
import 'dart:io' if (dart.library.html) 'dart:html' show File;
// Import dashboard widgets
import '../widgets/credit_usage_dashboard.dart';
import '../widgets/unified_engagement_analytics.dart';
import '../widgets/simple_scraped_analytics.dart';

enum ExportFormat { csv, xlsx }

enum ContentTab { posts, boards, credits, analytics }

// --- PERFORMANCE FIX: Top-level function for Excel generation ---
// This will be run in a background isolate using compute()
Future<List<int>?> _generateExcelInBackground(Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> products = params['products'];
  final List<Map<String, List<Map<String, dynamic>>>> allEngagementData =
      params['engagementData'];

  var excel = Excel.createExcel();

  // Create Products sheet
  Sheet productsSheet = excel['Products'];
  if (products.isNotEmpty) {
    List<String> headers = products.first.keys.toList();
    productsSheet.appendRow(headers);
    for (var product in products) {
      productsSheet.appendRow(product.values.toList());
    }
  }

  // Create engagement sheets
  Sheet likesSheet = excel['Likes'];
  Sheet sharesSheet = excel['Shares'];
  Sheet viewsSheet = excel['Views'];

  // Add headers for engagement sheets
  likesSheet.appendRow([
    'Product ID',
    'Product Title',
    'User ID',
    'Username',
    'Email',
    'Full Name',
    'Liked At',
  ]);

  sharesSheet.appendRow([
    'Product ID',
    'Product Title',
    'User ID',
    'Username',
    'Email',
    'Full Name',
    'Platform',
    'Shared At',
  ]);

  viewsSheet.appendRow([
    'Product ID',
    'Product Title',
    'User ID',
    'Username',
    'Email',
    'Full Name',
    'Country',
    'Viewed At',
  ]);

  // Loop through products and their corresponding prefetched engagement data
  for (int i = 0; i < products.length; i++) {
    final product = products[i];
    final engagement = allEngagementData[i];
    final itemId = product['id'].toString();

    // Add likes
    for (var like in engagement['likes']!) {
      final user = like['users'] as Map<String, dynamic>?;
      likesSheet.appendRow([
        itemId,
        product['title']?.toString() ?? '',
        like['user_id']?.toString() ?? '',
        user?['username']?.toString() ?? 'Unknown',
        user?['email']?.toString() ?? '',
        user?['full_name']?.toString() ?? '',
        like['created_at']?.toString() ?? '',
      ]);
    }

    // Add shares
    for (var share in engagement['shares']!) {
      final user = share['users'] as Map<String, dynamic>?;
      sharesSheet.appendRow([
        itemId,
        product['title']?.toString() ?? '',
        share['user_id']?.toString() ?? '',
        user?['username']?.toString() ?? 'Unknown',
        user?['email']?.toString() ?? '',
        user?['full_name']?.toString() ?? '',
        share['share_platform']?.toString() ?? '',
        share['created_at']?.toString() ?? '',
      ]);
    }

    // Add views
    for (var view in engagement['views']!) {
      final user = view['users'] as Map<String, dynamic>?;
      viewsSheet.appendRow([
        itemId,
        product['title']?.toString() ?? '',
        view['user_id']?.toString() ?? '',
        user?['username']?.toString() ?? 'Unknown',
        user?['email']?.toString() ?? '',
        user?['full_name']?.toString() ?? '',
        view['country']?.toString() ?? '',
        view['created_at']?.toString() ?? '',
      ]);
    }
  }

  excel.delete('Sheet1'); // Remove default sheet
  return excel.save();
}
// --- END PERFORMANCE FIX ---

class ContentSection extends StatefulWidget {
  const ContentSection({Key? key}) : super(key: key);

  @override
  State<ContentSection> createState() => _ContentSectionState();
}

class _ContentSectionState extends State<ContentSection> {
  final supabase = Supabase.instance.client;

  ContentTab _selectedTab = ContentTab.posts;

  List<Map<String, dynamic>> _postData = [];
  List<Map<String, dynamic>> _boardData = [];
  List<Map<String, dynamic>> _creditUsageData = [];
  Map<String, dynamic>? _creditStatsData;

  bool loadingFilters = true;
  String? filtersError;

  List<String> categories = [];
  List<String> materials = [];

  String? selectedCategory;
  String? selectedMaterial;
  String searchQuery = "";
  bool showAnalytics = false;

  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchFilters();
    // _fetchFilterOptions();
    _loadDataForTab(_selectedTab);
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      dynamic data;
      String rpcName = 'get_scraped_posts_with_metrics';

      final catFilter =
          (selectedCategory == 'All Categories' ? null : selectedCategory);
      final matFilter =
          (selectedMaterial == 'All Materials' ? null : selectedMaterial);
      final searchFilter = (searchQuery.isEmpty ? null : searchQuery);

      if (catFilter != null || matFilter != null || searchFilter != null) {
        rpcName = 'get_filtered_scraped_posts';
        data = await supabase.rpc(rpcName, params: {
          'category_filter': catFilter,
          'material_filter': matFilter,
          'search_text': searchFilter,
        });
      } else {
        data = await supabase.rpc(rpcName);
      }

      if (mounted) {
        setState(() {
          _postData = (data as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error fetching data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchFilterOptions() async {
    try {
      final results = await Future.wait([
        supabase.rpc('get_distinct_categories'),
        supabase.rpc('get_distinct_materials'),
      ]);

      final cats = results[0] as List;
      final mats = results[1] as List;

      setState(() {
        categories = ['All Categories', ...cats.map((e) => e.toString())];
        materials = ['All Materials', ...mats.map((e) => e.toString())];
        loadingFilters = false;
      });
    } catch (e) {
      setState(() {
        filtersError = "Error loading filters: $e";
        loadingFilters = false;
      });
    }
  }

  Future<void> _loadDataForTab(ContentTab tab) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedTab = tab;
    });

    try {
      switch (tab) {
        case ContentTab.posts:
          await _fetchScrapedPosts();
          break;
        case ContentTab.boards:
          await _fetchPopularBoards();
          break;
        case ContentTab.credits:
          await _fetchCreditUsage();
          break;
        case ContentTab.analytics:
          setState(() => _isLoading = false);
          break;
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchScrapedPosts() async {
    final data = await supabase.rpc(
      'get_filtered_scraped_posts',
      params: {
        'search_text': searchQuery.isNotEmpty ? searchQuery : null,
        'category_filter': selectedCategory,
        'material_filter': selectedMaterial,
      },
    );
    _postData = List<Map<String, dynamic>>.from(data);
  }

  Future<void> _fetchPopularBoards() async {
    final data = await supabase.rpc('get_popular_boards');
    _boardData = List<Map<String, dynamic>>.from(data);
  }

  Future<void> _fetchCreditUsage() async {
    final statsFuture = supabase.rpc('get_credit_usage_stats').single();
    final dailyUnlocksFuture = supabase.rpc('get_daily_unlocks');

    final results =
        await Future.wait<dynamic>([statsFuture, dailyUnlocksFuture]);

    _creditStatsData = results[0] as Map<String, dynamic>;
    _creditUsageData = List<Map<String, dynamic>>.from(results[1]);
  }

  // Web-compatible file download
  void _downloadFile(List<int> bytes, String fileName, String mimeType) {
    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // For mobile/desktop - would need platform-specific implementation
      debugPrint('File download on non-web platforms not yet implemented');
    }
  }

  // Fetch detailed engagement data for a product
  Future<Map<String, List<Map<String, dynamic>>>> _fetchEngagementData(
      String itemId, String itemTable) async {
    try {
      // Fetch likes with user details
      final likesDataFuture = supabase
          .from('likes')
          .select('id, created_at, user_id, users(username, email, full_name)')
          .eq('item_id', itemId)
          .eq('item_table', itemTable);

      // Fetch shares with user details
      final sharesDataFuture = supabase
          .from('shares')
          .select(
              'id, created_at, user_id, share_platform, users(username, email, full_name)')
          .eq('item_id', itemId)
          .eq('item_table', itemTable);

      // Fetch views with user details and country
      final viewsDataFuture = supabase
          .from('views')
          .select(
              'id, created_at, user_id, country, users(username, email, full_name)')
          .eq('item_id', itemId)
          .eq('item_table', itemTable);

      // --- PERFORMANCE FIX: Run fetches in parallel ---
      final results = await Future.wait([
        likesDataFuture,
        sharesDataFuture,
        viewsDataFuture,
      ]);

      return {
        'likes': List<Map<String, dynamic>>.from(results[0] ?? []),
        'shares': List<Map<String, dynamic>>.from(results[1] ?? []),
        'views': List<Map<String, dynamic>>.from(results[2] ?? []),
      };
      // --- END PERFORMANCE FIX ---
    } catch (e) {
      debugPrint('Error fetching engagement data: $e');
      return {'likes': [], 'shares': [], 'views': []};
    }
  }

  List<Map<String, dynamic>> _getActiveData() {
    switch (_selectedTab) {
      case ContentTab.posts:
        return _postData;
      case ContentTab.boards:
        return _boardData;
      case ContentTab.credits:
        return _creditUsageData; // Or _creditStatsData in a list
      default:
        return [];
    }
  }

  // Export products with detailed engagement data
  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);

    try {
      final activeData = _getActiveData();
      if (activeData.isEmpty) {
        _showMessage('No data to export');
        return;
      }

      // Show export options dialog
      final exportType = await _showExportOptionsDialog();
      if (exportType == null) return;

      if (exportType == 'all') {
        // Export with all engagement data (separate CSV files)
        await _exportAllEngagementDataCsv(activeData);
      } else {
        // Export only product data
        await _exportSimpleCsv(activeData);
      }
    } catch (e) {
      _showMessage('Error exporting: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportSimpleCsv(List<Map<String, dynamic>> data) async {
    List<String> headers = data.first.keys.toList();
    List<List<dynamic>> csvData = [headers];
    for (var map in data) {
      csvData.add(map.values.toList());
    }
    String csvString = const ListToCsvConverter().convert(csvData);
    final bytes = utf8.encode(csvString);
    _downloadFile(bytes, '${_selectedTab.name}_export.csv', 'text/csv');
    _showMessage('CSV exported successfully');
  }

  Future<void> _exportAllEngagementDataCsv(
      List<Map<String, dynamic>> products) async {
    // --- PERFORMANCE FIX: Fetch all data in parallel first ---
    _showMessage('Fetching engagement data for ${products.length} products...');
    List<Future<Map<String, List<Map<String, dynamic>>>>> futures = [];
    for (var product in products) {
      final itemId = product['id'].toString();
      final itemTable = 'products'; // You may need to track this
      futures.add(_fetchEngagementData(itemId, itemTable));
    }

    final allEngagementData = await Future.wait(futures);
    _showMessage('Data fetched. Generating CSV files...');
    // --- END PERFORMANCE FIX ---

    int processed = 0;
    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final engagement = allEngagementData[i]; // Get prefetched data
      final itemId = product['id'].toString();

      // Export likes
      if (engagement['likes']!.isNotEmpty) {
        final likesData =
            _formatEngagementForCsv(engagement['likes']!, product, 'like');
        final csvString = const ListToCsvConverter().convert(likesData);
        final bytes = utf8.encode(csvString);
        _downloadFile(bytes, '${itemId}_likes.csv', 'text/csv');
      }

      // Export shares
      if (engagement['shares']!.isNotEmpty) {
        final sharesData =
            _formatEngagementForCsv(engagement['shares']!, product, 'share');
        final csvString = const ListToCsvConverter().convert(sharesData);
        final bytes = utf8.encode(csvString);
        _downloadFile(bytes, '${itemId}_shares.csv', 'text/csv');
      }

      // Export views
      if (engagement['views']!.isNotEmpty) {
        final viewsData =
            _formatEngagementForCsv(engagement['views']!, product, 'view');
        final csvString = const ListToCsvConverter().convert(viewsData);
        final bytes = utf8.encode(csvString);
        _downloadFile(bytes, '${itemId}_views.csv', 'text/csv');
      }

      processed++;
      if (processed % 10 == 0) {
        _showMessage('Generated files for $processed/${products.length} products');
      }
    }

    _showMessage('All engagement data exported successfully');
  }

  List<List<dynamic>> _formatEngagementForCsv(
      List<Map<String, dynamic>> engagementData,
      Map<String, dynamic> product,
      String type) {
    List<List<dynamic>> csvData = [
      [
        'Product ID',
        'Product Title',
        'User ID',
        'Username',
        'Email',
        'Full Name',
        'Action Type',
        'Created At',
        if (type == 'share') 'Platform',
        if (type == 'view') 'Country',
      ]
    ];

    for (var item in engagementData) {
      final user = item['users'] as Map<String, dynamic>?;
      csvData.add([
        product['id'],
        product['title'] ?? '',
        item['user_id'] ?? '',
        user?['username'] ?? 'Unknown',
        user?['email'] ?? '',
        user?['full_name'] ?? '',
        type,
        item['created_at'] ?? '',
        if (type == 'share') item['share_platform'] ?? '',
        if (type == 'view') item['country'] ?? '',
      ]);
    }

    return csvData;
  }

  // Export to Excel with multiple sheets for engagement data
  Future<void> _exportToXlsx() async {
    setState(() => _isExporting = true);

    try {
      final activeData = _getActiveData();
      if (activeData.isEmpty) {
        _showMessage('No data to export');
        return;
      }

      // Show export options dialog
      final exportType = await _showExportOptionsDialog();
      if (exportType == null) return;

      if (exportType == 'all') {
        await _exportMultiSheetExcel(activeData);
      } else {
        await _exportSimpleExcel(activeData);
      }
    } catch (e) {
      _showMessage('Error exporting: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportSimpleExcel(List<Map<String, dynamic>> data) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Products'];

    List<String> headers = data.first.keys.toList();
    sheet.appendRow(headers);

    for (var map in data) {
      sheet.appendRow(map.values.toList());
    }

    excel.delete('Sheet1'); // Remove default sheet
    List<int>? fileBytes = excel.save();

    if (fileBytes != null) {
      _downloadFile(
          fileBytes,
          '${_selectedTab.name}_export.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      _showMessage('Excel exported successfully');
    }
  }

  Future<void> _exportMultiSheetExcel(List<Map<String, dynamic>> products) async {
    // --- PERFORMANCE FIX 1: Fetch all data in parallel ---
    _showMessage('Fetching engagement data for ${products.length} products...');
    List<Future<Map<String, List<Map<String, dynamic>>>>> futures = [];
    for (var product in products) {
      final itemId = product['id'].toString();
      final itemTable = 'products';
      futures.add(_fetchEngagementData(itemId, itemTable));
    }
    final allEngagementData = await Future.wait(futures);
    _showMessage('Data fetched. Generating Excel file in background...');
    // --- END PERFORMANCE FIX 1 ---

    // --- PERFORMANCE FIX 2: Generate Excel file in a background isolate ---
    final List<int>? fileBytes =
        await compute(_generateExcelInBackground, {
      'products': products,
      'engagementData': allEngagementData,
    });
    // --- END PERFORMANCE FIX 2 ---

    if (fileBytes != null) {
      _downloadFile(
          fileBytes,
          '${_selectedTab.name}_detailed_export.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      _showMessage(
          'Multi-sheet Excel exported with ${products.length} products');
    } else {
      _showMessage('Error generating Excel file');
    }
  }

  // Show dialog to choose export type
  Future<String?> _showExportOptionsDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose what to export:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Product Data Only'),
              subtitle: const Text('Export basic product information'),
              onTap: () => Navigator.pop(context, 'simple'),
            ),
            ListTile(
              title: const Text('Detailed Export'),
              subtitle: const Text(
                  'Include likes, shares, and views with user details'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchFilters() async {
    setState(() {
      loadingFilters = true;
      filtersError = null;
    });

    try {
      final categoryRespFuture = supabase.rpc(
        'get_distinct_product_values',
        params: {'column_name': 'Category'},
      );

      final materialRespFuture = supabase.rpc(
        'get_distinct_product_values',
        params: {'column_name': 'Metal Type'},
      );

      // Run both queries in parallel
      final results =
          await Future.wait([categoryRespFuture, materialRespFuture]);

      final categoryResp = results[0] as List;
      final materialResp = results[1] as List;
      // --- END FIX ---

      final catSet = <String>{};
      final matSet = <String>{};

      // --- FIX: Update loop to parse the RPC response (a list of strings) ---
      if (categoryResp is List) {
        for (final row in categoryResp) {
          // The 'row' is now the string value itself, not a map
          final val = row?.toString().trim();
          if (val != null && val.isNotEmpty) catSet.add(val);
        }
      }

      // --- FIX: Update loop to parse the RPC response (a list of strings) ---
      if (materialResp is List) {
        for (final row in materialResp) {
          // The 'row' is now the string value itself, not a map
          final val = row?.toString().trim();
          if (val != null && val.isNotEmpty) matSet.add(val);
        }
      }
      // --- END FIX ---

      setState(() {
        categories = catSet.toList()..sort();
        materials = matSet.toList()..sort();
      });
    } catch (e, st) {
      debugPrint('Error fetching filters: $e\n$st');
      setState(() {
        filtersError = 'Failed to load filters. Try again later.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingFilters = false;
        });
      }
    }
  }

  void _applyFilters() {
    debugPrint('Applying filters: search="$searchQuery", '
        'category="$selectedCategory", material="$selectedMaterial"');

    _loadDataForTab(_selectedTab);
  }

  void _openMoreFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MoreFiltersSheet(
        onApply: (extraFilters) {
          debugPrint('More filters applied: $extraFilters');
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Management',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      "Manage jewellery posts, boards, contents and monitor credit usage patterns.",
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  ],
                ),
              ),
              _isExporting
                  ? ElevatedButton.icon(
                      onPressed: null,
                      label: const Text("Exporting..."),
                      icon: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.6),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : PopupMenuButton<ExportFormat>(
                      tooltip: "Export Data",
                      onSelected: (ExportFormat format) {
                        switch (format) {
                          case ExportFormat.csv:
                            _exportToCsv();
                            break;
                          case ExportFormat.xlsx:
                            _exportToXlsx();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<ExportFormat>>[
                        const PopupMenuItem<ExportFormat>(
                          value: ExportFormat.csv,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.table_chart),
                            title: Text('Export as CSV'),
                            subtitle: Text('Separate files per data type'),
                          ),
                        ),
                        const PopupMenuItem<ExportFormat>(
                          value: ExportFormat.xlsx,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.grid_on),
                            title: Text('Export as Excel'),
                            subtitle: Text('Multi-sheet workbook'),
                          ),
                        ),
                      ],
                      child: ElevatedButton.icon(
                        onPressed: null, // Controlled by PopupMenuButton
                        label: const Text("Export Data"),
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        foregroundColor: MaterialStateProperty.all<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tabChip(context, 'Scraped Jewelry Posts', ContentTab.posts),
                _tabChip(context, 'Popular Boards', ContentTab.boards),
                _tabChip(context, 'Credit Usage', ContentTab.credits),
                _tabChip(context, 'Scraped Analytics', ContentTab.analytics),
              ],
            ),
          ),

          // Main filter bar - Only show for Posts tab
          if (_selectedTab == ContentTab.posts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Row 1: Search + Dropdowns + Buttons
                    Row(
                      children: [
                        // Search field
                        Expanded(
                          flex: 3,
                          child: TextField(
                            onChanged: (s) => setState(() => searchQuery = s),
                            decoration: InputDecoration(
                              hintText: 'Search jewelry posts...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Category dropdown (loading / error states handled)
                        Expanded(
                          flex: 2,
                          child: loadingFilters
                              ? _loadingBox()
                              : filtersError != null
                                  ? _errorBox(filtersError!)
                                  : _dropdown(
                                      label: 'Category',
                                      value: selectedCategory,
                                      items: categories,
                                      onChanged: (v) =>
                                          setState(() => selectedCategory = v),
                                    ),
                        ),

                        const SizedBox(width: 12),

                        // Material dropdown
                        Expanded(
                          flex: 2,
                          child: loadingFilters
                              ? _loadingBox()
                              : filtersError != null
                                  ? const SizedBox.shrink()
                                  : _dropdown(
                                      label: 'Material',
                                      value: selectedMaterial,
                                      items: materials,
                                      onChanged: (v) =>
                                          setState(() => selectedMaterial = v),
                                    ),
                        ),

                        const SizedBox(width: 12),

                        // More Filters
                        OutlinedButton.icon(
                          onPressed: _openMoreFilters,
                          icon: const Icon(Icons.filter_list),
                          label: const Text('More Filters'),
                        ),

                        const SizedBox(width: 12),

                        // Show Analytics Toggle button
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => showAnalytics = !showAnalytics),
                          icon: const Icon(Icons.show_chart_outlined),
                          label: Text(showAnalytics
                              ? 'Hide Analytics'
                              : 'Show Analytics'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: showAnalytics
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // View toggles (icons only)
                        _viewToggle(true, Icons.grid_view),
                        const SizedBox(width: 6),
                        _viewToggle(false, Icons.list),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 2: Apply / Reset buttons
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _applyFilters,
                          child: const Text('Apply Filters'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedCategory = null;
                              selectedMaterial = null;
                              searchQuery = '';
                            });
                          },
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        // Quick info about selected filters
                        Text(
                          _activeFiltersText(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Animated Unified Engagement Analytics section
          if (_selectedTab == ContentTab.posts)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: UnifiedEngagementAnalytics(postData: _postData),
              ),
              crossFadeState: showAnalytics
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),

          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          'Error loading data: $_error',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      )
                    : _buildDataList(),
          ),
        ],
      ),
    );
  }

  String _activeFiltersText() {
    final parts = <String>[];
    if (selectedCategory != null) parts.add('Category: $selectedCategory');
    if (selectedMaterial != null) parts.add('Material: $selectedMaterial');
    if (searchQuery.isNotEmpty)
      parts.add(
          'Search: "${searchQuery.length > 20 ? searchQuery.substring(0, 20) + '…' : searchQuery}"');
    if (parts.isEmpty) return 'No filters applied';
    return parts.join(' • ');
  }

  Widget _chip(BuildContext context, String label, {bool selected = false}) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceVariant,
    );
  }

  Widget _loadingBox() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildDataList() {
    switch (_selectedTab) {
      case ContentTab.posts:
        return _buildPostsList();
      case ContentTab.boards:
        return _buildBoardsList();
      case ContentTab.credits:
        return _buildCreditsUI();
      case ContentTab.analytics:
        return const SimpleScrapedAnalytics();
      default:
        return Center(
            child: Text('Data for "${_selectedTab.name}" goes here.'));
    }
  }

  Widget _buildPostsList() {
    if (_postData.isEmpty) {
      return Center(child: Text('No posts found.'));
    }
    return ListView.builder(
      itemCount: _postData.length,
      itemBuilder: (context, index) {
        final post = _postData[index];
        // Build your list tile here
        return ListTile(
          leading: post['image'] != null
              ? Image.network(post['image'],
                  width: 50, height: 50, fit: BoxFit.cover)
              : Container(width: 50, height: 50, color: Colors.grey.shade300),
          title: Text(post['title'] ?? 'No Title'),
          subtitle: Text(
              'Category: ${post['category']} • Metal: ${post['metal_type']}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Likes: ${post['like_count']}'),
              Text('Shares: ${post['share_count']}'),
              Text('Views: ${post['view_count']}'),
            ],
          ),
        );
      },
    );
  }

  // NEW: Example for boards list
  Widget _buildBoardsList() {
    if (_boardData.isEmpty) {
      return Center(child: Text('No boards found.'));
    }
    return ListView.builder(
      itemCount: _boardData.length,
      itemBuilder: (context, index) {
        final board = _boardData[index];
        return ListTile(
          title: Text(board['board_name'] ?? 'Untitled Board'),
          subtitle: Text('By: ${board['user_name'] ?? 'Unknown User'}'),
          trailing: Text('${board['pin_count']} Pins'),
        );
      },
    );
  }

  // Enhanced Credits UI with dashboard widget
  Widget _buildCreditsUI() {
    return const CreditUsageDashboard();
  }

  // UPDATED: Replace your old _chip widget with this one
  Widget _tabChip(BuildContext context, String label, ContentTab tab) {
    final theme = Theme.of(context);
    final bool selected = (_selectedTab == tab);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (isSelected) {
        if (isSelected) {
          _loadDataForTab(tab); // Load data when chip is selected
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceVariant,
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(label),
          value: value,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All'),
            ),
            ...items.map((e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ))
          ],
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }

  Widget _viewToggle(bool selected, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: selected ? Colors.white : Colors.black,
        size: 18,
      ),
    );
  }

  Widget _analyticsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📊 Analytics Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
              'Summary metrics, charts or other analytics widgets appear here.'),
          const SizedBox(height: 12),
          // Replace these with real charts or values
          Row(
            children: const [],
          ),
        ],
      ),
    );
  }
}

/// A small bottom sheet used for "More Filters". Modify to include
/// price range, tags, date pickers etc.
class MoreFiltersSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> extraFilters)? onApply;

  const MoreFiltersSheet({Key? key, this.onApply}) : super(key: key);

  @override
  State<MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<MoreFiltersSheet> {
  RangeValues priceRange = const RangeValues(1000, 10000);
  bool onlyInStock = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            runSpacing: 12,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('More Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Price Range'),
              RangeSlider(
                values: priceRange,
                labels: RangeLabels(priceRange.start.round().toString(),
                    priceRange.end.round().toString()),
                min: 0,
                max: 50000,
                divisions: 100,
                onChanged: (v) => setState(() => priceRange = v),
              ),
              CheckboxListTile(
                value: onlyInStock,
                onChanged: (v) => setState(() => onlyInStock = v ?? false),
                title: const Text('Only show in-stock items'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onApply?.call({
                        'minPrice': priceRange.start,
                        'maxPrice': priceRange.end,
                        'onlyInStock': onlyInStock,
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
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

/// A compact stat box used inside analytics
class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  const _MiniStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}