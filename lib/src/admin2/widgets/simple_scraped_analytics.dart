import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Enum to track which detail view is active
enum AnalyticsDetailView { none, byProductType, byCategory }

class SimpleScrapedAnalytics extends StatefulWidget {
  const SimpleScrapedAnalytics({Key? key}) : super(key: key);

  @override
  State<SimpleScrapedAnalytics> createState() => _SimpleScrapedAnalyticsState();
}

class _SimpleScrapedAnalyticsState extends State<SimpleScrapedAnalytics> {
  final supabase = Supabase.instance.client;

  List<String> categories = [];
  List<String> metalTypes = [];

  int totalImages = 0;
  int totalPosts = 0;
  int totalCategories = 0;
  int avgPerCategory = 0;

  List<CategoryData> categoryPerformance = [];

  bool _isLoading = false;

  // State for detail views
  AnalyticsDetailView _detailView = AnalyticsDetailView.none;
  List<Map<String, dynamic>> _detailData = [];
  String _detailTitle = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final catDataFuture = supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Category'});
      final metalDataFuture = supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Metal Type'});
      final productsDataFuture =
          supabase.from('products').select('id, "Category"');
      final designerDataFuture =
          supabase.from('designerproducts').select('id, "Category"');

      // Run futures in parallel
      final results = await Future.wait([
        catDataFuture,
        metalDataFuture,
        productsDataFuture,
        designerDataFuture,
      ]);

      final catData = results[0] as List?;
      final metalData = results[1] as List?;
      final productsData = results[2] as List;
      final designerData = results[3] as List;

      final cats = List<String>.from(catData ?? []);
      final metals = List<String>.from(metalData ?? []);

      final catMap = <String, int>{};
      for (var p in [...productsData, ...designerData]) {
        final cat = p['Category']?.toString() ?? 'Uncategorized';
        catMap[cat] = (catMap[cat] ?? 0) + 1;
      }

      final catPerf = catMap.entries
          .map((e) => CategoryData(
                category: e.key,
                totalImages: (e.value * 0.65).toInt(), // Mock data logic
                totalPosts: (e.value * 0.35).toInt(), // Mock data logic
              ))
          .toList()
        ..sort((a, b) => b.totalImages.compareTo(a.totalImages));

      if (mounted) {
        setState(() {
          categories = cats;
          metalTypes = metals;
          totalImages = productsData.length;
          totalPosts = designerData.length;
          totalCategories = catMap.length;
          avgPerCategory = catMap.isNotEmpty
              ? ((productsData.length + designerData.length) / catMap.length)
                  .toInt()
              : 0;
          categoryPerformance = catPerf;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: Function to show Product Type breakdown ---
  Future<void> _showProductTypeData() async {
    setState(() {
      _isLoading = true;
      _detailTitle = 'Posts by Product Type';
    });

    try {
      final productTypesDataFuture =
          supabase.from('products').select('"Product Type"');
      final designerTypesDataFuture =
          supabase.from('designerproducts').select('"Product Type"');

      final results =
          await Future.wait([productTypesDataFuture, designerTypesDataFuture]);
      final productTypesData = results[0] as List;
      final designerTypesData = results[1] as List;

      final typeMap = <String, int>{};
      for (var p in [...productTypesData, ...designerTypesData]) {
        final type = p['Product Type']?.toString() ?? 'Uncategorized';
        typeMap[type] = (typeMap[type] ?? 0) + 1;
      }

      final detailData = typeMap.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (mounted) {
        setState(() {
          _detailData = detailData;
          _detailView = AnalyticsDetailView.byProductType;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading product type data: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- NEW: Function to show Category breakdown ---
  void _showCategoryData() {
    final detailData = categoryPerformance
        .map((cp) => {
              'name': cp.category,
              'count': cp.totalImages + cp.totalPosts,
            })
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    setState(() {
      _detailData = detailData;
      _detailTitle = 'Posts by Category';
      _detailView = AnalyticsDetailView.byCategory;
    });
  }

  // --- NEW: Function to reset view ---
  void _resetDetailView() {
    setState(() {
      _detailView = AnalyticsDetailView.none;
      _detailData = [];
      _detailTitle = '';
    });
  }

  // --- NEW: Placeholder for other cards ---
  void _showUnimplementedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This card does not have a detail view yet.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ring')) return Colors.purple;
    if (lower.contains('necklace')) return Colors.pink;
    if (lower.contains('bracelet')) return Colors.cyan;
    if (lower.contains('earring')) return Colors.orange;
    if (lower.contains('watch')) return Colors.teal;
    return Colors.grey;
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute:$second $period';
  }

  @override
  Widget build(BuildContext context) {
    // --- THEME AWARENESS FIX ---
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define theme-aware colors
    final headerTextColor = isDarkMode ? Colors.white : Colors.black87;
    final defaultTextColor = isDarkMode ? Colors.white70 : Colors.black87;
    final subtleTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final tableHeaderColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;
    final barBackgroundColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;
    // --- END FIX ---

    if (_isLoading) {
      return const Center(
          child:
              Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
    }

    // --- NEW: Conditional view ---
    if (_detailView != AnalyticsDetailView.none) {
      return _buildDetailView();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.purple, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scraped Jewellery Trends',
                            style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: headerTextColor // --- THEME FIX ---
                                )),
                        Text('Category-wise performance',
                            style: TextStyle(
                                fontSize: 12, 
                                color: subtleTextColor // --- THEME FIX ---
                                )),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                        onPressed: _loadData),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        onPressed: () {}),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Counter Cards
            Row(
              children: [
                Expanded(
                    child: _CounterCard(
                  title: 'Total Images',
                  count: totalImages,
                  icon: Icons.image,
                  // --- THEME FIX: Adjust background and icon colors ---
                  color: isDarkMode ? Colors.purple.shade900 : Colors.purple.shade50,
                  iconColor: isDarkMode ? Colors.purple.shade200 : Colors.purple,
                  onTap: _showProductTypeData,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _CounterCard(
                  title: 'Total Posts',
                  count: totalPosts,
                  icon: Icons.article,
                  color: isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50,
                  iconColor: isDarkMode ? Colors.blue.shade200 : Colors.blue,
                  onTap: _showUnimplementedMessage, 
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _CounterCard(
                  title: 'Categories',
                  count: totalCategories,
                  icon: Icons.grid_view,
                  color: isDarkMode ? Colors.green.shade900 : Colors.green.shade50,
                  iconColor: isDarkMode ? Colors.green.shade200 : Colors.green,
                  onTap: _showCategoryData,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _CounterCard(
                  title: 'Avg per Category',
                  count: avgPerCategory,
                  icon: Icons.trending_up,
                  color: isDarkMode ? Colors.orange.shade900 : Colors.orange.shade50,
                  iconColor: isDarkMode ? Colors.orange.shade200 : Colors.orange,
                  onTap: _showUnimplementedMessage,
                )),
              ],
            ),

            const SizedBox(height: 24),

            // Category Performance Table
            Card(
              // Card will adapt to theme automatically
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category Performance',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: headerTextColor // --- THEME FIX ---
                            )),
                    const SizedBox(height: 4),
                    Text(
                        'Detailed breakdown of scraped content by category',
                        style: TextStyle(
                            fontSize: 12, 
                            color: subtleTextColor // --- THEME FIX ---
                            )),
                    const SizedBox(height: 20),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(3),
                        4: FlexColumnWidth(2.5),
                        5: FlexColumnWidth(1.5),
                      },
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      children: [
                        // Header row
                        TableRow(
                          // --- THEME FIX: Use theme-aware color ---
                          decoration: BoxDecoration(color: tableHeaderColor),
                          children: [
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Category',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Total Images',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Total Posts',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Trending Tags',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Top Colors',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                            Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Last Updated',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: headerTextColor // --- THEME FIX ---
                                        ))),
                          ],
                        ),
                        // Data rows
                        ...categoryPerformance.take(5).map((cat) => TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                  cat.category),
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                          child: Text(cat.category,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: defaultTextColor // --- THEME FIX ---
                                                  ))),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.image,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(cat.totalImages.toString(),
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: defaultTextColor // --- THEME FIX ---
                                              )),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.article,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(cat.totalPosts.toString(),
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: defaultTextColor // --- THEME FIX ---
                                              )),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      'Diamond',
                                      'Engagement',
                                      'Vintage'
                                    ]
                                        .map((tag) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  // --- THEME FIX: Use theme-aware color ---
                                                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text(tag,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: defaultTextColor // --- THEME FIX ---
                                                      )),
                                            ))
                                        .toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      'White',
                                      'Yellow Gold',
                                      'Rose Gold'
                                    ]
                                        .map((color) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  // --- THEME FIX: Use theme-aware color ---
                                                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text(color,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: defaultTextColor // --- THEME FIX ---
                                                      )),
                                            ))
                                        .toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 12,
                                          color: Colors.green.shade600),
                                      const SizedBox(width: 4),
                                      Flexible(
                                          child: Text(
                                              _formatTime(cat.lastUpdated),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  // --- THEME FIX: Use lighter green in dark mode ---
                                                  color: isDarkMode ? Colors.green.shade300 : Colors.green.shade600
                                                  ))),
                                    ],
                                  ),
                                ),
                              ],
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Trending Chart
            if (categoryPerformance.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What\'s Trending by Category',
                          style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: headerTextColor // --- THEME FIX ---
                              )),
                      const SizedBox(height: 4),
                      Text(
                          'Popularity score based on engagement and upload frequency',
                          style: TextStyle(
                              fontSize: 12, 
                              color: subtleTextColor // --- THEME FIX ---
                              )),
                      const SizedBox(height: 24),
                      ...categoryPerformance.take(5).map((cat) {
                        final maxValue = categoryPerformance
                            .map((c) => c.totalImages + c.totalPosts)
                            .reduce((a, b) => a > b ? a : b);
                        final value = cat.totalImages + cat.totalPosts;
                        final percentage =
                            maxValue > 0 ? value / maxValue : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 100,
                                  child: Text(cat.category,
                                      style: TextStyle(
                                          fontSize: 13, 
                                          color: defaultTextColor // --- THEME FIX ---
                                          ))),
                              Expanded(
                                child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                      // --- THEME FIX: Use theme-aware color ---
                                      color: barBackgroundColor, 
                                      borderRadius: BorderRadius.circular(14)),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage,
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color:
                                              _getCategoryColor(cat.category),
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                  width: 50,
                                  child: Text(value.toString(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: headerTextColor // --- THEME FIX ---
                                          ),
                                      textAlign: TextAlign.right)),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Detail view widget ---
  Widget _buildDetailView() {
    // --- THEME AWARENESS FIX ---
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final headerTextColor = isDarkMode ? Colors.white : Colors.black87;
    final defaultTextColor = isDarkMode ? Colors.white70 : Colors.black87;
    // --- END FIX ---
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _resetDetailView,
              ),
              const SizedBox(width: 8),
              Text(
                _detailTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: headerTextColor // --- THEME FIX ---
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: DataTable(
              columns: [
                DataColumn(
                    label: Text('Item Name',
                        style: TextStyle(fontWeight: FontWeight.bold, color: headerTextColor) // --- THEME FIX ---
                        )),
                DataColumn(
                    label: Text('Post Count',
                        style: TextStyle(fontWeight: FontWeight.bold, color: headerTextColor) // --- THEME FIX ---
                        ),
                    numeric: true),
              ],
              rows: _detailData.map((data) {
                return DataRow(
                  cells: [
                    DataCell(Text(data['name'].toString(), style: TextStyle(color: defaultTextColor) // --- THEME FIX ---
                    )),
                    DataCell(Text(data['count'].toString(), style: TextStyle(color: defaultTextColor) // --- THEME FIX ---
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryData {
  final String category;
  final int totalImages;
  final int totalPosts;
  final DateTime lastUpdated;

  CategoryData({
    required this.category,
    required this.totalImages,
    required this.totalPosts,
  }) : lastUpdated = DateTime.now();
}

class _CounterCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _CounterCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // --- THEME FIX: Check brightness here to set text color ---
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Determine text/icon colors based on the *passed* background color's brightness
    // This is more robust than checking the theme
    final bool isDarkBackground = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;

    final Color textColor = isDarkBackground ? Colors.white : Colors.grey.shade800;
    final Color subTextColor = isDarkBackground ? Colors.white70 : Colors.grey.shade600;
    final Color iconBgColor = isDarkBackground ? Colors.black.withOpacity(0.2) : Colors.white;
    // --- END FIX ---

    return MouseRegion(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color: color, // This is passed in (e.g., purple.shade50 or purple.shade900)
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: iconBgColor, // Use dynamic iconBgColor
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 20), // iconColor is passed in
                ),
                const Spacer(),
                Text(count.toString(),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textColor // Use dynamic textColor
                        )),
                const SizedBox(height: 4),
                Text(title,
                    style:
                        TextStyle(
                          fontSize: 12, 
                          color: subTextColor // Use dynamic subTextColor
                          )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}