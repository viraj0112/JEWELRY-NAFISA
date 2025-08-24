import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    final topPostsResponse = await supabase
        .from('analytics_daily')
        .select('*, assets(*)')
        .eq('assets.owner_id', userId)
        .order('views', ascending: false)
        .limit(10);

    final globalTopPostsResponse = await supabase
        .from('analytics_daily')
        .select('*, assets(*)')
        .order('views', ascending: false)
        .limit(10);

    final totalViewsResponse = await supabase
        .from('analytics_daily')
        .select('views')
        .eq('assets.owner_id', userId);
    final totalLikesResponse = await supabase
        .from('analytics_daily')
        .select('likes')
        .eq('assets.owner_id', userId);

    return {
      'top_posts': List<Map<String, dynamic>>.from(topPostsResponse),
      'global_top_posts': List<Map<String, dynamic>>.from(globalTopPostsResponse),
      'total_views': (totalViewsResponse as List).fold(0, (prev, e) => prev + (e['views'] as int)),
      'total_likes': (totalLikesResponse as List).fold(0, (prev, e) => prev + (e['likes'] as int)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final analytics = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Performance", style: theme.textTheme.headlineMedium),
                const SizedBox(height: 24),
                Text("Top 10 Posts of the Day (Global)", style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildPostList(analytics['global_top_posts']),
                const SizedBox(height: 16),
                Text("Top 10 For Your Posts", style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildPostList(analytics['top_posts']),
                const SizedBox(height: 24),
                Text("Post-Level Metrics", style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                _buildMetricCard(
                    title: 'Total Views',
                    value: analytics['total_views'].toString()),
                _buildMetricCard(
                    title: 'Total Likes',
                    value: analytics['total_likes'].toString()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(List<Map<String, dynamic>> posts) {
    if (posts.isEmpty) {
      return const Card(child: ListTile(title: Text("No data available.")));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Card(
          child: ListTile(
            leading: Image.network(post['assets']['media_url'],
                width: 50, height: 50, fit: BoxFit.cover),
            title: Text(post['assets']['title']),
            trailing: Text("Views: ${post['views']}"),
          ),
        );
      },
    );
  }
}