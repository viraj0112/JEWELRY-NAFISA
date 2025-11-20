// Behavior Insights Tab - Part of Analytics Dashboard
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../widgets/analytics_widgets.dart';

class BehaviorInsightsTab extends StatefulWidget {
  final List<PurchaseProbability> initialProbabilities;
  final List<ConversionFunnelStage> initialFunnel;
  final List<TopMember> initialMembers;
  final List<CategoryPreference> initialCategories;
  final Function(String) onExport;

  const BehaviorInsightsTab({
    super.key,
    required this.initialProbabilities,
    required this.initialFunnel,
    required this.initialMembers,
    required this.initialCategories,
    required this.onExport,
  });

  @override
  State<BehaviorInsightsTab> createState() => _BehaviorInsightsTabState();
}

class _BehaviorInsightsTabState extends State<BehaviorInsightsTab>
    with TickerProviderStateMixin {
  // Data
  List<PurchaseProbability> probabilities = [];
  List<ConversionFunnelStage> funnel = [];
  List<TopMember> members = [];
  List<CategoryPreference> categories = [];

  // State Management
  int selectedPeriodTab = 0; // 0: Week, 1: Month, 2: Year
  bool isLoading = false;

  // Animation Controller
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    probabilities = widget.initialProbabilities;
    funnel = widget.initialFunnel;
    members = widget.initialMembers;
    categories = widget.initialCategories;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
        // AI-Powered Purchase Probability Section
        _buildPurchaseProbabilitySection(),
        
        const SizedBox(height: 32),
        
        // Conversion Funnel & Top Members Section
        _buildConversionFunnelSection(),
        
        const SizedBox(height: 32),
        
        // Category Preferences Section
        _buildCategoryPreferencesSection(),
      ],
    );
  }

  Widget _buildPurchaseProbabilitySection() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  FontAwesomeIcons.brain,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Probability Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FontAwesomeIcons.robot,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI-Powered Predictions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => widget.onExport('behavior'),
                icon: const Icon(FontAwesomeIcons.download),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Data Table with Enhanced Styling
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 96,
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    Colors.grey.shade50,
                  ),
                  headingRowHeight: 60,
                  dataRowHeight: 80,
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Member',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Activity Score',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Conversion Probability',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Recent Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  rows: probabilities.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 150,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
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
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${user.activityScore}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: user.activityScore > 80
                                        ? Colors.green.shade700
                                        : user.activityScore > 60
                                            ? Colors.amber.shade700
                                            : Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          ProbabilityBadge(probability: user.probability),
                        ),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: user.recentActions.take(2).map((action) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    action,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildConversionFunnelSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 768;
        
        return isMobile
            ? Column(
                children: [
                  _buildConversionFunnelCard(),
                  const SizedBox(height: 24),
                  _buildTopMembersCard(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildConversionFunnelCard()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTopMembersCard()),
                ],
              );
      },
    );
  }

  Widget _buildConversionFunnelCard() {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FontAwesomeIcons.filter,
                  color: Colors.purple.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Conversion Funnel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'User journey from visitor to member',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 24),
          
          ...funnel.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isFirst = index == 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage.stage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            stage.users.formatted,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (!isFirst) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${stage.percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Stack(
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 1000 + (index * 200)),
                        height: 40,
                        width: (stage.percentage / 100) *
                            (MediaQuery.of(context).size.width - 200),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              stage.fill,
                              stage.fill.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: stage.fill.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${stage.users.formatted} users',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
    ).animate().fadeIn(duration: 700.ms).slideX(begin: -0.2, end: 0);
  }

  Widget _buildTopMembersCard() {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FontAwesomeIcons.trophy,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top Members',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Highest engagement this week',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Time Period Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['Week', 'Month', 'Year'].asMap().entries.map((entry) {
                final index = entry.key;
                final period = entry.value;
                final isActive = index == selectedPeriodTab;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedPeriodTab = index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        period,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Members List
          ...members.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          index == 0
                              ? Colors.amber.shade400
                              : index == 1
                                  ? Colors.grey.shade400
                                  : Colors.orange.shade400,
                          index == 0
                              ? Colors.amber.shade600
                              : index == 1
                                  ? Colors.grey.shade600
                                  : Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8b5cf6), Color(0xFFec4899)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        member.avatar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${member.posts} posts • ${member.saves} saves',
                          style: TextStyle(
                            fontSize: 14,
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
                            width: 80,
                            child: LinearProgressIndicator(
                              value: member.engagement / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.purple.shade400,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${member.engagement}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.purple.shade600,
                          fontWeight: FontWeight.w700,
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
    ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildCategoryPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10b981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                FontAwesomeIcons.chartPie,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Category Preferences',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => widget.onExport('categories'),
              icon: const Icon(FontAwesomeIcons.download),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 768;
            
            return isMobile
                ? Column(
                    children: [
                      _buildCategoryDistributionChart(),
                      const SizedBox(height: 24),
                      _buildCategoryEngagementList(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCategoryDistributionChart()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildCategoryEngagementList()),
                    ],
                  );
          },
        ),
      ],
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCategoryDistributionChart() {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.chartPie,
                color: Colors.green.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Category Distribution',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sections: categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  
                  return PieChartSectionData(
                    value: category.value,
                    color: category.color,
                    title: '${category.value.toStringAsFixed(0)}%',
                    radius: 100,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    titlePositionPercentageOffset: 0.5,
                  );
                }).toList(),
                sectionsSpace: 3,
                centerSpaceRadius: 50,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Legend
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${category.name}: ${category.members} members',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryEngagementList() {
    return CustomCard(
      backgroundColor: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.chartBar,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Category Engagement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          ...categories.map((category) {
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: category.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${category.members} members',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  LinearProgressIndicator(
                    value: category.value / 100 * 2, // Scale for visibility
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(category.color),
                    minHeight: 12,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}