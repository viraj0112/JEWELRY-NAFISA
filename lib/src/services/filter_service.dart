import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FilterService {
  final _supabase = Supabase.instance.client;

  Future<List<String>> getDistinctArrayValues(String columnName) async {
    try {
      // Call the NEW function you just created in the Supabase SQL Editor
      final response = await _supabase.rpc(
        'get_distinct_unnested_values',
        params: {'column_name': columnName},
      );

      if (response is List) {
        return response
            .map((item) => item?.toString())
            .where((item) => item != null && item.isNotEmpty)
            .cast<String>()
            .toList();
      } else {
        debugPrint(
            'No distinct array values found for column: $columnName, unexpected response type from RPC: ${response.runtimeType}');
        return [];
      }
    } catch (e) {
      debugPrint(
          'Error fetching distinct array values for column $columnName: $e');
      return [];
    }
  }

  Future<List<String>> getDistinctValues(String columnName) async {
    try {
      final response = await _supabase.rpc(
        'get_distinct_product_values',
        params: {'column_name': columnName},
      );

      if (response is List) {
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
    // Separate columns by their type (text vs. array)
    final textColumns = ['Product Type', 'Metal Purity', 'Plain'];
    final arrayColumns = ['Studded']; // 'Studded' is an ARRAY column

    // Fetch text values using the old function
    final List<Future<List<String>>> textFutures =
        textColumns.map((columnName) => getDistinctValues(columnName)).toList();

    // Fetch array values using the NEW function
    final List<Future<List<String>>> arrayFutures = arrayColumns
        .map((columnName) =>
            getDistinctArrayValues(columnName)) // <-- Use the new function
        .toList();

    // Wait for all futures to complete
    final textResults = await Future.wait(textFutures);
    final arrayResults = await Future.wait(arrayFutures);

    // Map results back
    return {
      'Product Type': textResults[0],
      'Metal Purity': textResults[1],
      'Plain': textResults[2],
      'Studded': arrayResults[0], // <-- Get result from array futures
    };
  }
}
