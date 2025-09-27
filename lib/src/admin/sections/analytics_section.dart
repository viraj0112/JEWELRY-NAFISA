import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        Text('Analytics & Insights', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
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

  Widget _buildPostAnalytics() {
    // TODO: Fetch Post Analytics data from Supabase
    return const StyledCard(child: Center(child: Text('Post-Level Analytics - Table/Grid view of all posts with filters.')));
  }

  Widget _buildUserBehavior() {
    // TODO: Fetch User Behavior data from Supabase
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: ChartGrid(), // Reusing the main chart grid
    );
  }

  Widget _buildCreditUsage() {
    // TODO: Fetch Credit Usage data from Supabase
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: DailyUsageCard(), // Using a specific chart
    );
  }
  
  Widget _buildEngagementSegment() {
    // TODO: Fetch Engagement Segment data from Supabase
     return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: UserGrowthCard(), // Using a specific chart
    );
  }
}