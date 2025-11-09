import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; 

double _calculateScore(
    Map<String, dynamic> post, Map<String, double> weights) {
  return (post['like_count'] ?? 0) * weights['likes']! +
      (post['view_count'] ?? 0) * weights['views']! +
      (post['share_count'] ?? 0) * weights['shares']!;
}

// --- PERFORMANCE FIX: Top-level function to run in a background isolate ---
Map<String, dynamic> _computeMetrics(Map<String, dynamic> params) {
  // This code runs in the background and does NOT block the UI
  final List<Map<String, dynamic>> postData = params['postData'];
  final Map<String, double> weights = params['weights'];

  if (postData.isEmpty) {
    return {
      'totalLikes': 0,
      'totalViews': 0,
      'totalShares': 0,
      'bestCategory': 'N/A',
      'avgEngagement': 0.0,
    };
  }

  int totalLikes = postData.fold(
      0, (sum, post) => sum + (post['like_count'] as int? ?? 0));
  int totalViews = postData.fold(
      0, (sum, post) => sum + (post['view_count'] as int? ?? 0));
  int totalShares = postData.fold(
      0, (sum, post) => sum + (post['share_count'] as int? ?? 0));

  // Calculate best category
  final categoryScores = <String, double>{};
  for (var post in postData) {
    final category = post['category']?.toString() ?? 'Unknown';
    final score = _calculateScore(post, weights); // Use top-level function
    categoryScores[category] = (categoryScores[category] ?? 0) + score;
  }

  String bestCategory = 'N/A';
  if (categoryScores.isNotEmpty) {
    bestCategory =
        categoryScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double avgEngagement =
      postData.isNotEmpty ? totalLikes / postData.length : 0;

  // Return a map with all the results
  return {
    'totalLikes': totalLikes,
    'totalViews': totalViews,
    'totalShares': totalShares,
    'bestCategory': bestCategory,
    'avgEngagement': avgEngagement,
  };
}
// --- END PERFORMANCE FIX ---

class UnifiedEngagementAnalytics extends StatefulWidget {
  final List<Map<String, dynamic>> postData;

  const UnifiedEngagementAnalytics({
    Key? key,
    required this.postData,
  }) : super(key: key);

  @override
  State<UnifiedEngagementAnalytics> createState() =>
      _UnifiedEngagementAnalyticsState();
}

class _UnifiedEngagementAnalyticsState extends State<UnifiedEngagementAnalytics>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // Filter states
  String? selectedCategory;
  String? selectedMaterial;
  String? selectedStoneType;
  String? selectedPriceRange;
  String? selectedEngagementType;
  int? minThreshold;
  String searchQuery = '';

  // View state
  bool showChartView = false; // false = bar chart, true = pie chart
  Set<String> selectedPosts = {};
  String sortColumn = 'total_score';
  bool sortAscending = false;

  // Metric weights for scoring
  Map<String, double> metricWeights = {
    'likes': 1.0,
    'views': 0.5,
    'shares': 2.0,
    'details': 1.5,
    'quotes': 3.0,
  };

  // Filter options
  List<String> categories = [];
  List<String> materials = [];
  List<String> stoneTypes = [];

  // Aggregated metrics
  int totalLikes = 0;
  int totalViews = 0;
  int totalShares = 0;
  int totalQuotes = 0;
  String bestCategory = '';
  double avgEngagement = 0;

  // AI Insights
  String aiInsight = '';

  // Animation controller
  late AnimationController _animationController;

  bool _isLoadingMetrics = true; // <-- ADD THIS

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _calculateMetrics(); // <-- This is now async
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- PERFORMANCE FIX: Run calculations in background ---
  Future<void> _calculateMetrics() async {
    setState(() => _isLoadingMetrics = true);

    // Run the heavy calculation in a background isolate
    final Map<String, dynamic> metrics = await compute(_computeMetrics, {
      'postData': widget.postData,
      'weights': metricWeights,
    });

    // Update state with results from the background isolate
    if (mounted) {
      setState(() {
        totalLikes = metrics['totalLikes'];
        totalViews = metrics['totalViews'];
        totalShares = metrics['totalShares'];
        bestCategory = metrics['bestCategory'];
        avgEngagement = metrics['avgEngagement'];
        _isLoadingMetrics = false;
      });
      _generateAIInsights(); // Now generate insights with the new data
    }
  }
  // --- END PERFORMANCE FIX ---

  void _generateAIInsights() {
    if (widget.postData.isEmpty) {
      aiInsight = 'No data available for analysis';
      return;
    }

    // This data is now pre-calculated from the compute function
    if (avgEngagement > 100 && totalLikes < 10) {
      aiInsight =
          'ЁЯУК High views but low engagement. Consider improving CTAs or content quality.';
    } else if (totalShares > totalLikes * 0.5) {
      aiInsight =
          'ЁЯЪА Strong sharing behavior! Content is highly viral. Capitalize on this trend.';
    } else if (bestCategory.isNotEmpty && bestCategory != 'N/A') {
      aiInsight =
          'тнР "$bestCategory" is your top-performing category. Focus marketing efforts here.';
    } else {
      aiInsight = 'ЁЯТб Engagement is steady. Monitor trends for optimization opportunities.';
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final catData = await supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Category'});
      final matData = await supabase.rpc('get_distinct_product_values',
          params: {'column_name': 'Metal Type'});
      final stoneData = await supabase.rpc('get_distinct_unnested_values',
          params: {'column_name': 'Stone Type'});

      if (mounted) {
        setState(() {
          categories = List<String>.from(catData ?? []);
          materials = List<String>.from(matData ?? []);
          stoneTypes = List<String>.from(stoneData ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    // This still runs on build, but the *heavy* score calculation
    // is now done, so this is just filtering, which is faster.
    return widget.postData.where((post) {
      // Apply filters
      if (selectedCategory != null && post['category'] != selectedCategory)
        return false;
      if (selectedMaterial != null && post['metal_type'] != selectedMaterial)
        return false;
      if (searchQuery.isNotEmpty &&
          !(post['title']
                  ?.toString()
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) ??
              false)) {
        return false;
      }
      if (minThreshold != null) {
        // Use the top-level score function
        final score = _calculateScore(post, metricWeights);
        if (score < minThreshold!) return false;
      }
      return true;
    }).toList();
  }

  void _showWeightConfigModal() {
    showDialog(
      context: context,
      builder: (context) => _WeightConfigModal(
        weights: metricWeights,
        onSave: (newWeights) {
          setState(() {
            metricWeights = newWeights;
          });
          _calculateMetrics(); // Re-run background calculation
        },
      ),
    );
  }

  void _showAlertSetupModal() {
    showDialog(
      context: context,
      builder: (context) => const _AlertSetupModal(),
    );
  }

  void _exportData(String format) {
    // Implementation would go here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting as $format...')),
    );
  }

  void _bulkAction(String action) {
    if (selectedPosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No posts selected')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action on ${selectedPosts.length} posts')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredData = _filteredData;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _animationController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animationController.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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
            // Sticky filter bar
            _buildFilterBar(theme),

            const SizedBox(height: 20),

            // 6 Metric Cards
            if (_isLoadingMetrics)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else
              _buildMetricCards(theme),

            const SizedBox(height: 20),

            // AI Insights
            if (!_isLoadingMetrics) _buildAIInsights(theme),

            const SizedBox(height: 20),

            // Action bar with controls
            _buildActionBar(theme),

            const SizedBox(height: 16),

            // Chart or Table view
            if (_isLoadingMetrics)
              const SizedBox(
                height: 200,
                child: Center(child: Text("Loading data...")),
              )
            else
              showChartView
                  ? _buildChartView(theme, filteredData)
                  : _buildDataTable(theme, filteredData),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedCategory,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (value) => setState(() => selectedCategory = value),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Material',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedMaterial,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...materials
                    .map((m) => DropdownMenuItem(value: m, child: Text(m))),
              ],
              onChanged: (value) => setState(() => selectedMaterial = value),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Stone Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              value: selectedStoneType,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...stoneTypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (value) => setState(() => selectedStoneType = value),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Min Score',
                prefixIcon: Icon(Icons.filter_alt),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) =>
                  setState(() => minThreshold = int.tryParse(value)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure Weights',
            onPressed: _showWeightConfigModal,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Setup Alerts',
            onPressed: _showAlertSetupModal,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
            child: _MetricCard(
          title: 'Total Likes',
          value: totalLikes.toString(),
          icon: Icons.favorite,
          color: Colors.red,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _MetricCard(
          title: 'Total Views',
          value: totalViews.toString(),
          icon: Icons.visibility,
          color: Colors.blue,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _MetricCard(
          title: 'Total Shares',
          value: totalShares.toString(),
          icon: Icons.share,
          color: Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _MetricCard(
          title: 'Quotes',
          value: totalQuotes.toString(),
          icon: Icons.request_quote,
          color: Colors.orange,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _MetricCard(
          title: 'Best Category',
          value: bestCategory.isNotEmpty ? bestCategory : 'N/A',
          icon: Icons.star,
          color: Colors.purple,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _MetricCard(
          title: 'Avg Engagement',
          value: avgEngagement.toStringAsFixed(1),
          icon: Icons.trending_up,
          color: Colors.teal,
        )),
      ],
    );
  }

  Widget _buildAIInsights(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb, color: Colors.purple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-Powered Insights',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(aiInsight, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    return Row(
      children: [
        // Bulk actions
        if (selectedPosts.isNotEmpty) ...[
          ElevatedButton.icon(
            onPressed: () => _bulkAction('Delete'),
            icon: const Icon(Icons.delete),
            label: Text('Delete (${selectedPosts.length})'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _bulkAction('Hide'),
            icon: const Icon(Icons.visibility_off),
            label: Text('Hide (${selectedPosts.length})'),
          ),
          const SizedBox(width: 8),
        ],

        // View toggle
        IconButton(
          icon: Icon(showChartView ? Icons.table_chart : Icons.pie_chart),
          tooltip: showChartView ? 'Show Table' : 'Show Charts',
          onPressed: () => setState(() => showChartView = !showChartView),
        ),

        const Spacer(),

        // Export options
        PopupMenuButton<String>(
          icon: const Icon(Icons.download),
          tooltip: 'Export',
          onSelected: _exportData,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
            const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            const PopupMenuItem(value: 'email', child: Text('Email Report')),
          ],
        ),

        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _calculateMetrics, // Re-run background calculation
        ),
      ],
    );
  }

  Widget _buildChartView(ThemeData theme, List<Map<String, dynamic>> data) {
    final categoryData = <String, int>{};
    for (var post in data) {
      final category = post['category']?.toString() ?? 'Unknown';
      categoryData[category] = (categoryData[category] ?? 0) + 1;
    }

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category Distribution', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: categoryData.entries.map((entry) {
                final percentage =
                    data.isNotEmpty ? (entry.value / data.length * 100) : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(entry.key, style: theme.textTheme.bodySmall),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentage / 100,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.purple.shade400
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(entry.value.toString(),
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(ThemeData theme, List<Map<String, dynamic>> data) {
    // Sort data
    final sortedData = List<Map<String, dynamic>>.from(data);
    sortedData.sort((a, b) {
      dynamic aVal, bVal;
      switch (sortColumn) {
        case 'title':
          aVal = a['title'] ?? '';
          bVal = b['title'] ?? '';
          break;
        case 'category':
          aVal = a['category'] ?? '';
          bVal = b['category'] ?? '';
          break;
        case 'likes':
          aVal = a['like_count'] ?? 0;
          bVal = b['like_count'] ?? 0;
          break;
        case 'views':
          aVal = a['view_count'] ?? 0;
          bVal = b['view_count'] ?? 0;
          break;
        case 'shares':
          aVal = a['share_count'] ?? 0;
          bVal = b['share_count'] ?? 0;
          break;
        default: // total_score
          // --- PERFORMANCE FIX: Use top-level function ---
          aVal = _calculateScore(a, metricWeights);
          bVal = _calculateScore(b, metricWeights);
        // --- END PERFORMANCE FIX ---
      }
      return sortAscending
          ? Comparable.compare(aVal, bVal)
          : Comparable.compare(bVal, aVal);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: [
          'title',
          'category',
          'likes',
          'views',
          'shares',
          'total_score'
        ].indexOf(sortColumn),
        sortAscending: sortAscending,
        showCheckboxColumn: true,
        columns: [
          DataColumn(
            label: const Text('Title'),
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'title';
                sortAscending = ascending;
              });
            },
          ),
          DataColumn(
            label: const Text('Category'),
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'category';
                sortAscending = ascending;
              });
            },
          ),
          DataColumn(
            label: const Text('Likes'),
            numeric: true,
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'likes';
                sortAscending = ascending;
              });
            },
          ),
          DataColumn(
            label: const Text('Views'),
            numeric: true,
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'views';
                sortAscending = ascending;
              });
            },
          ),
          DataColumn(
            label: const Text('Shares'),
            numeric: true,
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'shares';
                sortAscending = ascending;
              });
            },
          ),
          DataColumn(
            label: const Text('Score'),
            numeric: true,
            onSort: (columnIndex, ascending) {
              setState(() {
                sortColumn = 'total_score';
                sortAscending = ascending;
              });
            },
          ),
        ],
        rows: sortedData.map((post) {
          final postId = post['id'].toString();
          final isSelected = selectedPosts.contains(postId);

          return DataRow(
            selected: isSelected,
            onSelectChanged: (selected) {
              setState(() {
                if (selected == true) {
                  selectedPosts.add(postId);
                } else {
                  selectedPosts.remove(postId);
                }
              });
            },
            cells: [
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    post['title']?.toString() ?? 'No Title',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(post['category']?.toString() ?? 'N/A')),
              DataCell(Text((post['like_count'] ?? 0).toString())),
              DataCell(Text((post['view_count'] ?? 0).toString())),
              DataCell(Text((post['share_count'] ?? 0).toString())),
              DataCell(Text(
                  _calculateScore(post, metricWeights).toStringAsFixed(1))),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightConfigModal extends StatefulWidget {
  final Map<String, double> weights;
  final Function(Map<String, double>) onSave;

  const _WeightConfigModal({
    required this.weights,
    required this.onSave,
  });

  @override
  State<_WeightConfigModal> createState() => _WeightConfigModalState();
}

class _WeightConfigModalState extends State<_WeightConfigModal> {
  late Map<String, double> _tempWeights;

  @override
  void initState() {
    super.initState();
    _tempWeights = Map.from(widget.weights);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Metric Weights'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _tempWeights.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(entry.key.toUpperCase()),
                  ),
                  Expanded(
                    child: Slider(
                      value: entry.value,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: entry.value.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _tempWeights[entry.key] = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(entry.value.toStringAsFixed(1)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_tempWeights);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AlertSetupModal extends StatelessWidget {
  const _AlertSetupModal();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setup Engagement Alerts'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Alert Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Threshold Value',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Metric to Monitor',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'likes', child: Text('Likes')),
                DropdownMenuItem(value: 'views', child: Text('Views')),
                DropdownMenuItem(value: 'shares', child: Text('Shares')),
                DropdownMenuItem(value: 'score', child: Text('Total Score')),
              ],
              onChanged: (value) {},
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert created successfully')),
              );
            },
            child: const Text('Create Alert')),
      ],
    );
  }
}