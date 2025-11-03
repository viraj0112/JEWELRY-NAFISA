import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/enhanced_admin_models.dart';

class EngagementGraphWidget extends StatefulWidget {
  final EngagementData engagementData;

  const EngagementGraphWidget({
    super.key,
    required this.engagementData,
  });

  @override
  State<EngagementGraphWidget> createState() => _EngagementGraphWidgetState();
}

class _EngagementGraphWidgetState extends State<EngagementGraphWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedMetric = 'all';

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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Engagement Graph',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildMetricSelector(),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Views'),
                  Tab(text: 'Unlocks'),
                  Tab(text: 'Saves'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllMetricsChart(),
                  _buildSingleMetricChart(widget.engagementData.views, Colors.blue),
                  _buildSingleMetricChart(widget.engagementData.unlocks, Colors.orange),
                  _buildSingleMetricChart(widget.engagementData.saves, Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildEngagementStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 20),
      onSelected: (value) {
        setState(() {
          _selectedMetric = value;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('All Metrics')),
        const PopupMenuItem(value: 'views', child: Text('Views Only')),
        const PopupMenuItem(value: 'unlocks', child: Text('Unlocks Only')),
        const PopupMenuItem(value: 'saves', child: Text('Saves Only')),
      ],
    );
  }

  Widget _buildAllMetricsChart() {
    if (widget.engagementData.views.isEmpty) {
      return const Center(
        child: Text('No engagement data available'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _buildChartArea(),
        ),
        const SizedBox(height: 8),
        _buildChartLegend(),
      ],
    );
  }

  Widget _buildSingleMetricChart(List<TimeSeriesPoint> data, Color color) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _buildSingleMetricChartArea(data, color),
        ),
        const SizedBox(height: 8),
        _buildSingleMetricLegend(color),
      ],
    );
  }

  Widget _buildChartArea() {
    return CustomPaint(
      size: Size(double.infinity, double.infinity),
      painter: MultiLineChartPainter(
        data: widget.engagementData,
      ),
    );
  }

  Widget _buildSingleMetricChartArea(List<TimeSeriesPoint> data, Color color) {
    return CustomPaint(
      size: Size(double.infinity, double.infinity),
      painter: SingleLineChartPainter(
        data: data,
        color: color,
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.blue, 'Views'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.orange, 'Unlocks'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.green, 'Saves'),
        const SizedBox(width: 16),
        _buildLegendItem(Colors.purple, 'Shares'),
      ],
    );
  }

  Widget _buildSingleMetricLegend(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Engagement Trend',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEngagementStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Views',
            _calculateTotalViews().toString(),
            Icons.visibility,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Unlocks',
            _calculateTotalUnlocks().toString(),
            Icons.lock_open,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Saves',
            _calculateTotalSaves().toString(),
            Icons.bookmark_border,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalViews() {
    return widget.engagementData.views.fold(0, (sum, point) => sum + point.value);
  }

  int _calculateTotalUnlocks() {
    return widget.engagementData.unlocks.fold(0, (sum, point) => sum + point.value);
  }

  int _calculateTotalSaves() {
    return widget.engagementData.saves.fold(0, (sum, point) => sum + point.value);
  }
}

// Custom painters for the charts
class MultiLineChartPainter extends CustomPainter {
  final EngagementData data;

  MultiLineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final viewPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blue;

    final unlockPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.orange;

    final savePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    // Simple line drawing (placeholder implementation)
    if (data.views.isEmpty) return;

    final points = data.views;
    // Fix: Handle single point case to avoid division by zero
    if (points.length == 1) {
      final x = size.width / 2;
      final maxValue = points[0].value.toDouble();
      final y = maxValue > 0 ? size.height - (points[0].value / maxValue * size.height) : size.height / 2;
      canvas.drawCircle(Offset(x, y), 4, viewPaint..style = PaintingStyle.fill);
      return;
    }

    final stepX = size.width / (points.length - 1);
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b).toDouble();
    
    // Fix: Handle case where maxValue is 0 to avoid division by zero
    if (maxValue == 0) {
      final y = size.height / 2;
      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final x = i * stepX;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, viewPaint);
      return;
    }
    
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].value / maxValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, viewPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SingleLineChartPainter extends CustomPainter {
  final List<TimeSeriesPoint> data;
  final Color color;

  SingleLineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = color;

    if (data.isEmpty) return;

    final points = data;
    // Fix: Handle single point case to avoid division by zero
    if (points.length == 1) {
      final x = size.width / 2;
      final maxValue = points[0].value.toDouble();
      final y = maxValue > 0 ? size.height - (points[0].value / maxValue * size.height) : size.height / 2;
      canvas.drawCircle(Offset(x, y), 4, paint..style = PaintingStyle.fill);
      return;
    }

    final stepX = size.width / (points.length - 1);
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b).toDouble();
    
    // Fix: Handle case where maxValue is 0 to avoid division by zero
    if (maxValue == 0) {
      final y = size.height / 2;
      final path = Path();
      for (int i = 0; i < points.length; i++) {
        final x = i * stepX;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      return;
    }
    
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].value / maxValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}