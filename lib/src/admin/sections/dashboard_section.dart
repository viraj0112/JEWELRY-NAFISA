import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:jewelry_nafisa/src/admin/widgets/filter_component.dart';
import 'package:provider/provider.dart';

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  late FilterStateNotifier _filterNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start listening to the global filter notifier
    _filterNotifier = context.watch<FilterStateNotifier>();
    _filterNotifier.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterNotifier.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    // TODO: Use the new filter state to fetch data from Supabase
    // final filters = _filterNotifier.value;
    // print("Filters updated: ${filters.dateRangeType}, ${filters.category}");
    // fetchDashboardData(filters);

    // You can use setState if you need to show a loading indicator
    // setState(() => _isLoading = true);
  }

  @override
  Widget build(BuildContext context) {
    // The main scrollable view for the dashboard content
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          24, 0, 24, 24), // Adjust padding as filter is outside now
      children: const [
        // The header can be simplified if needed, or kept
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Dashboard Overview',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 24),

        // Redesigned Key Performance Indicators (KPIs)
        MetricsGrid(),

        SizedBox(height: 24),

        // Redesigned & Responsive Charts and Graphs
        ChartGrid(),
      ],
    );
  }
}
