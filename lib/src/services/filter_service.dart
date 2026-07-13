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
      // "Category" is now a text[] (unified array); unnest it like Metal Color.
      if (columnName == 'Category') {
        return await getDistinctArrayValues('Category');
      }
      // Metal Color is now unified into metal_color_arr (text[]); use the
      // array-unnesting path instead of the scalar RPC.
      if (columnName == 'Metal Color') {
        return await getDistinctArrayValues('Metal Color');
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

  /// "Category" is the unified text[] array; collect its non-blank elements.
  void _addCategoryValuesFromRow(
      Map<String, dynamic> item, Set<String> values) {
    final arr = item['Category'];
    if (arr is List) {
      for (final v in arr) {
        if (v != null && v.toString().trim().isNotEmpty) {
          values.add(v.toString());
        }
      }
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
    // Metal Color is now unified into metal_color_arr (text[]).
    if (columnName == 'Metal Color') {
      return await getDependentDistinctArrayValues('Metal Color', filters);
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
          if (filter.key == 'Jewellery Type') {
            if (filter.value == 'Plain') {
              productsQuery = productsQuery.not('Plain', 'is', 'null');
              designerQuery = designerQuery.not('Plain', 'is', 'null');
            } else if (filter.value == 'Studded') {
              productsQuery = productsQuery.not('Studded', 'is', 'null');
              designerQuery = designerQuery.not('Studded', 'is', 'null');
            }
            continue;
          }

          // Use quotes for filter keys if they contain spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          if (filter.key == 'Metal Type' && filter.value == 'AKD') {
            productsQuery = productsQuery.ilike(filterKey, 'AKD%');
            designerQuery = designerQuery.ilike(filterKey, 'AKD%');
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

  Future<List<String>> getDependentDistinctArrayValues(
      String columnName, Map<String, String?> filters) async {
    // If no specific filters are applied, just get all distinct array values.
    if (filters.values.every((v) => v == null || v == 'All')) {
      return getDistinctArrayValues(columnName);
    }

    try {
      final columnKey = columnName.contains(' ') ? '"$columnName"' : columnName;
      var productsQuery = _supabase.from('products').select(columnKey);
      var designerQuery = _supabase.from('designerproducts').select(columnKey);

      for (var filter in filters.entries) {
        if (filter.value != null && filter.value != 'All') {
          if (filter.key == 'Jewellery Type') {
            if (filter.value == 'Plain') {
              productsQuery = productsQuery.not('Plain', 'is', 'null');
              designerQuery = designerQuery.not('Plain', 'is', 'null');
            } else if (filter.value == 'Studded') {
              productsQuery = productsQuery.not('Studded', 'is', 'null');
              designerQuery = designerQuery.not('Studded', 'is', 'null');
            }
            continue;
          }

          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          if (filter.key == 'Metal Type' && filter.value == 'AKD') {
            productsQuery = productsQuery.ilike(filterKey, 'AKD%');
            designerQuery = designerQuery.ilike(filterKey, 'AKD%');
          } else {
            productsQuery = productsQuery.eq(filterKey, filter.value!);
            designerQuery = designerQuery.eq(filterKey, filter.value!);
          }
        }
      }

      final responses = await Future.wait([productsQuery, designerQuery]);
      final Set<String> values = {};

      void processResponse(dynamic response) {
        if (response is List) {
          for (var row in response) {
            final val = row[columnName];
            if (val is List) {
              for (var item in val) {
                if (item != null && item.toString().trim().isNotEmpty) {
                  values.add(item.toString().trim());
                }
              }
            } else if (val is String && val.trim().isNotEmpty) {
               // Sometimes array columns might come as strings if they are formatted weirdly
               values.add(val.trim());
            }
          }
        }
      }

      processResponse(responses[0]);
      processResponse(responses[1]);

      return values.toList()..sort();
    } catch (e) {
      debugPrint(
          'Error fetching dependent distinct array values for column $columnName: $e');
      return [];
    }
  }

  /// Fetches distinct category values from Category, Category1, Category2, Category3 columns
  /// based on other filters, across 'products', 'designerproducts', and 'manufacturerproducts' tables
  Future<List<String>> _getDependentDistinctCategoryValues(
      Map<String, String?> filters) async {
    try {
      // 1. Start queries for all three tables. "Category" is the unified
      // text[] array (Phase-3-renamed from category_arr).
      var productsQuery = _supabase.from('products').select('"Category"');
      var designerQuery =
          _supabase.from('designerproducts').select('"Category"');
      var manufacturerQuery =
          _supabase.from('manufacturerproducts').select('"Category"');

      // 2. Apply dependent filters to all three queries (excluding Category filter itself)
      for (var filter in filters.entries) {
        if (filter.value != null &&
            filter.value != 'All' &&
            filter.key != 'Category') {
          // Use quotes for filter keys if they contain spaces
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          if (filter.key == 'Metal Type' && filter.value == 'AKD') {
            productsQuery = productsQuery.ilike(filterKey, 'AKD%');
            designerQuery = designerQuery.ilike(filterKey, 'AKD%');
            manufacturerQuery = manufacturerQuery.ilike(filterKey, 'AKD%');
          } else {
            productsQuery = productsQuery.eq(filterKey, filter.value!);
            designerQuery = designerQuery.eq(filterKey, filter.value!);
            manufacturerQuery = manufacturerQuery.eq(filterKey, filter.value!);
          }
        }
      }

      // 3. Execute all three queries in parallel
      final responses =
          await Future.wait([productsQuery, designerQuery, manufacturerQuery]);

      final Set<String> values = {};

      // 4-6. Process all three tables' results (prefers category_arr, falls
      // back to legacy Category/Category1/2/3 — see _addCategoryValuesFromRow).
      for (final response in responses) {
        if (response is List) {
          for (var item in response) {
            _addCategoryValuesFromRow(item, values);
          }
        }
      }

      return values.toList()..sort();
    } catch (e) {
      debugPrint('Error fetching dependent distinct category values: $e');
      return [];
    }
  }

  /// **MODIFIED:** Renamed and changed to only fetch *independent* filters.
  Future<Map<String, List<String>>> getInitialFilterOptions() async {
    // Separate columns by their type (text vs. array)
    final textColumns = [
      'Product Type',
      'Metal Purity',
    ]; //'Plain'
    // final arrayColumns = ['Studded']; // 'Studded' is an ARRAY column

    // Fetch text values using the old function
    final List<Future<List<String>>> textFutures =
        textColumns.map((columnName) => getDistinctValues(columnName)).toList();

    // Fetch array values using the NEW function
    // final List<Future<List<String>>> arrayFutures = arrayColumns
    //     .map((columnName) =>
    //         getDistinctArrayValues(columnName)) // <-- Use the new function
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

  /// Helper to get min and max values for weight sliders by parsing strings.
  /// Pass [filters] (e.g. {'Product Type': 'Rings'}) to narrow the range to
  /// only the products matching the current filter selection, mirroring the
  /// dependent-fetch pattern used for Metal Color / Stone Cut / etc.
  Future<List<double>> getWeightRange(String columnName,
      {bool isArray = false, Map<String, String?> filters = const {}}) async {
    try {
      final hasActiveFilters =
          filters.values.any((v) => v != null && v != 'All');
      List<String> rawValues = hasActiveFilters
          ? (isArray
              ? await getDependentDistinctArrayValues(columnName, filters)
              : await getDependentDistinctValues(columnName, filters))
          : (isArray
              ? await getDistinctArrayValues(columnName)
              : await getDistinctValues(columnName));

      double minWeight = double.infinity;
      double maxWeight = double.negativeInfinity;

      for (var val in rawValues) {
        // Extract the first sequence of numbers (including decimals) from the string
        final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(val);
        if (match != null) {
          final numberStr = match.group(0);
          if (numberStr != null) {
            final number = double.tryParse(numberStr);
            if (number != null) {
              if (number < minWeight) minWeight = number;
              if (number > maxWeight) maxWeight = number;
            }
          }
        }
      }

      if (minWeight == double.infinity ||
          maxWeight == double.negativeInfinity) {
        return [0.0, 100.0]; // fallback
      }

      // Add a small buffer so the slider isn't exactly at the edges for max items
      return [minWeight, maxWeight + (maxWeight * 0.1)];
    } catch (e) {
      debugPrint('Error getting weight range for $columnName: $e');
      return [0.0, 100.0]; // fallback
    }
  }
}
