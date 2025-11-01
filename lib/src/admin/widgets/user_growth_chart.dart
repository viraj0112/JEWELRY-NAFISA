import 'package:flutter/material.dart';
// FIX: Change to ConsumerWidget
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

final userGrowthProvider =
    FutureProvider.family<List<TimeSeriesData>, DateTimeRange>(
        (ref, dateRange) {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getUserGrowth(dateRange);
});

// FIX: Convert to ConsumerStatefulWidget
class UserGrowthChart extends ConsumerStatefulWidget {
  // FIX: Add optional initial date range
  final DateTimeRange? initialDateRange;

  const UserGrowthChart({super.key, this.initialDateRange});

  @override
  ConsumerState<UserGrowthChart> createState() => _UserGrowthChartState();
}

class _UserGrowthChartState extends ConsumerState<UserGrowthChart> {
  late DateTimeRange _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // FIX: Use the initialDateRange from the widget if provided
    final now = DateTime.now();
    _selectedDateRange = widget.initialDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
  }

  // FIX: Add this to update the chart if the global filter changes
  @override
  void didUpdateWidget(covariant UserGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateRange != null &&
        widget.initialDateRange != _selectedDateRange) {
      setState(() {
        _selectedDateRange = widget.initialDateRange!;
      });
      // Invalidate the provider to refetch with the new global range
      ref.invalidate(userGrowthProvider(_selectedDateRange));
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      // Invalidate to refetch with the new *manually* picked range
      ref.invalidate(userGrowthProvider(_selectedDateRange));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider with the *current* selected date range
    final chartDataAsync = ref.watch(userGrowthProvider(_selectedDateRange));
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (rest of your build method is fine)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User Growth Over Time',
                  style: theme.textTheme.headlineSmall,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${DateFormat.yMd().format(_selectedDateRange.start)} - ${DateFormat.yMd().format(_selectedDateRange.end)}',
                  ),
                  onPressed: () => _selectDateRange(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: chartDataAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return const Center(
                        child: Text('No data for this period.'));
                  }
                  return SfCartesianChart(
                    primaryXAxis: DateTimeAxis(
                      edgeLabelPlacement: EdgeLabelPlacement.shift,
                      dateFormat: DateFormat.Md(),
                    ),
                    primaryYAxis: NumericAxis(
                      title: AxisTitle(text: 'New Users'),
                      majorGridLines: const MajorGridLines(width: 0.5),
                    ),
                    series: <CartesianSeries<TimeSeriesData, DateTime>>[
                      LineSeries<TimeSeriesData, DateTime>(
                        dataSource: data,
                        xValueMapper: (TimeSeriesData sales, _) => sales.time,
                        yValueMapper: (TimeSeriesData sales, _) => sales.value,
                        name: 'New Users',
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                    ],
                    tooltipBehavior: TooltipBehavior(enable: true),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
