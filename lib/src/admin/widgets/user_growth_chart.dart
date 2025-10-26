import 'package:flutter/material.dart';
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

class UserGrowthChart extends ConsumerStatefulWidget {
  const UserGrowthChart({super.key});

  @override
  ConsumerState<UserGrowthChart> createState() => _UserGrowthChartState();
}

class _UserGrowthChartState extends ConsumerState<UserGrowthChart> {
  late DateTimeRange _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
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
      ref.invalidate(userGrowthProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartDataAsync = ref.watch(userGrowthProvider(_selectedDateRange));
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
