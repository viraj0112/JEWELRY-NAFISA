import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this to your pubspec.yaml for number formatting

class Metric {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final double percentageChange;

  Metric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.percentageChange,
  });
}

// 2. The reusable widget for displaying a single metric card.
class MetricCard extends StatelessWidget {
  final Metric metric;

  const MetricCard({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    // Helper to format large numbers with commas
    final formatter = NumberFormat('#,###');

    return Container(
      width: 180, // Set a fixed width for each card
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            formatter.format(metric.value),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPercentageChange(metric.percentageChange),
          const SizedBox(height: 8),
          Text(
            metric.label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // A helper widget to build the percentage row with color and icon
  Widget _buildPercentageChange(double change) {
    final bool isPositive = change >= 0;
    final Color color = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    final IconData icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// 3. A stateful widget to display the grid of metric cards.
// This is where you would fetch and update data based on filters.
class MetricsGrid extends StatefulWidget {
  const MetricsGrid({super.key});

  @override
  State<MetricsGrid> createState() => _MetricsGridState();
}

class _MetricsGridState extends State<MetricsGrid> {
  // Your dynamic data would live here.
  // In a real app, you would update this list in setState() when filters change.
  late List<Metric> _metricsData;

  @override
  void initState() {
    super.initState();
    // Initialize with sample data
    _metricsData = [
      Metric(icon: Icons.group_work_outlined, color: Colors.green, label: 'Total Members', value: 1847, percentageChange: 12.3),
      Metric(icon: Icons.person_outline, color: Colors.blue, label: 'Non-Members', value: 5234, percentageChange: 8.7),
      Metric(icon: Icons.person_pin_circle_outlined, color: Colors.purple, label: 'Daily Active Users', value: 892, percentageChange: 5.2),
      Metric(icon: Icons.credit_card_outlined, color: Colors.orange, label: 'Credits Used Today', value: 2341, percentageChange: -3.1),
      Metric(icon: Icons.share_outlined, color: Colors.pink, label: 'Referrals', value: 156, percentageChange: 18.9),
      Metric(icon: Icons.visibility_outlined, color: Colors.indigo, label: 'Posts Viewed', value: 12847, percentageChange: 22.4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Using a Wrap widget makes the layout responsive for different screen sizes.
    return Wrap(
      spacing: 16.0, // Horizontal space between cards
      runSpacing: 16.0, // Vertical space between rows
      alignment: WrapAlignment.center,
      children: _metricsData.map((metric) {
        // Map each data object to a MetricCard widget
        return MetricCard(metric: metric);
      }).toList(),
    );
  }
}