import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
// FIX: Import the detailed user growth chart
import 'package:jewelry_nafisa/src/admin/widgets/user_growth_chart.dart'; 
// FIX: Import the dashboard widgets (like DailyUsageCard)
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart'; 
import 'package:intl/intl.dart';

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
              _buildPostAnalytics(),
              _buildUserBehavior(),
              _buildCreditUsage(),
              _buildEngagementSegment(),
            ],
          ),
        ),
      ],
    );
  }

  // FIX: The duplicate build method that was here has been removed.

  Widget _buildPostAnalytics() {
    return FutureBuilder<List<PostAnalytic>>(
      future: _adminService.getPostAnalytics(),
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

  Widget _buildUserBehavior() {
    // FIX: Use the UserGrowthChart we created, not the non-existent 'ChartGrid'
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: UserGrowthChart(), 
    );
  }

  Widget _buildCreditUsage() {
    // FIX: Use DailyUsageCard from the imported dashboard_widgets
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: DailyUsageCard(), 
    );
  }

  Widget _buildEngagementSegment() {
    // FIX: Use UserGrowthCard from the imported dashboard_widgets
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: UserGrowthCard(), 
    );
  }
}