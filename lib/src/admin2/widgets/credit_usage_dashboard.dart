import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreditUsageDashboard extends StatefulWidget {
  const CreditUsageDashboard({Key? key}) : super(key: key);

  @override
  State<CreditUsageDashboard> createState() => _CreditUsageDashboardState();
}

class _CreditUsageDashboardState extends State<CreditUsageDashboard> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;

  // Credit stats
  int _totalCreditsRemaining = 0;
  int _totalItemsUnlocked = 0;
  double _avgCreditsRemaining = 0;

  // Credit usage breakdown metrics
  int _detailViews = 0;
  int _designDownloads = 0;
  int _boardSaves = 0;
  int _referralBonuses = 0;
  int _totalCreditsUsedToday = 0;
  double _percentChangeFromYesterday = 0;

  // Low credit users
  List<Map<String, dynamic>> _lowCreditUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchCreditData();
  }

  Future<void> _fetchCreditData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch basic credit stats
      final statsResponse =
          await supabase.rpc('get_credit_usage_stats').single();

      // Fetch credit usage breakdown
      final breakdownData = await _fetchCreditBreakdown();

      // Fetch users with low credits
      final lowCreditData = await supabase
          .from('users')
          .select('id, username, email, full_name, credits_remaining')
          .lt('credits_remaining', 15)
          .order('credits_remaining', ascending: true)
          .limit(10);

      if (mounted) {
        setState(() {
          // Basic stats
          _totalCreditsRemaining =
              statsResponse['total_credits_remaining'] ?? 0;
          _totalItemsUnlocked = statsResponse['total_items_unlocked'] ?? 0;
          _avgCreditsRemaining =
              (statsResponse['avg_credits_remaining'] ?? 0).toDouble();

          // Usage breakdown
          _detailViews = breakdownData['detail_views'] ?? 0;
          _designDownloads = breakdownData['design_downloads'] ?? 0;
          _boardSaves = breakdownData['board_saves'] ?? 0;
          _referralBonuses = breakdownData['referral_bonuses'] ?? 0;
          _totalCreditsUsedToday = breakdownData['total_used_today'] ?? 0;
          _percentChangeFromYesterday = breakdownData['percent_change'] ?? 0;

          // Low credit users
          _lowCreditUsers = List<Map<String, dynamic>>.from(lowCreditData ?? []);

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error fetching credit data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchCreditBreakdown() async {
    try {
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1)).toIso8601String();
      final twoDaysAgo = now.subtract(const Duration(days: 2)).toIso8601String();

      // --- PERFORMANCE FIX: Run all queries in parallel ---

      // 1. Define all futures
      final viewsTodayFuture = supabase
          .from('views')
          .select('id')
          .gte('created_at', oneDayAgo);

      final viewsYesterdayFuture = supabase
          .from('views')
          .select('id')
          .gte('created_at', twoDaysAgo)
          .lt('created_at', oneDayAgo);

      final unlocksTodayFuture = supabase
          .from('user_unlocked_items')
          .select('id')
          .gte('unlocked_at', oneDayAgo);

      final savesTodayFuture = supabase
          .from('boards_pins')
          .select('board_id')
          .gte('created_at', oneDayAgo);

      final referralsDataFuture = supabase
          .from('referrals')
          .select('credits_awarded')
          .gte('created_at', oneDayAgo);

      // 2. Await them all at once
      final results = await Future.wait([
        viewsTodayFuture,
        viewsYesterdayFuture,
        unlocksTodayFuture,
        savesTodayFuture,
        referralsDataFuture,
      ]);

      // 3. Unpack the results
      final viewsToday = results[0] as List;
      final viewsYesterday = results[1] as List;
      final unlocksToday = results[2] as List;
      final savesToday = results[3] as List;
      final referralsData = results[4] as List;

      // --- END PERFORMANCE FIX ---

      final referralCredits = referralsData.fold<int>(
        0,
        (sum, ref) => sum + ((ref['credits_awarded'] as int?) ?? 0),
      );

      final viewsCount = viewsToday.length;
      final viewsYesterdayCount = viewsYesterday.length;
      final unlocksCount = unlocksToday.length;
      final savesCount = savesToday.length;

      final totalToday =
          viewsCount + unlocksCount + savesCount + referralCredits;
      final totalYesterday = viewsYesterdayCount;

      final percentChange = totalYesterday > 0
          ? ((totalToday - totalYesterday) / totalYesterday * 100)
          : 0.0;

      return {
        'detail_views': viewsCount,
        'design_downloads': unlocksCount,
        'board_saves': savesCount,
        'referral_bonuses': referralCredits,
        'total_used_today': totalToday,
        'percent_change': percentChange,
      };
    } catch (e) {
      debugPrint('Error fetching credit breakdown: $e');
      return {
        'detail_views': 0,
        'design_downloads': 0,
        'board_saves': 0,
        'referral_bonuses': 0,
        'total_used_today': 0,
        'percent_change': 0.0,
      };
    }
  }

  Future<void> _sendCreditOffer(Map<String, dynamic> user) async {
    // TODO: Implement send offer functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Credit offer sent to ${user['username'] ?? user['email']}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Stats Row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Credits Remaining',
                  value: _totalCreditsRemaining.toString(),
                  icon: Icons.account_balance_wallet,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Total Items Unlocked',
                  value: _totalItemsUnlocked.toString(),
                  icon: Icons.lock_open,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Avg Credits per User',
                  value: _avgCreditsRemaining.toStringAsFixed(1),
                  icon: Icons.person,
                  color: Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Two column layout for breakdown and alerts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Credit Usage Breakdown
              Expanded(
                flex: 3,
                child: _buildUsageBreakdown(),
              ),

              const SizedBox(width: 16),

              // Credit Shortage Alerts
              Expanded(
                flex: 2,
                child: _buildShortageAlerts(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBreakdown() {
    final total =
        _detailViews + _designDownloads + _boardSaves + _referralBonuses;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Usage Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'How credits are being consumed across the platform',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            _UsageItem(
              label: 'Detail Views',
              count: _detailViews,
              percentage: total > 0 ? (_detailViews / total * 100) : 0,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _UsageItem(
              label: 'Design Downloads',
              count: _designDownloads,
              percentage: total > 0 ? (_designDownloads / total * 100) : 0,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _UsageItem(
              label: 'Board Saves',
              count: _boardSaves,
              percentage: total > 0 ? (_boardSaves / total * 100) : 0,
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
            _UsageItem(
              label: 'Referral Bonuses',
              count: _referralBonuses,
              percentage: total > 0 ? (_referralBonuses / total * 100) : 0,
              color: Colors.orange,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalCreditsUsedToday total credits used today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _percentChangeFromYesterday >= 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_percentChangeFromYesterday >= 0 ? '+' : ''}${_percentChangeFromYesterday.toStringAsFixed(0)}% compared to yesterday',
                    style: TextStyle(
                      color: _percentChangeFromYesterday >= 0
                          ? Colors.green
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortageAlerts() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Shortage Alerts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Users running low on credits',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            if (_lowCreditUsers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No users with low credits'),
                ),
              )
            else
              ..._lowCreditUsers
                  .map((user) => _UserAlertCard(
                        userName: user['username'] ??
                            user['full_name'] ??
                            user['email'] ??
                            'Unknown',
                        creditsRemaining: user['credits_remaining'] ?? 0,
                        onSendOffer: () => _sendCreditOffer(user),
                      ))
                  .toList(),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageItem extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final Color color;

  const _UsageItem({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _UserAlertCard extends StatelessWidget {
  final String userName;
  final int creditsRemaining;
  final VoidCallback onSendOffer;

  const _UserAlertCard({
    required this.userName,
    required this.creditsRemaining,
    required this.onSendOffer,
  });

  @override
  Widget build(BuildContext context) {
    final alertColor = creditsRemaining < 6
        ? Colors.red.shade50
        : creditsRemaining < 10
            ? Colors.orange.shade50
            : Colors.yellow.shade50;

    final textColor = creditsRemaining < 6
        ? Colors.red.shade900
        : creditsRemaining < 10
            ? Colors.orange.shade900
            : Colors.yellow.shade900;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$creditsRemaining credits remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onSendOffer,
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: textColor),
            ),
            child: const Text('Send Offer'),
          ),
        ],
      ),
    );
  }
}