import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FilterService {
  final _supabase = Supabase.instance.client;

  Future<List<String>> getDistinctValues(String columnName) async {
    try {
      final response = await _supabase.rpc(
        'get_distinct_product_values',
        params: {'column_name': columnName},
      );

      if (response is List) {
        // Process the list returned from the RPC
        return response
            .map((item) => item?.toString())
            .where((item) => item != null && item.isNotEmpty)
            .cast<String>()
            .toList();
      } else {
        debugPrint(
            'No distinct values found for column: $columnName, unexpected response type from RPC: ${response.runtimeType}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching distinct values for column $columnName: $e');
      return [];
    }
  }

  /// **FIXED:** Fetches distinct values for a column based on other filters.
  Future<List<String>> getDependentDistinctValues(
      String columnName, Map<String, String?> filters) async {
    // Check if all filters are 'All' or null
    if (filters.values.every((v) => v == null || v == 'All')) {
      // If no specific filters are applied, just get all distinct values.
      return getDistinctValues(columnName);
    }

    try {
      // 1. Start the query.
      // **FIX: Force quotes around the column name to handle spaces.**
      var query = _supabase.from('products').select('"$columnName"');

      // 2. Apply dependent filters
      for (var filter in filters.entries) {
        if (filter.value != null && filter.value != 'All') {
          // Use quotes for filter keys if they contain spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          query = query.eq(filterKey, filter.value!);
        }
      }

      // 3. Execute the query
      final response = await query;

      if (response is List) {
        // 4. Process the results client-side to get distinct values
        // The response map key will be the unquoted column name.
        final values = response
            .map((item) => item[columnName]?.toString())
            .where((item) => item != null && item.isNotEmpty)
            .cast<String>()
            .toSet() // Use toSet() to get unique values
            .toList(); // Convert back to list
        return values;
      } else {
        debugPrint(
            'No distinct values found for column: $columnName, unexpected response type: ${response.runtimeType}');
        return [];
      }
    } catch (e) {
      debugPrint(
          'Error fetching dependent distinct values for column $columnName: $e');
      return [];
    }
  }

  /// **MODIFIED:** Renamed and changed to only fetch *independent* filters.
  Future<Map<String, List<String>>> getInitialFilterOptions() async {
    // Only fetch filters that do NOT depend on other filters
    final filterColumns = ['Product Type', 'Plain', 'Studded'];

    final List<Future<List<String>>> futures = filterColumns
        .map((columnName) => getDistinctValues(columnName))
        .toList();

    final results = await Future.wait(futures);

    return {
      'Product Type': results[0],
      'Plain': results[1],
      'Studded': results[2], 
    };
  }
}
