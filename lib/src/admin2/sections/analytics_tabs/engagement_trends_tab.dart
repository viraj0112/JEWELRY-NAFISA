// Engagement Trends Tab - Part of Analytics Dashboard
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../widgets/analytics_widgets.dart';

class EngagementTrendsTab extends StatefulWidget {
  final List<TopPost> initialPosts;
  final List<EngagementTrend> initialTrends;
  final Function(String) onExport;
  final Function(Map<String, dynamic>) onFilterChange;

  const EngagementTrendsTab({
    super.key,
    required this.initialPosts,
    required this.initialTrends,
    required this.onExport,
    required this.onFilterChange,
  });

  @override
  State<EngagementTrendsTab> createState() => _EngagementTrendsTabState();
}

class _EngagementTrendsTabState extends State<EngagementTrendsTab>
    with TickerProviderStateMixin {
  // State Management
  String searchTerm = '';
  String engagementType = 'all';
  bool comparisonEnabled = false;
  String sortBy = 'views';
  bool sortAscending = false;
  int selectedTab = 0;

  // Data
  List<TopPost> posts = [];
  List<EngagementTrend> trends = [];
  bool isLoading = false;

  // Animation Controller for smooth transitions
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    posts = widget.initialPosts;
    trends = widget.initialTrends;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Enhanced Filter Bar with Animations
        _buildFilterBar(),

        const SizedBox(height: 24),

        // Tab Navigation
        CustomTabBar(
          tabs: const ['Top Posts', 'Trending Posts', 'Most Viewed'],
          selectedIndex: selectedTab,
          onTabChanged: (index) {
            setState(() => selectedTab = index);
            _animationController.reset();
            _animationController.forward();
          },
        ),

        const SizedBox(height: 24),

        // Tab Content with Animation
        Expanded(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (_animationController.value * 0.2),
                child: Opacity(
                  opacity: _animationController.value,
                  child: _buildTabContent(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Engagement Over Time Chart
        _buildEngagementOverTimeChart(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return FilterBar(
      children: [
        // Enhanced Search Bar with Animation
        Expanded(
          flex: 3,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by title, tag, or category...',
              prefixIcon: const Icon(Icons.search, color: Colors.purple),
              suffixIcon: searchTerm.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _clearSearch(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => searchTerm = value);
              _applyFilters();
            },
          ),
        ),

        // Engagement Type Filter
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            value: engagementType,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'views', child: Text('Views')),
              DropdownMenuItem(value: 'likes', child: Text('Likes')),
              DropdownMenuItem(value: 'comments', child: Text('Comments')),
              DropdownMenuItem(value: 'saves', child: Text('Saves')),
            ],
            onChanged: (value) {
              setState(() => engagementType = value!);
              _applyFilters();
            },
          ),
        ),

        // Compare Weeks Toggle
        Container(
          decoration: BoxDecoration(
            color: comparisonEnabled
                ? Colors.purple.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: comparisonEnabled
                  ? Colors.purple.shade300
                  : Colors.grey.shade300,
            ),
          ),
          child: CheckboxListTile(
            title: const Text('Compare weeks'),
            value: comparisonEnabled,
            onChanged: (value) => setState(() => comparisonEnabled = value!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            activeColor: Colors.purple,
          ),
        ),

        // Apply Button
        ElevatedButton.icon(
          onPressed: _applyFilters,
          icon: const Icon(Icons.filter_list, size: 16),
          label: const Text('Apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),

        // Reset Button
        OutlinedButton.icon(
          onPressed: _resetFilters,
          icon: const Icon(Icons.rotate_left, size: 16),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildTopPostsTab();
      case 1:
        return _buildTrendingPostsTab();
      case 2:
        return _buildMostViewedTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopPostsTab() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 48,
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            headingRowHeight: 60,
            dataRowHeight: 80,
            columns: [
              const DataColumn(
                label: Text(
                  'Post',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              DataColumn(
                label: Row(
                  children: [
                    EngagementIcon(type: 'views', color: Colors.blue),
                    const SizedBox(width: 8),
                    SortableTableHeader(
                      title: 'Views',
                      onTap: () => _sortPosts('views'),
                      isSorted: sortBy == 'views',
                      sortAscending: sortAscending,
                    ),
                  ],
                ),
              ),
              DataColumn(
                label: Row(
                  children: [
                    EngagementIcon(type: 'likes', color: Colors.red),
                    const SizedBox(width: 8),
                    SortableTableHeader(
                      title: 'Likes',
                      onTap: () => _sortPosts('likes'),
                      isSorted: sortBy == 'likes',
                      sortAscending: sortAscending,
                    ),
                  ],
                ),
              ),
              DataColumn(
                label: Row(
                  children: [
                    EngagementIcon(type: 'comments', color: Colors.green),
                    const SizedBox(width: 8),
                    SortableTableHeader(
                      title: 'Comments',
                      onTap: () => _sortPosts('comments'),
                      isSorted: sortBy == 'comments',
                      sortAscending: sortAscending,
                    ),
                  ],
                ),
              ),
              DataColumn(
                label: Row(
                  children: [
                    EngagementIcon(type: 'saves', color: Colors.orange),
                    const SizedBox(width: 8),
                    SortableTableHeader(
                      title: 'Saves',
                      onTap: () => _sortPosts('saves'),
                      isSorted: sortBy == 'saves',
                      sortAscending: sortAscending,
                    ),
                  ],
                ),
              ),
              const DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
            rows: posts.map((post) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                post.thumbnail ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image,
                                        color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                child: Text(
                                  post.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  post.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    _buildMetricCell(post.views, Colors.blue.shade600),
                  ),
                  DataCell(
                    _buildMetricCell(post.likes, Colors.red.shade600),
                  ),
                  DataCell(
                    _buildMetricCell(post.comments, Colors.green.shade600),
                  ),
                  DataCell(
                    _buildMetricCell(post.saves, Colors.orange.shade600),
                  ),
                  DataCell(
                    Text(
                      _formatDate(post.date),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMetricCell(int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        value.formatted,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildTrendingPostsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.9,
          ),
          itemCount: posts.take(8).length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Stack(
                  children: [
                    // Main Image
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          post.thumbnail ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image,
                                size: 48,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Trending Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8b5cf6), Color(0xFFec4899)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              FontAwesomeIcons.fire,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Trending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              post.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem(
                                  FontAwesomeIcons.eye,
                                  post.views.formatted,
                                  Colors.grey.shade300,
                                ),
                                _buildStatItem(
                                  FontAwesomeIcons.heart,
                                  post.likes.formatted,
                                  Colors.red.shade300,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMostViewedTab() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.chartBar,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Most Viewed Posts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (posts.isNotEmpty
                          ? posts.first.views.toDouble()
                          : 10000) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final post = posts[groupIndex];
                        return BarTooltipItem(
                          '${post.title}\n${post.views.formatted} views',
                          const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= posts.length)
                            return const Text('');
                          final post = posts[value.toInt()];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              post.title.split(' ').take(2).join(' '),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 80,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [8, 4],
                    ),
                  ),
                  barGroups: posts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final post = entry.value;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: post.views.toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade400,
                              Colors.purple.shade600,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementOverTimeChart() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.lineChart,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  comparisonEnabled
                      ? 'Engagement Over Time (This Week vs Last Week)'
                      : 'Daily Engagement Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final date = trends[value.toInt()].date;
                          return Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  lineBarsData: comparisonEnabled
                      ? [
                          LineChartBarData(
                            spots: trends.asMap().entries.map((entry) {
                              final index = entry.key;
                              final trend = entry.value;
                              return FlSpot(
                                index.toDouble(),
                                trend.thisWeek?.toDouble() ?? 0,
                              );
                            }).toList(),
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple,
                                Colors.purple.withOpacity(0.5),
                              ],
                            ),
                            color: Colors.purple,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            isStrokeJoinRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.purple,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.3),
                                  Colors.purple.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: trends.asMap().entries.map((entry) {
                              final index = entry.key;
                              final trend = entry.value;
                              return FlSpot(
                                index.toDouble(),
                                trend.lastWeek?.toDouble() ?? 0,
                              );
                            }).toList(),
                            gradient: LinearGradient(
                              colors: [
                                Colors.pink,
                                Colors.pink.withOpacity(0.5),
                              ],
                            ),
                            color: Colors.pink,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            isStrokeJoinRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.pink,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.pink.withOpacity(0.3),
                                  Colors.pink.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ]
                      : [
                          LineChartBarData(
                            spots: trends.asMap().entries.map((entry) {
                              final index = entry.key;
                              final trend = entry.value;
                              return FlSpot(
                                index.toDouble(),
                                trend.views.toDouble(),
                              );
                            }).toList(),
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple,
                                Colors.purple.withOpacity(0.5),
                              ],
                            ),
                            color: Colors.purple,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            isStrokeJoinRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.purple,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withOpacity(0.3),
                                  Colors.purple.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.2, end: 0);
  }

  // Helper Methods
  void _applyFilters() {
    setState(() {
      isLoading = true;
    });

    widget.onFilterChange({
      'searchTerm': searchTerm,
      'engagementType': engagementType,
      'comparisonEnabled': comparisonEnabled,
    });

    AnalyticsService.fetchTopPosts(
      searchTerm: searchTerm,
      engagementType: engagementType,
    ).then((filteredPosts) {
      setState(() {
        posts = filteredPosts;
        isLoading = false;
      });
    });
  }

  void _resetFilters() {
    setState(() {
      searchTerm = '';
      engagementType = 'all';
      comparisonEnabled = false;
      sortBy = 'views';
      sortAscending = false;
    });
    _applyFilters();
  }

  void _clearSearch() {
    setState(() {
      searchTerm = '';
    });
    _applyFilters();
  }

  void _sortPosts(String field) {
    setState(() {
      if (sortBy == field) {
        sortAscending = !sortAscending;
      } else {
        sortBy = field;
        sortAscending = false;
      }

      posts.sort((a, b) {
        int aValue = 0;
        int bValue = 0;

        switch (field) {
          case 'views':
            aValue = a.views;
            bValue = b.views;
            break;
          case 'likes':
            aValue = a.likes;
            bValue = b.likes;
            break;
          case 'comments':
            aValue = a.comments;
            bValue = b.comments;
            break;
          case 'saves':
            aValue = a.saves;
            bValue = b.saves;
            break;
        }

        return sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
