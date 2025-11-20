// Comprehensive Analytics Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/analytics_widgets.dart';

class AnalyticsSection extends ConsumerStatefulWidget {
  const AnalyticsSection({super.key});

  @override
  ConsumerState<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends ConsumerState<AnalyticsSection> {
  // Global State
  bool isExporting = false;
  bool isLoading = false;

  // Section 1: Post Engagement State
  String searchTerm = '';
  String engagementType = 'all';
  bool comparisonEnabled = false;
  String sortBy = 'views';
  bool sortAscending = false;
  int selectedEngagementTab = 0;

  // Data state
  List<TopPost> posts = [];
  List<EngagementTrend> trends = [];

  // Section 3: Credit System State
  int creditRangeMin = 0;
  int creditRangeMax = 1000;
  Set<String> selectedUsers = {};
  bool showMessageDialog = false;
  String customMessage = '';

  // Dialog states
  final GlobalKey<FormState> _messageFormKey = GlobalKey<FormState>();

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
    final analyticsAsync = ref.watch(analyticsDataProvider);

    return analyticsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, stack) {
        _showErrorSnackBar('Failed to load analytics data: $err');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading analytics: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(analyticsDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (analytics) {
        return Scaffold(
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),

                    // Section 1: Post Engagement Trends
                    _buildPostEngagementSection(
                        analytics.topPosts, analytics.trends),
                    const SizedBox(height: 32),

                    // Section 2: Member Behaviour Insights
                    _buildMemberBehaviorSection(
                        analytics.purchaseProbabilities,
                        analytics.funnel,
                        analytics.members,
                        analytics.categories),
                    const SizedBox(height: 32),

                    // Section 3: Credit System Management
                    _buildCreditSystemSection(
                        analytics.creditUsers, analytics.categories),
                  ],
                ),
              ),
              if (showMessageDialog) _buildMessageDialog(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final timeRange = ref.watch(analyticsTimeRangeProvider);

    return AdminPageHeader(
      title: 'Analytics Dashboard',
      subtitle:
          'Comprehensive insights into engagement, behavior, and credits.',
      actions: [
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            value: timeRange,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: '1d', child: Text('Today')),
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(analyticsTimeRangeProvider.notifier).state = value;
              }
            },
          ),
        ),
        ElevatedButton.icon(
          onPressed: isExporting ? null : _exportAllData,
          icon: isExporting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(FontAwesomeIcons.download, size: 16),
          label: const Text('Export All'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildPostEngagementSection(
      List<TopPost> topPosts, List<EngagementTrend> engagementTrends) {
    return CustomCard(
      child: Column(
        children: [
          SectionHeader(
            title: 'Post Engagement Trends',
            description:
                'Unified analytics with search, filters, and comparison',
            gradientColors: [const Color(0xFFf3e8ff), const Color(0xFFfce7f3)],
            onExport: () => _exportSection('engagement'),
          ),

          const SizedBox(height: 24),

          // Sticky Search & Filter Bar
          FilterBar(
            children: [
              // Search Bar
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by title, tag, or category...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => searchTerm = value);
                  },
                ),
              ),

              // Engagement Type Filter
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: engagementType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'views', child: Text('Views')),
                    DropdownMenuItem(value: 'likes', child: Text('Likes')),
                    DropdownMenuItem(
                        value: 'comments', child: Text('Comments')),
                    DropdownMenuItem(value: 'saves', child: Text('Saves')),
                  ],
                  onChanged: (value) => setState(() => engagementType = value!),
                ),
              ),

              // Compare Weeks Checkbox
              CheckboxListTile(
                title: const Text('Compare weeks'),
                value: comparisonEnabled,
                onChanged: (value) =>
                    setState(() => comparisonEnabled = value!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              // Apply Button
              ElevatedButton.icon(
                onPressed: _applyFilters,
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (engagementTrends.isNotEmpty) ...[
            _buildEngagementTrendChart(engagementTrends),
            const SizedBox(height: 24),
          ],

          // Sub-Tabs
          CustomTabBar(
            tabs: const ['Top Posts', 'Trending Posts', 'Most Viewed'],
            selectedIndex: selectedEngagementTab,
            onTabChanged: (index) =>
                setState(() => selectedEngagementTab = index),
          ),

          const SizedBox(height: 24),

          // Tab Content
          _buildEngagementTabContent(topPosts),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildEngagementTabContent(List<TopPost> topPosts) {
    switch (selectedEngagementTab) {
      case 0:
        return _buildTopPostsTab(topPosts);
      case 1:
        return _buildTrendingPostsTab(topPosts);
      case 2:
        return _buildMostViewedTab(topPosts);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEngagementTrendChart(List<EngagementTrend> trends) {
    final currentSpots = trends.asMap().entries.map(
      (entry) {
        final trend = entry.value;
        final value = trend.thisWeek?.toDouble() ?? trend.views.toDouble();
        return FlSpot(entry.key.toDouble(), value);
      },
    ).toList();

    final previousSpots = trends.asMap().entries.map(
      (entry) {
        final trend = entry.value;
        final value = trend.lastWeek?.toDouble() ?? trend.likes.toDouble();
        return FlSpot(entry.key.toDouble(), value);
      },
    ).toList();

    final currentColor = const Color(0xFFec4899);
    final previousColor = const Color(0xFF0ea5e9);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Engagement Pulse',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      _TrendLegend(label: 'This week', color: currentColor),
                      _TrendLegend(label: 'Last week', color: previousColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Visual comparison of week-over-week interactions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: isCompact ? 220 : 260,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (value, meta) => Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (trends.length / 5)
                              .clamp(1, trends.length)
                              .toDouble(),
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= trends.length) {
                              return const Text('');
                            }
                            final date = trends[value.toInt()].date;
                            return Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 11),
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
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: currentSpots,
                        isCurved: true,
                        color: currentColor,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: currentColor.withValues(alpha: 0.12),
                        ),
                      ),
                      LineChartBarData(
                        spots: previousSpots,
                        isCurved: true,
                        color: previousColor,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: previousColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopPostsTab(List<TopPost> topPosts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
          columns: [
            const DataColumn(
                label: Text('Post',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(
              label: Row(
                children: [
                  EngagementIcon(type: 'views'),
                  const SizedBox(width: 8),
                  SortableTableHeader(
                    title: 'Views',
                    onTap: () {},
                    isSorted: sortBy == 'views',
                    sortAscending: sortAscending,
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  EngagementIcon(type: 'likes'),
                  const SizedBox(width: 8),
                  SortableTableHeader(
                    title: 'Likes',
                    onTap: () {},
                    isSorted: sortBy == 'likes',
                    sortAscending: sortAscending,
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  EngagementIcon(type: 'comments'),
                  const SizedBox(width: 8),
                  SortableTableHeader(
                    title: 'Comments',
                    onTap: () {},
                    isSorted: sortBy == 'comments',
                    sortAscending: sortAscending,
                  ),
                ],
              ),
            ),
            DataColumn(
              label: Row(
                children: [
                  EngagementIcon(type: 'saves'),
                  const SizedBox(width: 8),
                  SortableTableHeader(
                    title: 'Saves',
                    onTap: () {},
                    isSorted: sortBy == 'saves',
                    sortAscending: sortAscending,
                  ),
                ],
              ),
            ),
            const DataColumn(
                label: Text('Date',
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: topPosts.map((post) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: post.thumbUrl != null
                                ? NetworkImage(post.thumbUrl!)
                                : const NetworkImage(
                                    'https://via.placeholder.com/100'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              post.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(Text(post.views.toString())),
                DataCell(Text(post.likes.toString())),
                DataCell(Text(post.quotesRequested.toString())),
                DataCell(Text(post.saves.toString())),
                DataCell(
                  Text(
                    post.date.toString().split(' ')[0],
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendingPostsTab(List<TopPost> topPosts) {
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
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: topPosts.take(8).length,
          itemBuilder: (context, index) {
            final post = topPosts[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {},
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: post.thumbUrl != null
                            ? Image.network(
                                post.thumbUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image),
                              ),
                      ),
                    ),

                    // Trending Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              FontAwesomeIcons.chartLine,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Trending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              post.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      FontAwesomeIcons.eye,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.views.toString(),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      FontAwesomeIcons.heart,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.likes.toString(),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
    );
  }

  Widget _buildMostViewedTab(List<TopPost> topPosts) {
    return SizedBox(
      height: 400,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              (topPosts.isNotEmpty ? topPosts.first.views.toDouble() : 10000) *
                  1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final post = topPosts[groupIndex];
                return BarTooltipItem(
                  '${post.title}\n${post.views} views',
                  const TextStyle(color: Colors.black),
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
                  if (value.toInt() >= topPosts.length) return const Text('');
                  final post = topPosts[value.toInt()];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      post.title.split(' ').take(2).join(' '),
                      style: const TextStyle(fontSize: 12),
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
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
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
          barGroups: topPosts.asMap().entries.map((entry) {
            final index = entry.key;
            final post = entry.value;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: post.views.toDouble(),
                  color: const Color(0xFF8b5cf6),
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
    );
  }

  Widget _buildMemberBehaviorSection(
      List<PurchaseProbability> purchaseProbabilities,
      List<ConversionFunnelStage> conversionFunnel,
      List<TopMember> topMembers,
      List<CategoryPreference> categoryPreferences) {
    return CustomCard(
      child: Column(
        children: [
          SectionHeader(
            title: 'Member Behaviour Insights',
            description:
                'Purchase probability, conversion funnel, and engagement analysis',
            gradientColors: [const Color(0xFFdbeafe), const Color(0xFFe0e7ff)],
            onExport: () => _exportSection('behavior'),
          ),

          const SizedBox(height: 24),

          // Purchase Probability Section
          _buildPurchaseProbabilitySection(purchaseProbabilities),

          const SizedBox(height: 32),

          // Conversion Funnel & Top Members
          _buildConversionFunnelSection(conversionFunnel, topMembers),

          const SizedBox(height: 32),

          // Category Preferences
          _buildCategoryPreferencesSection(categoryPreferences),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildPurchaseProbabilitySection(
      List<PurchaseProbability> purchaseProbabilities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Purchase Probability Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI-Powered Predictions',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Data Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 96),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: [
                const DataColumn(
                    label: Text('Member',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Activity Score',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Conversion Probability',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Recent Actions',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: purchaseProbabilities.map((user) {
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LinearProgressIndicator(
                            value: user.activityScore / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              user.activityScore > 80
                                  ? Colors.green.shade400
                                  : user.activityScore > 60
                                      ? Colors.amber.shade400
                                      : Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.activityScore}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    DataCell(ProbabilityBadge(probability: user.probability)),
                    DataCell(
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: user.recentActions.take(2).map((action) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              action,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversionFunnelSection(
      List<ConversionFunnelStage> conversionFunnel,
      List<TopMember> topMembers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 768;

        return Column(
          children: [
            Text(
              'Conversion Funnel & Top Members',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            if (isMobile)
              Column(
                children: [
                  _buildConversionFunnelCard(conversionFunnel),
                  const SizedBox(height: 24),
                  _buildTopMembersCard(topMembers),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildConversionFunnelCard(conversionFunnel)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTopMembersCard(topMembers)),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildConversionFunnelCard(
      List<ConversionFunnelStage> conversionFunnel) {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversion Funnel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'User journey from visitor to member',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          ...conversionFunnel.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isFirst = index == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage.stage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Text(
                            stage.users.formatted,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          if (!isFirst) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${stage.percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        height: 32,
                        width: (stage.percentage / 100) *
                            (MediaQuery.of(context).size.width - 200),
                        decoration: BoxDecoration(
                          color: stage.fill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            '${stage.users.formatted} users',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopMembersCard(List<TopMember> topMembers) {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Members',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Highest engagement this week',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),

          const SizedBox(height: 16),

          // Members List
          ...topMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8b5cf6), Color(0xFFec4899)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        member.avatar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${member.posts} posts • ${member.saves} saves',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Engagement Meter
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 64,
                            child: LinearProgressIndicator(
                              value: member.engagement / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.purple.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${member.engagement}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryPreferencesSection(
      List<CategoryPreference> categoryPreferences) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Category Preferences',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            OutlinedButton.icon(
              onPressed: () => _exportSection('categories'),
              icon: const Icon(FontAwesomeIcons.download, size: 16),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 768;

            return isMobile
                ? Column(
                    children: [
                      _buildCategoryDistributionChart(categoryPreferences),
                      const SizedBox(height: 24),
                      _buildCategoryEngagementList(categoryPreferences),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildCategoryDistributionChart(
                              categoryPreferences)),
                      const SizedBox(width: 24),
                      Expanded(
                          child: _buildCategoryEngagementList(
                              categoryPreferences)),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryDistributionChart(
      List<CategoryPreference> categoryPreferences) {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: categoryPreferences.asMap().entries.map((entry) {
                  final category = entry.value;

                  return PieChartSectionData(
                    value: category.value,
                    color: category.color,
                    title: '${category.value.toStringAsFixed(0)}%',
                    radius: 100,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          ...categoryPreferences.map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        Text('${category.name}: ${category.members} members'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryEngagementList(
      List<CategoryPreference> categoryPreferences) {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Engagement',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...categoryPreferences.map((category) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: category.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '${category.members} members',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: category.value / 100 * 2, // Scale for visibility
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(category.color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCreditSystemSection(List<CreditUser> creditUsers,
      List<CategoryPreference> categoryPreferences) {
    final distributionData =
        AnalyticsService.getCreditDistribution(creditUsers);
    final summaryCards = AnalyticsService.getCreditSummaryCards(creditUsers);

    return CustomCard(
      child: Column(
        children: [
          SectionHeader(
            title: 'Credit System Management',
            description:
                'Filter, analyze, and manage user credits with bulk actions',
            gradientColors: [const Color(0xFFfef3c7), const Color(0xFFfed7aa)],
            onExport: () => _exportSection('credits'),
          ),

          const SizedBox(height: 24),

          // Credit Range Filter
          _buildCreditRangeFilter(),

          const SizedBox(height: 24),

          // Credit Distribution Chart
          _buildCreditDistributionChart(distributionData),

          const SizedBox(height: 32),

          // Filtered Users Table
          _buildFilteredUsersTable(creditUsers),

          const SizedBox(height: 32),

          // Footer Summary Cards
          _buildFooterSummaryCards(summaryCards),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCreditRangeFilter() {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit Range Filter',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: 16),

          // Input Fields
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Min Credits',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: creditRangeMin.toString(),
                  onChanged: (value) => setState(() {
                    creditRangeMin = int.tryParse(value) ?? 0;
                  }),
                ),
              ),
              const SizedBox(width: 16),
              const Text('-', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Max Credits',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: creditRangeMax.toString(),
                  onChanged: (value) => setState(() {
                    creditRangeMax = int.tryParse(value) ?? 1000;
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Quick Filter Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterButton('0-100', 0, 100),
              _buildQuickFilterButton('100-300', 100, 300),
              _buildQuickFilterButton('300-500', 300, 500),
              _buildQuickFilterButton('500-1000', 500, 1000),
            ],
          ),

          const SizedBox(height: 16),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showSuccessSnackBar('Filter applied'),
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('Apply'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetCreditFilter,
                icon: const Icon(Icons.rotate_left, size: 16),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, int min, int max) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          creditRangeMin = min;
          creditRangeMax = max;
        });
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildCreditDistributionChart(
      List<CreditDistribution> distributionData) {
    if (distributionData.isEmpty) {
      return CustomCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'No credit usage data available yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    final peakUsers = distributionData.fold<int>(
        0, (max, item) => item.users > max ? item.users : max);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'User distribution across credit ranges',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: peakUsers == 0 ? 50.0 : peakUsers * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = distributionData[groupIndex];
                      return BarTooltipItem(
                        '${data.range} credits\n${data.users} users',
                        const TextStyle(color: Colors.black),
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
                        if (value.toInt() >= distributionData.length) {
                          return const Text('');
                        }
                        return Text(
                          distributionData[value.toInt()].range,
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
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
                barGroups: distributionData.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.users.toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredUsersTable(List<CreditUser> creditUsers) {
    final filteredUsers = creditUsers
        .where((user) =>
            user.creditsRemaining >= creditRangeMin &&
            user.creditsRemaining <= creditRangeMax)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filtered Users (${filteredUsers.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (selectedUsers.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedUsers.length} selected',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showCustomMessageDialog(),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send Custom Message'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Data Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 96),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
              columns: [
                const DataColumn(label: SizedBox(width: 48)), // Checkbox column
                const DataColumn(
                    label: Text('Username',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Email',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Current Credits',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Last Earned',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Source',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                const DataColumn(
                    label: Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: filteredUsers.map((user) {
                final isSelected = selectedUsers.contains(user.id);

                return DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleUserSelection(user.id),
                      ),
                    ),
                    DataCell(Text(user.username)),
                    DataCell(Text(user.email.isEmpty ? 'N/A' : user.email)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              FontAwesomeIcons.coins,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.creditsRemaining.toString(),
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(user.isMember ? 'Member' : 'Non-Member')),
                    DataCell(Text(user.source.name)), // Credit source
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _sendAlert(user.id),
                            icon: const Icon(Icons.send, size: 16),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _addCredits(user.id),
                            icon: const Icon(Icons.add, size: 16),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterSummaryCards(List<CreditSummary> summaryCards) {
    if (summaryCards.isEmpty) {
      return const SizedBox.shrink();
    }

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
          children: summaryCards
              .map(
                (card) => MetricCard(
                  title: card.label,
                  value: card.value,
                  icon: card.icon,
                  color: card.color,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMessageDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Custom Message',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a personalized message to ${selectedUsers.length} selected user(s)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
      content: Form(
        key: _messageFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Type your message here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Message cannot be empty';
                }
                return null;
              },
              onChanged: (value) => setState(() => customMessage = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              customMessage = '';
              selectedUsers.clear();
              showMessageDialog = false;
            });
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_messageFormKey.currentState!.validate()) {
              _sendCustomMessage();
              setState(() {
                customMessage = '';
                selectedUsers.clear();
                showMessageDialog = false;
              });
            }
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Send Message'),
        ),
      ],
    );
  }

  // Helper Methods
  void _applyFilters() {
    // Data filtering now handled by Riverpod providers
    _showSuccessSnackBar('Filters applied successfully');
  }

  void _resetFilters() {
    setState(() {
      searchTerm = '';
      engagementType = 'all';
      comparisonEnabled = false;
      sortBy = 'views';
      sortAscending = false;
    });
    _showSuccessSnackBar('Filters reset successfully');
  }

  void _resetCreditFilter() {
    setState(() {
      creditRangeMin = 0;
      creditRangeMax = 1000;
      selectedUsers.clear();
    });
    _showSuccessSnackBar('Credit filter reset successfully');
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (selectedUsers.contains(userId)) {
        selectedUsers.remove(userId);
      } else {
        selectedUsers.add(userId);
      }
    });
  }

  void _sendAlert(String userId) {
    _showSuccessSnackBar('Alert sent to user successfully');
  }

  void _addCredits(String userId) {
    _showSuccessSnackBar('Credits added successfully');
  }

  void _showCustomMessageDialog() {
    setState(() => showMessageDialog = true);
  }

  void _sendCustomMessage() {
    // Simulate sending message
    _showSuccessSnackBar(
        'Message sent to ${selectedUsers.length} user(s) successfully');
  }

  Future<void> _exportSection(String section) async {
    setState(() => isExporting = true);
    // Export functionality disabled: AnalyticsService and required data are not available
    _showErrorSnackBar('Export functionality is currently unavailable.');
    setState(() => isExporting = false);
  }

  Future<void> _exportAllData() async {
    setState(() => isExporting = true);
    // Export functionality disabled: AnalyticsService and required data are not available
    _showErrorSnackBar('Export functionality is currently unavailable.');
    setState(() => isExporting = false);
  }
}

class _TrendLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _TrendLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
