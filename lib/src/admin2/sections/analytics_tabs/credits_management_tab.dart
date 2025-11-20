// Credit Management Tab - Part of Analytics Dashboard
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics_service.dart';
import '../../widgets/analytics_widgets.dart';

class CreditsManagementTab extends StatefulWidget {
  final List<CreditUser> initialUsers;
  final List<CreditDistribution> initialDistribution;
  final List<CreditSummary> initialSummary;
  final Function(String) onExport;

  const CreditsManagementTab({
    super.key,
    required this.initialUsers,
    required this.initialDistribution,
    required this.initialSummary,
    required this.onExport,
  });

  @override
  State<CreditsManagementTab> createState() => _CreditsManagementTabState();
}

class _CreditsManagementTabState extends State<CreditsManagementTab>
    with TickerProviderStateMixin {
  // Data
  List<CreditUser> users = [];
  List<CreditDistribution> distribution = [];
  List<CreditSummary> summary = [];

  // State Management
  RangeValues creditRange = const RangeValues(0, 1000);
  String? selectedSource;
  Set<String> selectedUsers = {};
  bool showMessageDialog = false;
  bool showAddCreditsDialog = false;
  String customMessage = '';
  String addCreditsUserId = '';
  String addCreditsAmount = '';
  String addCreditsSource = 'admin';
  bool isLoading = false;

  // Form Keys
  final GlobalKey<FormState> _messageFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _addCreditsFormKey = GlobalKey<FormState>();

  // Animation Controller
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    users = widget.initialUsers;
    distribution = widget.initialDistribution;
    summary = widget.initialSummary;
    creditRange = const RangeValues(0, 1000);
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
    final filteredUsers = users.where((user) => 
      user.currentCredits >= creditRange.start && 
      user.currentCredits <= creditRange.end &&
      (selectedSource == null || user.source.name == selectedSource)
    ).toList();

    return Column(
      children: [
        // Export Button in Header
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onExport('credits'),
              icon: const Icon(FontAwesomeIcons.download, size: 16),
              label: const Text('Export Credit Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Credit Range Filter with Dual Slider
        _buildCreditRangeFilter(),
        
        const SizedBox(height: 32),
        
        // Credit Distribution Chart
        _buildCreditDistributionChart(),
        
        const SizedBox(height: 32),
        
        // Filtered Users Table
        _buildFilteredUsersTable(filteredUsers),
        
        const SizedBox(height: 32),
        
        // Footer Summary Cards
        _buildFooterSummaryCards(),
        
        // Custom Message Dialog
        if (showMessageDialog) _buildMessageDialog(filteredUsers.length),
        
        // Add Credits Dialog
        if (showAddCreditsDialog) _buildAddCreditsDialog(),
      ],
    );
  }

  Widget _buildCreditRangeFilter() {
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
                    colors: [Color(0xFFf59e0b), Color(0xFFd97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  FontAwesomeIcons.coins,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Credit Range Filter',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _resetCreditFilter,
                icon: const Icon(FontAwesomeIcons.rotate),
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
          
          // Dual Range Slider
          Text(
            'Credit Range',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          RangeSlider(
            values: creditRange,
            min: 0,
            max: 1000,
            divisions: 100,
            activeColor: Colors.orange,
            labels: RangeLabels(
              creditRange.start.round().toString(),
              creditRange.end.round().toString(),
            ),
            onChanged: (RangeValues values) {
              setState(() {
                creditRange = values;
              });
            },
          ),
          
          // Input Fields
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Min Credits',
                    prefixIcon: const Icon(Icons.remove),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: creditRange.start.round().toString(),
                  onChanged: (value) {
                    final newMin = double.tryParse(value) ?? 0;
                    setState(() {
                      creditRange = RangeValues(newMin, creditRange.end);
                    });
                  },
                ),
              ),
              
              const SizedBox(width: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '-',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Max Credits',
                    prefixIcon: const Icon(Icons.add),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: creditRange.end.round().toString(),
                  onChanged: (value) {
                    final newMax = double.tryParse(value) ?? 1000;
                    setState(() {
                      creditRange = RangeValues(creditRange.start, newMax);
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Source Filter Dropdown
          Text(
            'Credit Source',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            width: double.infinity,
            child: DropdownButtonFormField<String?>(
              value: selectedSource,
              decoration: InputDecoration(
                labelText: 'Filter by source',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Sources'),
                ),
                const DropdownMenuItem<String?>(
                  value: 'admin',
                  child: Text('Admin'),
                ),
                const DropdownMenuItem<String?>(
                  value: 'referral',
                  child: Text('Referral'),
                ),
                const DropdownMenuItem<String?>(
                  value: 'bonus',
                  child: Text('Bonus'),
                ),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  selectedSource = newValue;
                });
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Quick Filter Buttons
          Text(
            'Quick Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickFilterButton('0-100', 0, 100),
              _buildQuickFilterButton('100-300', 100, 300),
              _buildQuickFilterButton('300-500', 300, 500),
              _buildQuickFilterButton('500-1000', 500, 1000),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _resetCreditFilter,
                icon: const Icon(FontAwesomeIcons.rotate, size: 16),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _applyCreditFilter,
                icon: const Icon(FontAwesomeIcons.filter, size: 16),
                label: const Text('Apply Filter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildQuickFilterButton(String label, double min, double max) {
    final isActive = creditRange.start == min && creditRange.end == max;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          creditRange = RangeValues(min, max);
        });
        _applyCreditFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.orange : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCreditDistributionChart() {
    return CustomCard(
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
                  FontAwesomeIcons.chartBar,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Credit Distribution',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User distribution across credit ranges',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 250,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = distribution[groupIndex];
                      return BarTooltipItem(
                        '${data.range} credits\n${data.users} users',
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
                        if (value.toInt() >= distribution.length) return const Text('');
                        return Text(
                          distribution[value.toInt()].range,
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
                      reservedSize: 50,
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
                    dashArray: [8, 4],
                  ),
                ),
                barGroups: distribution.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data.users.toDouble(),
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
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
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildFilteredUsersTable(List<CreditUser> filteredUsers) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Filtered Users (${filteredUsers.length})',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              if (selectedUsers.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FontAwesomeIcons.users,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${selectedUsers.length} selected',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                ElevatedButton.icon(
                  onPressed: _showCustomMessageDialog,
                  icon: const Icon(FontAwesomeIcons.paperPlane, size: 16),
                  label: const Text('Send Custom Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 96,
              ),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                headingRowHeight: 60,
                dataRowHeight: 80,
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: selectedUsers.isNotEmpty && selectedUsers.length == filteredUsers.length,
                      onChanged: (value) {
                        if (value == true) {
                          setState(() {
                            selectedUsers = filteredUsers.map((user) => user.id).toSet();
                          });
                        } else {
                          setState(() {
                            selectedUsers.clear();
                          });
                        }
                      },
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Username',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Current Credits',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Last Earned',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Source',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ],
                rows: filteredUsers.map((user) {
                  final isSelected = selectedUsers.contains(user.id);
                  
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (value) => _toggleUserSelection(user.id),
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleUserSelection(user.id),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FontAwesomeIcons.coins,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.currentCredits.toString(),
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${user.lastEarned} credits',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      DataCell(_buildSourceBadge(user.source)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _sendAlert(user.id),
                              icon: const Icon(FontAwesomeIcons.bell, size: 16),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.shade100,
                                foregroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _showAddCreditsDialog(user.id),
                              icon: const Icon(FontAwesomeIcons.plus, size: 16),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade100,
                                foregroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSourceBadge(CreditSource source) {
    Color borderColor;
    Color textColor;
    Color bgColor;
    String label;
    
    switch (source) {
      case CreditSource.admin:
        borderColor = Colors.purple.shade300;
        textColor = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        label = 'Admin';
        break;
      case CreditSource.referral:
        borderColor = Colors.blue.shade300;
        textColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        label = 'Referral';
        break;
      case CreditSource.bonus:
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        label = 'Bonus';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFooterSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 768 ? 2 : 1;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 2.5,
          children: summary.map((card) {
            return _buildMetricCard(card);
          }).toList(),
        );
      },
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMetricCard(CreditSummary card) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            card.color.withOpacity(0.1),
            card.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: card.color.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: card.color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              card.icon,
              color: card.color,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: card.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: card.color.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageDialog(int userCount) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FontAwesomeIcons.paperPlane,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Send Custom Message',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Send a personalized message to $userCount selected user(s)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      content: Form(
        key: _messageFormKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
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
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Send Message'),
        ),
      ],
    );
  }

  Widget _buildAddCreditsDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FontAwesomeIcons.plus,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Credits',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      content: Form(
        key: _addCreditsFormKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Credits Amount',
                  hintText: 'Enter amount to add',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
                onChanged: (value) => setState(() => addCreditsAmount = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: addCreditsSource,
                decoration: InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'bonus',
                    child: Text('Bonus'),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    addCreditsSource = newValue!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              showAddCreditsDialog = false;
              addCreditsUserId = '';
              addCreditsAmount = '';
            });
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_addCreditsFormKey.currentState!.validate()) {
              _addCredits();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Add Credits'),
        ),
      ],
    );
  }

  // Helper Methods
  void _applyCreditFilter() async {
    setState(() => isLoading = true);
    
    // Get filtered data
    final filteredUsers = await AnalyticsService.fetchCreditUsers(
      minCredits: creditRange.start.round(),
      maxCredits: creditRange.end.round(),
    );
    
    // Apply source filter locally since fetchCreditUsers doesn't support it
    final sourceFilteredUsers = selectedSource != null
        ? filteredUsers.where((user) => user.source.name == selectedSource).toList()
        : filteredUsers;
    
    final distribution = AnalyticsService.getCreditDistribution(sourceFilteredUsers);
    final summaryCards = AnalyticsService.getCreditSummaryCards(sourceFilteredUsers);
    
    setState(() {
      users = sourceFilteredUsers;
      this.distribution = distribution;
      summary = summaryCards;
      isLoading = false;
    });
    
    _showSuccessSnackBar('Credit filter applied successfully');
  }

  void _resetCreditFilter() {
    setState(() {
      creditRange = const RangeValues(0, 1000);
      selectedSource = null;
      selectedUsers.clear();
    });
    _applyCreditFilter();
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

  void _sendAlert(String userId) async {
    // For now, just show success
    _showSuccessSnackBar('Alert sent to user successfully');
  }

  void _showAddCreditsDialog(String userId) {
    setState(() {
      addCreditsUserId = userId;
      showAddCreditsDialog = true;
    });
  }

  void _addCredits() async {
    final amount = int.parse(addCreditsAmount);
    final source = CreditSource.fromString(addCreditsSource);
    
    final success = await AnalyticsService.addCredits(addCreditsUserId, amount, source);
    
    if (success) {
      _showSuccessSnackBar('Credits added successfully');
      setState(() {
        showAddCreditsDialog = false;
        addCreditsUserId = '';
        addCreditsAmount = '';
      });
      // Refresh the data
      _applyCreditFilter();
    } else {
      _showErrorSnackBar('Failed to add credits');
    }
  }

  void _showCustomMessageDialog() {
    setState(() => showMessageDialog = true);
  }

  void _sendCustomMessage() async {
    final success = await AnalyticsService.sendBulkMessage(selectedUsers.toList(), customMessage);
    
    if (success) {
      _showSuccessSnackBar('Message sent to ${selectedUsers.length} user(s) successfully');
      setState(() {
        customMessage = '';
        selectedUsers.clear();
        showMessageDialog = false;
      });
    } else {
      _showErrorSnackBar('Failed to send message');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}