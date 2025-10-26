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
        return response
            .map((item) {
              // If item is null or specifically the array column returns null/empty
              if (item == null || (item is Map && item.values.first == null)) {
                return null;
              }
              // If it's an array, join elements (handle potential non-string elements)
              if (item is List) {
                return item
                    .where((e) => e != null)
                    .map((e) => e.toString())
                    .join(', ');
              }
              // Otherwise, just convert to string
              return item.toString();
            })
            .where((item) =>
                item != null &&
                item.isNotEmpty) // Filter out nulls/empty strings
            .cast<String>()
            .toSet() // Ensure uniqueness
            .toList();
      } else {
        debugPrint(
            'No distinct values found for column: $columnName, unexpected response type from RPC: ${response.runtimeType}');
        return [];
      }
    } catch (e) {
      if (e is PostgrestException &&
          columnName == 'Studded' &&
          e.code == '22P02') {
        debugPrint(
            'Caught known malformed array error for column $columnName. Returning empty list. Error: $e');
        return []; // Return empty list specifically for this error on this column
      } else {
        // Log other errors normally
        debugPrint('Error fetching distinct values for column $columnName: $e');
        return [];
      }
    }
  }

  Future<List<String>> getDependentDistinctValues(
      String columnName, Map<String, String?> filters) async {
    // If no specific filters are selected (only 'All' or null), just get all distinct values.
    if (filters.values.every((v) => v == null || v == 'All')) {
      return getDistinctValues(columnName);
    }

    try {
      // Start building the query
      var query = _supabase
          .from('products')
          .select('"$columnName"'); // Ensure column name with space is quoted

      // Apply each filter from the map
      for (var filter in filters.entries) {
        // Only apply if a specific value (not 'All' or null) is selected
        if (filter.value != null && filter.value != 'All') {
          // Quote the filter key if it contains spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          query = query.eq(filterKey, filter.value!);
        }
      }

      // Execute the query
      final response = await query;

      // Process the response
      if (response is List) {
        final values = response
            .map((item) => item[columnName]?.toString())
            .where((item) => item != null && item.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
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

  Future<Map<String, List<String>>> getInitialFilterOptions() async {
    final filterColumns = ['Product Type', 'Metal Purity', 'Plain', 'Studded'];

    final List<Future<List<String>>> futures = filterColumns
        .map((columnName) => getDistinctValues(columnName))
        .toList();

    final results = await Future.wait(futures);

    return {
      'Product Type': results[0],
      'Metal Purity': results[1],
      'Plain': results[2],
      'Studded': results[3],
    };
  }
}
