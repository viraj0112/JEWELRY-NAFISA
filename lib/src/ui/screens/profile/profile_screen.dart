import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/referral_screen.dart';
import 'package:jewelry_nafisa/src/ui/widgets/credit_info_card.dart';
import 'package:jewelry_nafisa/src/ui/screens/profile/quote_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, int>> _quoteStatsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _quoteStatsFuture =
        context.read<UserProfileProvider>().getQuoteStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>();
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, userProfile),
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'My Account'),
                    Tab(text: 'My Credits'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyAccountTab(userProfile),
            const ReferralScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfileProvider user) {
    final theme = Theme.of(context);
    final avatarUrl = user.userProfile?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                backgroundColor: theme.colorScheme.surface,
                child: avatarUrl == null
                    ? Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 48,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: -10,
                child: user.isMember
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.6),
                              blurRadius: 12.0,
                              spreadRadius: 3.0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 32),
                      )
                    : Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.scaffoldBackgroundColor,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.grey[400], size: 32),
                            Icon(Icons.lock, color: Colors.grey[600], size: 14),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(user.username, style: theme.textTheme.headlineMedium),
          Text(
            user.userProfile?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMyAccountTab(UserProfileProvider userProfile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CreditInfoCard(),
          const SizedBox(height: 16),
          if (!userProfile.isMember) ...[
            _buildMembershipSection(context),
            const SizedBox(height: 16),
          ],
          _buildQuotesCard(context, userProfile),
        ],
      ),
    );
  }

  Widget _buildQuotesCard(
      BuildContext context, UserProfileProvider userProfile) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _quoteStatsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Could not load quotes')),
            ),
          );
        }

        final stats = snapshot.data ?? {'total': 0, 'valid': 0, 'expired': 0};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Quotes', style: theme.textTheme.titleLarge),
                    TextButton(
                      // FIX: Corrected the navigation logic
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const QuoteHistoryScreen(),
                          ),
                        );
                      },
                      child: const Text('View Detail History'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStatRow('Total Quotes:', stats['total'].toString()),
                _buildStatRow('Expired:', stats['expired'].toString()),
                _buildStatRow('Valid:', stats['valid'].toString()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membership Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Eligible for Free Making on Jewelry, Get Discount on Making Charges, Free Jewelry Cleaning, Discount on your Occasions',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BuyMembershipScreen(),
                ),
              ),
              child: const Text('Become a Lifetime Golden Member'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}