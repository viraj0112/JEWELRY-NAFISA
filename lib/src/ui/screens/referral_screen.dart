import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:share_plus/share_plus.dart';
import "package:intl/intl.dart";
import "package:supabase_flutter/supabase_flutter.dart";


class Referral{
  final String username;
  final DateTime date;
  final int creditsEarned;

  Referral({
    required this.username,
    required this.date,
    required this.creditsEarned,
  });
}


class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<List<Referral>> _referralHistoryFuture;

  @override
  void initState() {
    super.initState();
    _referralHistoryFuture = _fetchReferralHistory();
  }

  Future<List<Referral>> _fetchReferralHistory() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    try {
      final response = await supabase
          .from('referrals')
          .select('credits_awarded, created_at, referred:referred_id(username)')
          .eq('referrer_id', userId)
          .order('created_at', ascending: false);

      if (response is! List || response.isEmpty) {
        return [];
      }
      
      return response.map((item) {
        return Referral(
          username: item['referred']?['username'] ?? 'A user',
          date: DateTime.parse(item['created_at']),
          creditsEarned: item['credits_awarded'] ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error fetching referral history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch referral history: $e')),
        );
      }
      return [];
    }
  }


  @override
  Widget build(BuildContext context) {
    final userProfile = context.watch<UserProfileProvider>();
    final referralCode = userProfile.referralCode ?? 'Generating...';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildDesktopLayout(context, referralCode);
        } else {
          return _buildMobileLayout(context, referralCode);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, String referralCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReferralCard(context, referralCode),
          const SizedBox(height: 24),
          _buildReferralHistory(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, String referralCode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildReferralCard(context, referralCode)),
          const SizedBox(width: 32),
          Expanded(flex: 3, child: _buildReferralHistory(context)),
        ],
      ),
    );
  }

  Widget _buildReferralCard(BuildContext context, String referralCode) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Share Your Code, Get Credits!',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Invite friends to join with your unique referral code. When they sign up, you both get rewarded with extra credits!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Your Referral Code:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: referralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Referral code copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: theme.colorScheme.secondary),
                ),
                child: Text(
                  referralCode,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  'Join using my referral code to get exclusive benefits: $referralCode',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share My Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralHistory(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Referral History', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        FutureBuilder<List<Referral>>(
          future: _referralHistoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load history.'));
            }
            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No referrals yet. Share your code to get started!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return _buildHistoryItem(
                  context,
                  username: item.username,
                  date: DateFormat.yMMMd().format(item.date),
                  creditsEarned: '+${item.creditsEarned} Credits',
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required String username,
    required String date,
    required String creditsEarned,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text('$username joined!'),
        subtitle: Text('On $date'),
        trailing: Text(
          creditsEarned,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
