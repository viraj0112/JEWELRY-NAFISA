import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Performance", style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            // Placeholder for Top 10 lists
            Text("Top 10 Posts of the Day (Global)", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Card(child: ListTile(title: Text("Fetching data..."))),
            const SizedBox(height: 16),
            Text("Top 10 For Your Posts", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Card(child: ListTile(title: Text("Fetching data..."))),
            const SizedBox(height: 24),
            // Placeholder for individual post metrics
            Text("Post-Level Metrics", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _buildMetricCard(title: 'Total Views', value: '1,234'),
            _buildMetricCard(title: 'Total Likes', value: '567'),
            _buildMetricCard(title: 'Total Saves', value: '89'),
            _buildMetricCard(title: 'Quotes Requested', value: '12'),
          ],
        ),
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
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}