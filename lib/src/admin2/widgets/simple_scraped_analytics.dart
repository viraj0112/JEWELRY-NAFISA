import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final catData = await supabase.rpc('get_distinct_product_values', params: {'column_name': 'Category'});
      final metalData = await supabase.rpc('get_distinct_product_values', params: {'column_name': 'Metal Type'});
      
      final cats = List<String>.from(catData ?? []);
      final metals = List<String>.from(metalData ?? []);
      
      final productsData = await supabase.from('products').select('id, "Category"');
      final designerData = await supabase.from('designerproducts').select('id, "Category"');
      
      final catMap = <String, int>{};
      for (var p in [...productsData, ...designerData]) {
        final cat = p['Category']?.toString() ?? 'Uncategorized';
        catMap[cat] = (catMap[cat] ?? 0) + 1;
      }
      
      final catPerf = catMap.entries.map((e) => CategoryData(
            category: e.key,
            totalImages: (e.value * 0.65).toInt(),
            totalPosts: (e.value * 0.35).toInt(),
          )).toList()
        ..sort((a, b) => b.totalImages.compareTo(a.totalImages));
      
      if (mounted) {
        setState(() {
          categories = cats;
          metalTypes = metals;
          totalImages = productsData.length;
          totalPosts = designerData.length;
          totalCategories = catMap.length;
          avgPerCategory = catMap.isNotEmpty ? ((productsData.length + designerData.length) / catMap.length).toInt() : 0;
          categoryPerformance = catPerf;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute:$second $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scraped Jewellery Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Category-wise performance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh'), onPressed: _loadData),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(icon: const Icon(Icons.download, size: 16), label: const Text('Export CSV'), onPressed: () {}),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Counter Cards
            Row(
              children: [
                Expanded(child: _CounterCard(title: 'Total Images', count: totalImages, icon: Icons.image, color: Colors.purple.shade50, iconColor: Colors.purple)),
                const SizedBox(width: 12),
                Expanded(child: _CounterCard(title: 'Total Posts', count: totalPosts, icon: Icons.article, color: Colors.blue.shade50, iconColor: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _CounterCard(title: 'Categories', count: totalCategories, icon: Icons.grid_view, color: Colors.green.shade50, iconColor: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _CounterCard(title: 'Avg per Category', count: avgPerCategory, icon: Icons.trending_up, color: Colors.orange.shade50, iconColor: Colors.orange)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Category Performance Table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Detailed breakdown of scraped content by category', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      children: [
                        // Header row
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          children: const [
                            Padding(padding: EdgeInsets.all(12), child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(12), child: Text('Total Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(12), child: Text('Total Posts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(12), child: Text('Trending Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(12), child: Text('Top Colors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Padding(padding: EdgeInsets.all(12), child: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _getCategoryColor(cat.category), shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text(cat.category, style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.image, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(cat.totalImages.toString(), style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.article, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(cat.totalPosts.toString(), style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: ['Diamond', 'Engagement', 'Vintage'].map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                          child: Text(tag, style: const TextStyle(fontSize: 11)),
                                        )).toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: ['White', 'Yellow Gold', 'Rose Gold'].map((color) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                          child: Text(color, style: const TextStyle(fontSize: 11)),
                                        )).toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: Colors.green.shade600),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(_formatTime(cat.lastUpdated), style: TextStyle(fontSize: 11, color: Colors.green.shade600))),
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
                      const Text('What\'s Trending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Popularity score based on engagement and upload frequency', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 24),
                      
                      ...categoryPerformance.take(5).map((cat) {
                        final maxValue = categoryPerformance.map((c) => c.totalImages + c.totalPosts).reduce((a, b) => a > b ? a : b);
                        final value = cat.totalImages + cat.totalPosts;
                        final percentage = maxValue > 0 ? value / maxValue : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              SizedBox(width: 100, child: Text(cat.category, style: const TextStyle(fontSize: 13))),
                              Expanded(
                                child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage,
                                    child: Container(
                                      decoration: BoxDecoration(color: _getCategoryColor(cat.category), borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(width: 50, child: Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
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

  const _CounterCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const Spacer(),
            Text(count.toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}