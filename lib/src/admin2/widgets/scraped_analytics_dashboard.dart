import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ScrapedAnalyticsDashboard extends StatefulWidget {
  const ScrapedAnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<ScrapedAnalyticsDashboard> createState() => _ScrapedAnalyticsDashboardState();
}

class _ScrapedAnalyticsDashboardState extends State<ScrapedAnalyticsDashboard> {
  final supabase = Supabase.instance.client;
  
  // Filter states
  String? selectedCategory;
  String? selectedMetalType;
  String? selectedStoneType;
  DateTimeRange? selectedDateRange;
  
  // Filter options
  List<String> categories = [];
  List<String> metalTypes = [];
  List<String> stoneTypes = [];
  
  // Counter metrics
  int totalProducts = 0;
  int totalCategories = 0;
  int totalDesigns = 0;
  int totalVariations = 0;
  
  // Category performance data
  List<Map<String, dynamic>> categoryPerformance = [];
  
  // Loading states
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFilterOptions();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _fetchAnalyticsData();
      setState(() {
        _lastUpdated = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading analytics: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAnalyticsData() async {
    // Fetch aggregated counts
    final productsData = await supabase
        .from('products')
        .select('id');
    
    final designerProductsData = await supabase
        .from('designerproducts')
        .select('id');

    // Fetch category performance - placeholder for now
    // You'll need to create get_category_performance_analytics RPC
    List<Map<String, dynamic>> categoryData = [];
    try {
      final data = await supabase.rpc('get_category_performance_analytics');
      categoryData = List<Map<String, dynamic>>.from(data ?? []);
    } catch (e) {
      debugPrint('RPC function not yet created: $e');
      // Generate mock data from existing products
      categoryData = _generateCategoryPerformance();
    }
    
    setState(() {
      totalProducts = productsData.length;
      totalDesigns = designerProductsData.length;
      totalCategories = categories.length;
      totalVariations = totalProducts + totalDesigns;
      
      categoryPerformance = categoryData;
    });
  }

  List<Map<String, dynamic>> _generateCategoryPerformance() {
    // Generate from categories list
    return categories.map((cat) => {
      'category': cat,
      'product_count': 0,
      'avg_views': 0.0,
      'avg_likes': 0.0,
      'top_tags': <String>[],
      'top_colors': <String>[],
    }).toList();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final catData = await supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Category'});
      final metalData = await supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Metal Type'});
      final stoneData = await supabase.rpc('get_distinct_unnested_values',
          params: {'column_name': 'Stone Type'});

      setState(() {
        categories = List<String>.from(catData ?? []);
        metalTypes = List<String>.from(metalData ?? []);
        stoneTypes = List<String>.from(stoneData ?? []);
        totalCategories = categories.length;
      });
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    await _loadFilterOptions();
    setState(() => _isRefreshing = false);
  }

  void _exportCsv() {
    // Export logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting analytics data...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter dropdowns
          _buildFilterBar(),
          
          const SizedBox(height: 20),
          
          // 4 Gradient counter cards
          _buildCounterCards(),
          
          const SizedBox(height: 24),
          
          // Category performance table with charts
          _buildCategoryPerformanceSection(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedCategory,
              items: [
                const DropdownMenuItem(value: null, child: Text('All Categories')),
                ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (value) => setState(() => selectedCategory = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Metal Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedMetalType,
              items: [
                const DropdownMenuItem(value: null, child: Text('All Metals')),
                ...metalTypes.map((m) => DropdownMenuItem(value: m, child: Text(m))),
              ],
              onChanged: (value) => setState(() => selectedMetalType = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stone Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedStoneType,
              items: [
                const DropdownMenuItem(value: null, child: Text('All Stones')),
                ...stoneTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (value) => setState(() => selectedStoneType = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                selectedDateRange != null
                    ? '${selectedDateRange!.start.month}/${selectedDateRange!.start.day} - ${selectedDateRange!.end.month}/${selectedDateRange!.end.day}'
                    : 'Date Range',
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (range != null) {
                  setState(() => selectedDateRange = range);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isRefreshing ? null : _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCards() {
    return Row(
      children: [
        Expanded(
          child: _GradientCounterCard(
            title: 'Total Products',
            count: totalProducts,
            icon: Icons.shopping_bag,
            gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GradientCounterCard(
            title: 'Categories',
            count: totalCategories,
            icon: Icons.category,
            gradientColors: [Colors.purple.shade400, Colors.purple.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GradientCounterCard(
            title: 'Designer Items',
            count: totalDesigns,
            icon: Icons.diamond,
            gradientColors: [Colors.orange.shade400, Colors.orange.shade600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GradientCounterCard(
            title: 'Total Variations',
            count: totalVariations,
            icon: Icons.collections,
            gradientColors: [Colors.green.shade400, Colors.green.shade600],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPerformanceSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      'Category Performance Analytics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _lastUpdated != null
                              ? 'Last updated: ${_formatTime(_lastUpdated!)}'
                              : 'Loading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Performance table
            _buildPerformanceTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTable() {
    if (categoryPerformance.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No category data available'),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Product Count', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Avg Views', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Avg Likes', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Top Tags', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Top Colors', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: categoryPerformance.map((cat) {
          final categoryName = cat['category']?.toString() ?? 'Unknown';
          final categoryColor = _getCategoryColor(categoryName);
          
          return DataRow(
            cells: [
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(Text((cat['product_count'] ?? 0).toString())),
              DataCell(
                Row(
                  children: [
                    Text((cat['avg_views'] ?? 0).toStringAsFixed(1)),
                    const SizedBox(width: 8),
                    _buildProgressBar(
                      (cat['avg_views'] ?? 0).toDouble(),
                      Colors.blue,
                      maxValue: 1000,
                    ),
                  ],
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Text((cat['avg_likes'] ?? 0).toStringAsFixed(1)),
                    const SizedBox(width: 8),
                    _buildProgressBar(
                      (cat['avg_likes'] ?? 0).toDouble(),
                      Colors.red,
                      maxValue: 100,
                    ),
                  ],
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 4,
                  children: (cat['top_tags'] as List<dynamic>?)
                      ?.take(3)
                      .map((tag) => Chip(
                            label: Text(
                              tag.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList() ?? 
                      [const Text('-')],
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 4,
                  children: (cat['top_colors'] as List<dynamic>?)
                      ?.take(3)
                      .map((color) => Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _parseColor(color.toString()),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                          ))
                      .toList() ?? 
                      [const Text('-')],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressBar(double value, Color color, {double maxValue = 100}) {
    final percentage = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    
    return SizedBox(
      width: 60,
      height: 8,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Ring': Colors.red,
      'Necklace': Colors.blue,
      'Bracelet': Colors.green,
      'Earring': Colors.purple,
      'Pendant': Colors.orange,
    };
    return colors[category] ?? Colors.grey;
  }

  Color _parseColor(String colorName) {
    final colorMap = {
      'Gold': Colors.amber,
      'Silver': Colors.grey,
      'Rose Gold': Colors.pink,
      'White': Colors.white,
      'Yellow': Colors.yellow,
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': Colors.green,
    };
    return colorMap[colorName] ?? Colors.grey.shade400;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

}

class _GradientCounterCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final List<Color> gradientColors;

  const _GradientCounterCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Background icon (decorative)
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 120,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
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
}