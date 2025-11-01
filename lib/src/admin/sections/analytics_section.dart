import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
// FIX: Import the detailed user growth chart
import 'package:jewelry_nafisa/src/admin/widgets/user_growth_chart.dart';
// FIX: Import the dashboard widgets (like DailyUsageCard)
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart';
// FIX: Import Provider and Notifier
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';

// FIX: Convert to StatefulWidget to use the TabController
class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: We consume the filter state here
    return Consumer<FilterStateNotifier>(
      builder: (context, filterNotifier, child) {
        final filterState = filterNotifier.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics & Insights',
                style:
                    GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(),
              tabs: const [
                Tab(text: 'Post-Level Analytics'),
                Tab(text: 'User Behavior'),
                Tab(text: 'Credit Usage'),
                Tab(text: 'Engagement by Segment'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // FIX: Pass the filter state to the tab builders
                  _buildPostAnalytics(filterState),
                  _buildUserBehavior(filterState),
                  _buildCreditUsage(filterState),
                  _buildEngagementSegment(filterState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // FIX: This method now accepts and uses the FilterState
  Widget _buildPostAnalytics(FilterState filterState) {
    return FutureBuilder<List<PostAnalytic>>(
      // Use the filterState as a key to force rebuild
      key: ValueKey(filterState.hashCode), 
      future: _adminService.getPostAnalytics(filterState),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final analytics = snapshot.data ?? [];
        if (analytics.isEmpty) {
          return const Center(child: Text('No post analytics available.'));
        }

        // Use StyledCard (it's imported from dashboard_widgets)
        return StyledCard(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Views')),
                DataColumn(label: Text('Likes')),
                DataColumn(label: Text('Saves')),
              ],
              rows: analytics.map((analytic) {
                return DataRow(cells: [
                  DataCell(Text(DateFormat.yMMMd().format(analytic.date))),
                  DataCell(Text(analytic.assetTitle)),
                  DataCell(Text(analytic.assetType)),
                  DataCell(Text(analytic.views.toString())),
                  DataCell(Text(analytic.likes.toString())),
                  DataCell(Text(analytic.saves.toString())),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // FIX: Pass the filter state to the UserGrowthChart as an initial range
  Widget _buildUserBehavior(FilterState filterState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      // Pass the global filter's date range to the chart
      child: UserGrowthChart(
        initialDateRange: filterState.dateRange,
      ),
    );
  }

  // These widgets are not filter-aware yet, but we pass the state
  // for future-proofing.
  Widget _buildCreditUsage(FilterState filterState) {
    // FIX: Use DailyUsageCard from the imported dashboard_widgets
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: DailyUsageCard(), // This widget would also need refactoring
    );
  }

  Widget _buildEngagementSegment(FilterState filterState) {
    // FIX: Use UserGrowthCard from the imported dashboard_widgets
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: UserGrowthCard(), // This widget would also need refactoring
    );
  }
}