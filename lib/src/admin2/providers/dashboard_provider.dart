import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_models.dart';
import '../services/dashboard_service.dart';

final dashboardTimeRangeProvider = StateProvider<String>((ref) => '7d');
final dashboardRealTimeProvider = StateProvider<bool>((ref) => false);

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final timeRange = ref.watch(dashboardTimeRangeProvider);
  return DashboardService.fetchDashboardData(timeRange: timeRange);
});

final geographicLevelProvider = StateProvider<String>((ref) => 'country');
final geographicParentProvider = StateProvider<String>((ref) => '');

final geographicDataProvider = FutureProvider<GeographicData>((ref) async {
  final level = ref.watch(geographicLevelProvider);
  final parent = ref.watch(geographicParentProvider);
  // For now, return default data - will be implemented when needed
  return GeographicData(level: level, parentCode: parent, items: []);
});

class DashboardNotifier extends StateNotifier<DashboardData?> {
  DashboardNotifier() : super(null);

  Future<void> loadData({String timeRange = '7d'}) async {
    try {
      final data = await DashboardService.fetchDashboardData(timeRange: timeRange);
      state = data;
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      // Keep previous state on error
    }
  }

  void updateTimeRange(String timeRange) {
    loadData(timeRange: timeRange);
  }

  void refresh() {
    if (state != null) {
      loadData(timeRange: '7d'); // Default to 7d on refresh
    }
  }
}

final dashboardNotifierProvider = StateNotifierProvider<DashboardNotifier, DashboardData?>((ref) {
  return DashboardNotifier();
});