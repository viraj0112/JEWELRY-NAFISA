import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class MonetizationSection extends StatefulWidget {
  const MonetizationSection({super.key});

  @override
  State<MonetizationSection> createState() => _MonetizationSectionState();
}

class _MonetizationSectionState extends State<MonetizationSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        Text('Monetization & Membership',
            style:
                GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          tabs: const [
            Tab(text: 'Revenue Dashboard'),
            Tab(text: 'Subscriptions'),
            Tab(text: 'Upsell Funnel'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              RevenueDashboardTab(),
              SubscriptionsTab(),
              UpsellFunnelTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// --- TAB 1: Revenue Dashboard ---
class RevenueDashboardTab extends StatelessWidget {
  const RevenueDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      children: const [
        // MetricsGrid(),
        SizedBox(height: 24),
        ChartGrid(),
      ],
    );
  }
}

// --- TAB 2: Subscriptions Management ---
class SubscriptionsTab extends StatelessWidget {
  const SubscriptionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildSubscriptionsList();
        } else {
          return _buildSubscriptionsTable();
        }
      },
    );
  }

  // Table view for larger screens
  Widget _buildSubscriptionsTable() {
    return StyledCard(
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search by user email or plan...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Next Billing')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(
                    10,
                    (index) => DataRow(cells: [
                          const DataCell(Text('member@email.com')),
                          const DataCell(Text('Premium Monthly')),
                          DataCell(Chip(
                            label: Text(index.isEven ? 'Active' : 'Expired'),
                            backgroundColor:
                                (index.isEven ? Colors.green : Colors.grey)
                                    .withOpacity(0.1),
                            side: BorderSide.none,
                          )),
                          DataCell(Text(index.isEven ? '2025-10-15' : '-')),
                          DataCell(IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.more_vert))),
                        ])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List view for smaller screens
  Widget _buildSubscriptionsList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        final isActive = index.isEven;
        return StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('member@email.com',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('Premium Monthly',
                  style: TextStyle(color: Colors.grey)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Next Billing'),
                      Text(isActive ? '2025-10-15' : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Chip(
                    label: Text(isActive ? 'Active' : 'Expired'),
                    backgroundColor: (isActive ? Colors.green : Colors.grey)
                        .withOpacity(0.1),
                    side: BorderSide.none,
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

// --- TAB 3: Upsell Funnel ---
class UpsellFunnelTab extends StatelessWidget {
  const UpsellFunnelTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: GoalCompletionCard(),
    );
  }
}
