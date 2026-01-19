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
      // Special handling for Category to aggregate Category, Category1, Category2, Category3
      if (columnName == 'Category') {
        return await _getDistinctCategoryValues();
      }

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

  /// Fetches distinct category values from Category, Category1, Category2, Category3 columns
  /// across both 'products' and 'designerproducts' tables
  Future<List<String>> _getDistinctCategoryValues() async {
    try {
      final Set<String> values = {};

      // Query products table for all category columns
      final productsResponse = await _supabase
          .from('products')
          .select('Category, Category1, Category2, Category3');

      if (productsResponse is List) {
        for (var item in productsResponse) {
          if (item['Category'] != null && item['Category'].toString().isNotEmpty) {
            values.add(item['Category'].toString());
          }
          if (item['Category1'] != null && item['Category1'].toString().isNotEmpty) {
            values.add(item['Category1'].toString());
          }
          if (item['Category2'] != null && item['Category2'].toString().isNotEmpty) {
            values.add(item['Category2'].toString());
          }
          if (item['Category3'] != null && item['Category3'].toString().isNotEmpty) {
            values.add(item['Category3'].toString());
          }
        }
      }

      // Query designerproducts table for all category columns
      final designerResponse = await _supabase
          .from('designerproducts')
          .select('Category, Category1, Category2, Category3');

      if (designerResponse is List) {
        for (var item in designerResponse) {
          if (item['Category'] != null && item['Category'].toString().isNotEmpty) {
            values.add(item['Category'].toString());
          }
          if (item['Category1'] != null && item['Category1'].toString().isNotEmpty) {
            values.add(item['Category1'].toString());
          }
          if (item['Category2'] != null && item['Category2'].toString().isNotEmpty) {
            values.add(item['Category2'].toString());
          }
          if (item['Category3'] != null && item['Category3'].toString().isNotEmpty) {
            values.add(item['Category3'].toString());
          }
        }
      }

      return values.toList()..sort();
    } catch (e) {
      debugPrint('Error fetching distinct category values: $e');
      return [];
    }
  }

  /// **FIXED:** Fetches distinct values for a column based on other filters.
  /// Now queries both 'products' and 'designerproducts' tables.
  /// Special handling for Category column to aggregate Category, Category1, Category2, Category3
  Future<List<String>> getDependentDistinctValues(
      String columnName, Map<String, String?> filters) async {
    // Check if all filters are 'All' or null
    if (filters.values.every((v) => v == null || v == 'All')) {
      // If no specific filters are applied, just get all distinct values.
      return getDistinctValues(columnName);
    }

    // Special handling for Category to aggregate all category columns
    if (columnName == 'Category') {
      return await _getDependentDistinctCategoryValues(filters);
    }

    try {
      // 1. Start queries for both tables.
      // **FIX: Force quotes around the column name to handle spaces.**
      final columnKey = columnName.contains(' ') ? '"$columnName"' : columnName;
      var productsQuery = _supabase.from('products').select(columnKey);
      var designerQuery = _supabase.from('designerproducts').select(columnKey);

      // 2. Apply dependent filters to both queries
      for (var filter in filters.entries) {
        if (filter.value != null && filter.value != 'All') {
          // Use quotes for filter keys if they contain spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          // Special handling for Metal Type: use ilike for pattern matching
          if (filter.key == 'Metal Type') {
            productsQuery = productsQuery.ilike(filterKey, '%${filter.value}%');
            designerQuery = designerQuery.ilike(filterKey, '%${filter.value}%');
          } else {
            productsQuery = productsQuery.eq(filterKey, filter.value!);
            designerQuery = designerQuery.eq(filterKey, filter.value!);
          }
        }
      }

      // 3. Execute both queries in parallel
      final responses = await Future.wait([productsQuery, designerQuery]);

      final Set<String> values = {};

      // 4. Process products results
      // Use the original columnName (without quotes) to access the result
      if (responses[0] is List) {
        values.addAll(
          (responses[0] as List)
              .map((item) => item[columnName]?.toString())
              .where((item) => item != null && item.isNotEmpty)
              .cast<String>(),
        );
      }

      // 5. Process designerproducts results
      if (responses[1] is List) {
        values.addAll(
          (responses[1] as List)
              .map((item) => item[columnName]?.toString())
              .where((item) => item != null && item.isNotEmpty)
              .cast<String>(),
        );
      }

      return values.toList();
    } catch (e) {
      debugPrint(
          'Error fetching dependent distinct values for column $columnName: $e');
      return [];
    }
  }

  /// Fetches distinct category values from Category, Category1, Category2, Category3 columns
  /// based on other filters, across both 'products' and 'designerproducts' tables
  Future<List<String>> _getDependentDistinctCategoryValues(
      Map<String, String?> filters) async {
    try {
      // 1. Start queries for both tables, selecting all category columns
      var productsQuery = _supabase
          .from('products')
          .select('Category, Category1, Category2, Category3');
      var designerQuery = _supabase
          .from('designerproducts')
          .select('Category, Category1, Category2, Category3');

      // 2. Apply dependent filters to both queries (excluding Category filter itself)
      for (var filter in filters.entries) {
        if (filter.value != null && filter.value != 'All' && filter.key != 'Category') {
          // Use quotes for filter keys if they contain spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          // Special handling for Metal Type: use ilike for pattern matching
          if (filter.key == 'Metal Type') {
            productsQuery = productsQuery.ilike(filterKey, '%${filter.value}%');
            designerQuery = designerQuery.ilike(filterKey, '%${filter.value}%');
          } else {
            productsQuery = productsQuery.eq(filterKey, filter.value!);
            designerQuery = designerQuery.eq(filterKey, filter.value!);
          }
        }
      }

      // 3. Execute both queries in parallel
      final responses = await Future.wait([productsQuery, designerQuery]);

      final Set<String> values = {};

      // 4. Process products results - extract all category columns
      if (responses[0] is List) {
        for (var item in responses[0] as List) {
          if (item['Category'] != null && item['Category'].toString().isNotEmpty) {
            values.add(item['Category'].toString());
          }
          if (item['Category1'] != null && item['Category1'].toString().isNotEmpty) {
            values.add(item['Category1'].toString());
          }
          if (item['Category2'] != null && item['Category2'].toString().isNotEmpty) {
            values.add(item['Category2'].toString());
          }
          if (item['Category3'] != null && item['Category3'].toString().isNotEmpty) {
            values.add(item['Category3'].toString());
          }
        }
      }

      // 5. Process designerproducts results - extract all category columns
      if (responses[1] is List) {
        for (var item in responses[1] as List) {
          if (item['Category'] != null && item['Category'].toString().isNotEmpty) {
            values.add(item['Category'].toString());
          }
          if (item['Category1'] != null && item['Category1'].toString().isNotEmpty) {
            values.add(item['Category1'].toString());
          }
          if (item['Category2'] != null && item['Category2'].toString().isNotEmpty) {
            values.add(item['Category2'].toString());
          }
          if (item['Category3'] != null && item['Category3'].toString().isNotEmpty) {
            values.add(item['Category3'].toString());
          }
        }
      }

      return values.toList()..sort();
    } catch (e) {
      debugPrint(
          'Error fetching dependent distinct category values: $e');
      return [];
    }
  }

  /// **MODIFIED:** Renamed and changed to only fetch *independent* filters.
  Future<Map<String, List<String>>> getInitialFilterOptions() async {
    // Separate columns by their type (text vs. array)
    final textColumns = ['Product Type', 'Metal Purity', ]; //'Plain'
    // final arrayColumns = ['Studded']; // 'Studded' is an ARRAY column

    // Fetch text values using the old function
    final List<Future<List<String>>> textFutures =
        textColumns.map((columnName) => getDistinctValues(columnName)).toList();

    // Fetch array values using the NEW function
    // final List<Future<List<String>>> arrayFutures = arrayColumns
    //     .map((columnName) =>
    //         getDistinctArrayValues(columnName)) // <-- Use the new function
    //     .toList();

    // Wait for all futures to complete
    final textResults = await Future.wait(textFutures);
    // final arrayResults = await Future.wait(arrayFutures);

    // Map results back
    return {
      'Product Type': textResults[0],
      // 'Metal Purity': textResults[1],
      // 'Plain': textResults[2],
      // 'Studded': arrayResults[0], // <-- Get result from array futures
    };
  }
}
