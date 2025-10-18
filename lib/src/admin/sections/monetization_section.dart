import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart'; // <-- ADDED

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
class RevenueDashboardTab extends StatefulWidget {
  const RevenueDashboardTab({super.key});

  @override
  State<RevenueDashboardTab> createState() => _RevenueDashboardTabState();
}

class _RevenueDashboardTabState extends State<RevenueDashboardTab> {
  final AdminService _adminService = AdminService();
  late final Future<Map<String, dynamic>> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _adminService.getMonetizationMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _metricsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No metrics available.'));
            }
            final metrics = snapshot.data!;

            final revenue = (metrics['totalRevenue'] as num?)?.toInt() ?? 0;
            final subscriptions =
                (metrics['subscriptions'] as num?)?.toInt() ?? 0;
            final conversionRate =
                (metrics['conversionRate'] as num?)?.toDouble() ?? 0.0;
            final mrr =
                (metrics['monthlyRecurringRevenue'] as num?)?.toInt() ?? 0;

            final metricsData = [
              {
                'icon': Icons.attach_money,
                'color': const Color(0xFF00AB55),
                'label': 'Total Revenue',
                'value': revenue,
                'change': 0.0, // Static
              },
              {
                'icon': Icons.card_membership,
                'color': const Color(0xFF00B8D9),
                'label': 'Active Subscriptions',
                'value': subscriptions,
                'change': 0.0, // Change not calculated
              },
              {
                'icon': Icons.trending_up,
                'color': const Color(0xFFFFC107),
                'label': 'Conversion Rate',
                'value': (conversionRate * 100)
                    .toStringAsFixed(1), // Display as percentage
                'isPercentage': true, // Custom flag to adjust display
                'change': 0.0, // Change not calculated
              },
              {
                'icon': Icons.autorenew,
                'color': const Color(0xFFFF4842),
                'label': 'Est. MRR',
                'value': mrr,
                'change': 0.0, // Static
              },
            ];

            return LayoutBuilder(builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;
              return isMobile
                  ? Column(
                      children: metricsData
                          .map((metric) => _buildRevenueCard(metric))
                          .toList())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: metricsData
                          .map((metric) => Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  child: _buildRevenueCard(metric),
                                ),
                              ))
                          .toList(),
                    );
            });
          },
        ),
      ],
    );
  }

  Widget _buildRevenueCard(Map<String, dynamic> data) {
    bool isPercentage = data['isPercentage'] ?? false;
    return StyledCard(
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['label'],
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      color: (data['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(data['icon'], color: data['color'], size: 22),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              isPercentage ? '${data['value']}%' : '${data['value']}',
              style:
                  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isPercentage ? 'This month' : 'All time',
              style:
                  GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}

// --- TAB 2: Subscriptions Management ---
class SubscriptionsTab extends StatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  final AdminService _adminService = AdminService();
  late Stream<List<AppUser>> _subscriptionStream;
  // TODO: Implement search and filter logic

  // MODIFIED: Corrected this line
  final FilterState _filterState = FilterState.defaultFilters();

  @override
  void initState() {
    super.initState();
    _subscriptionStream = _adminService.getUsers(
      userType: 'Members',
      filterState: _filterState,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _subscriptionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No subscriptions found.'));
        }

        final users = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildSubscriptionsList(users);
            } else {
              return _buildSubscriptionsTable(users);
            }
          },
        );
      },
    );
  }

  Widget _buildSubscriptionsTable(List<AppUser> users) {
    return StyledCard(
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search by user email or plan...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            // TODO: Implement search logic
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
                  DataColumn(label: Text('Member Since')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: users.map((user) {
                  final status = user.membershipStatus ?? 'unknown';
                  final bool isActive = status == 'active';
                  return DataRow(cells: [
                    DataCell(Text(user.email ?? 'No email')),
                    DataCell(Text(user.membershipPlan ?? 'N/A')),
                    DataCell(Chip(
                      label: Text(status),
                      backgroundColor: (isActive ? Colors.green : Colors.grey)
                          .withOpacity(0.1),
                      side: BorderSide.none,
                    )),
                    DataCell(Text(user.createdAt != null
                        ? DateFormat.yMd()
                            .format(user.createdAt!) // <-- Fixed by import
                        : 'N/A')),
                    DataCell(IconButton(
                        onPressed: () {
                          // TODO: Show user details dialog
                        },
                        icon: const Icon(Icons.more_vert))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(List<AppUser> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final status = user.membershipStatus ?? 'unknown';
        final bool isActive = status == 'active';
        return StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email ?? 'No email',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(user.membershipPlan ?? 'N/A',
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Member Since'),
                      Text(
                          user.createdAt != null
                              ? DateFormat.yMd().format(
                                  user.createdAt!) // <-- Fixed by import
                              : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Chip(
                    label: Text(status),
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
