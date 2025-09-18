import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const MetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Icon(icon, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideX();
  }
}
