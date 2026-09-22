import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../utils/array_value_utils.dart';

class FilterService {
  final _supabase = Supabase.instance.client;
  static const _pageSize = 1000;

  static const _placeholderValues = {
    '',
    'null',
    'none',
    'n/a',
    'na',
    'not applicable',
    'no stone',
    'no stones',
  };

  static const _descriptorWords = {
    'antique',
    'asymmetrical',
    'bold',
    'bridal',
    'bright',
    'classic',
    'celestial',
    'contemporary',
    'delicate',
    'dual',
    'elegant',
    'festive',
    'floral',
    'geometric',
    'glamorous',
    'intricate',
    'luxurious',
    'modern',
    'minimal',
    'ornate',
    'romantic',
    'royal',
    'simple',
    'sleek',
    'sparkling',
    'statement',
    'traditional',
    'unique',
    'vintage',
    'white',
    'black',
    'blue',
    'green',
    'pink',
    'purple',
    'red',
    'yellow',
    'rose',
    'multicolor',
    'two-tone',
    'openwork',
  };

  static const _nonDescriptorWords = {
    'bangle',
    'bangles',
    'bracelet',
    'bracelets',
    'brooch',
    'chain',
    'chains',
    'charm',
    'earring',
    'earrings',
    'jewelry',
    'jewellery',
    'necklace',
    'necklaces',
    'pendant',
    'pendants',
    'ring',
    'rings',
    'set',
    'stone',
    'stones',
    'diamond',
    'diamonds',
    'cz',
    'moissanite',
    'sapphire',
    'onyx',
    'gold',
    'silver',
    'platinum',
    'gift',
    'gifts',
    'wear',
    'wedding',
    'women',
    'woman',
    'men',
    'man',
    'design',
    'designer',
    'fashion',
    'enamel',
    'bamboo',
    'american',
  };

  Future<List<String>> getDistinctArrayValues(String columnName) async {
    try {
      final values = <String>{};
      for (final table in [
        'products',
        'designerproducts',
        'manufacturerproducts'
      ]) {
        final columnKey =
            columnName.contains(' ') ? '"$columnName"' : columnName;
        final rows = await _supabase.from(table).select(columnKey).limit(10000);
        for (final row in rows) {
          for (final value
              in ArrayValueUtils.parse(row[columnName]) ?? const []) {
            if (!_placeholderValues.contains(value.toLowerCase())) {
              values.add(value);
            }
          }
        }
      }
      return values.toList()..sort();
    } catch (e) {
      debugPrint(
          'Error fetching distinct array values for column $columnName: $e');
      return [];
    }
  }

  Future<List<String>> getFeaturedTags(Map<String, dynamic> filters) async {
    final tags = await getDependentDistinctArrayValues('Product Tags', filters);
    final unique = <String, String>{};
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final words = normalized
          .split(RegExp(r'[^a-z0-9-]+'))
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty ||
          words.any(_nonDescriptorWords.contains) ||
          !words.any(_descriptorWords.contains)) {
        continue;
      }
      unique.putIfAbsent(normalized, () => tag.trim());
    }
    return unique.values.toList()..sort();
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
      if (columnName == 'Sub Category') {
        final values = <String>{};
        for (final table in [
          'products',
          'designerproducts',
          'manufacturerproducts'
        ]) {
          final rows =
              await _supabase.from(table).select('"Sub Category"').limit(10000);
          for (final row in rows) {
            for (final value
                in ArrayValueUtils.parse(row['Sub Category']) ?? const []) {
              if (!_placeholderValues.contains(value.toLowerCase())) {
                values.add(value);
              }
            }
          }
        }
        return values.toList()..sort();
      }

      // Use the RPC that does SELECT DISTINCT across all 3 tables in SQL.
      // This bypasses PostgREST's row limit (default 1000 rows/request)
      // which was causing only 1–3 Product Types to be returned despite
      // 9+ types existing across 9 000+ rows.
      final response = await _supabase.rpc(
        'get_all_distinct_product_values',
        params: {'p_column': columnName},
      );

      if (response is List) {
        final values = response
            .map((item) => item?.toString().trim())
            .where((v) => v != null && v.isNotEmpty)
            .cast<String>()
            .toList()
          ..sort();
        debugPrint(
            '[FilterService] getDistinctValues("$columnName") => $values');
        return values;
      }
      return [];
    } catch (e) {
      debugPrint(
          '[FilterService] ERROR getDistinctValues("$columnName") RPC failed: $e. '
          'Falling back to row-fetch.');
      // ---- FALLBACK: row-fetch (slow but works without the RPC) ----
      try {
        final columnKey =
            columnName.contains(' ') ? '"$columnName"' : columnName;
        final values = <String>{};

        try {
          final res =
              await _supabase.from('products').select(columnKey).limit(10000);
          for (var row in res) {
            final val = row[columnName];
            if (val != null && val.toString().trim().isNotEmpty) {
              values.add(val.toString().trim());
            }
          }
        } catch (_) {}
        for (final table in ['designerproducts', 'manufacturerproducts']) {
          try {
            final res =
                await _supabase.from(table).select(columnKey).limit(10000);
            for (var row in res) {
              final val = row[columnName];
              if (val != null && val.toString().trim().isNotEmpty) {
                values.add(val.toString().trim());
              }
            }
          } catch (_) {}
        }
        return values.toList()..sort();
      } catch (e2) {
        debugPrint('Fallback also failed for $columnName: $e2');
        return [];
      }
    }
  }

  /// "Category" is the unified text[] array; collect its non-blank elements.
  void _addCategoryValuesFromRow(
      Map<String, dynamic> item, Set<String> values) {
    values.addAll(ArrayValueUtils.parse(item['Category']) ?? const []);
  }

  Future<List<dynamic>> _fetchPaged(
    String table,
    String columns,
    dynamic Function(dynamic) applyFilters,
  ) async {
    final rows = <dynamic>[];
    for (var offset = 0;; offset += _pageSize) {
      dynamic query = _supabase.from(table).select(columns);
      query = applyFilters(query);
      final page =
          await query.range(offset, offset + _pageSize - 1) as List<dynamic>;
      rows.addAll(page);
      if (page.length < _pageSize) break;
    }
    return rows;
  }

  Future<List<String>> _getDependentDistinctPagedValues(
      String columnName, Map<String, dynamic> filters) async {
    dynamic applyFilters(dynamic query) {
      for (final filter in filters.entries) {
        if (filter.value == null ||
            filter.value == 'All' ||
            (filter.value is List && (filter.value as List).isEmpty)) {
          continue;
        }
        if (filter.key == 'Jewellery Type') {
          query = query.not(
              filter.value == 'Plain' ? 'Plain' : 'Studded', 'is', 'null');
          continue;
        }
        final filterKey =
            filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
        if (filter.value is List) {
          query = query.overlaps(filterKey, filter.value as List);
        } else if (filter.key == 'Metal Type') {
          final metal = filter.value.toString().trim();
          query = query.ilike(filterKey, metal == 'AKD' ? 'AKD%' : '%$metal%');
        } else {
          query = query.eq(filterKey, filter.value);
        }
      }
      return query;
    }

    final responses = await Future.wait([
      _fetchPaged('products', '"$columnName"', applyFilters),
      _fetchPaged('designerproducts', '"$columnName"', applyFilters),
      _fetchPaged('manufacturerproducts', '"$columnName"', applyFilters),
    ]);
    final values = <String>{};
    for (final response in responses) {
      for (final row in response) {
        for (final value
            in ArrayValueUtils.parse(row[columnName]) ?? const []) {
          if (!_placeholderValues.contains(value.toLowerCase())) {
            values.add(value);
          }
        }
      }
    }
    return values.toList()..sort();
  }

  /// **FIXED:** Fetches distinct values for a column based on other filters.
  /// Now queries both 'products' and 'designerproducts' tables.
  /// Special handling for Category column to aggregate Category, Category1, Category2, Category3
  Future<List<String>> getDependentDistinctValues(
      String columnName, Map<String, dynamic> filters) async {
    // Check if all filters are 'All' or null, or empty lists
    if (filters.values
        .every((v) => v == null || v == 'All' || (v is List && v.isEmpty))) {
      // If no specific filters are applied, just get all distinct values.
      return getDistinctValues(columnName);
    }

    // Special handling for Category to aggregate all category columns
    if (columnName == 'Category') {
      return await _getDependentDistinctCategoryValues(filters);
    }
    if (columnName == 'Sub Category') {
      return await _getDependentDistinctPagedValues(columnName, filters);
    }
    if (columnName == 'Product Type') {
      return await _getDependentDistinctPagedValues(columnName, filters);
    }
    // Metal Color is now unified into metal_color_arr (text[]).
    if (columnName == 'Metal Color') {
      return await getDependentDistinctArrayValues('Metal Color', filters);
    }

    try {
      final columnKey = columnName.contains(' ') ? '"$columnName"' : columnName;

      var productsQuery = _supabase.from('products').select(columnKey);
      var designerQuery = _supabase.from('designerproducts').select(columnKey);
      var manufacturerQuery =
          _supabase.from('manufacturerproducts').select(columnKey);

      // 2. Apply dependent filters to all queries
      for (var filter in filters.entries) {
        if (filter.value != null &&
            filter.value != 'All' &&
            !(filter.value is List && (filter.value as List).isEmpty)) {
          if (filter.key == 'Jewellery Type') {
            final column = filter.value == 'Plain' ? 'Plain' : 'Studded';
            productsQuery = productsQuery.not(column, 'is', 'null');
            designerQuery = designerQuery.not(column, 'is', 'null');
            manufacturerQuery = manufacturerQuery.not(column, 'is', 'null');
            continue;
          }
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;

          if (filter.value is List) {
            productsQuery =
                productsQuery.overlaps(filterKey, filter.value as List);
            designerQuery =
                designerQuery.overlaps(filterKey, filter.value as List);
            manufacturerQuery =
                manufacturerQuery.overlaps(filterKey, filter.value as List);
          } else {
            if (filter.key == 'Metal Type') {
              final metal = filter.value.toString().trim();
              productsQuery = productsQuery.ilike(filterKey, '%$metal%');
              designerQuery = designerQuery.ilike(filterKey, '%$metal%');
              manufacturerQuery =
                  manufacturerQuery.ilike(filterKey, '%$metal%');
            } else {
              productsQuery = productsQuery.eq(filterKey, filter.value!);
              designerQuery = designerQuery.eq(filterKey, filter.value!);
              manufacturerQuery =
                  manufacturerQuery.eq(filterKey, filter.value!);
            }
          }
        }
      }

      // 3. Execute all queries in parallel
      final responses = await Future.wait([
        productsQuery,
        designerQuery,
        manufacturerQuery,
      ]);

      final values = <String>{};

      for (var response in responses) {
        for (final item in response) {
          for (final value
              in ArrayValueUtils.parse(item[columnName]) ?? const []) {
            if (!_placeholderValues.contains(value.toLowerCase())) {
              values.add(value);
            }
          }
        }
      }

      return values.toList();
    } catch (e) {
      debugPrint(
          'Error fetching dependent distinct values for column $columnName: $e');
      return [];
    }
  }

  Future<List<String>> getDependentDistinctArrayValues(
      String columnName, Map<String, dynamic> filters) async {
    // If no specific filters are applied, just get all distinct array values.
    if (filters.values
        .every((v) => v == null || v == 'All' || (v is List && v.isEmpty))) {
      return getDistinctArrayValues(columnName);
    }

    try {
      final columnKey = columnName.contains(' ') ? '"$columnName"' : columnName;
      var productsQuery = _supabase.from('products').select(columnKey);
      var designerQuery = _supabase.from('designerproducts').select(columnKey);
      var manufacturerQuery =
          _supabase.from('manufacturerproducts').select(columnKey);

      // 1. Unnest arrays logic in Dart
      void addValuesFromRow(Map<String, dynamic> item, Set<String> values) {
        final val = item[columnName];
        for (final value in ArrayValueUtils.parse(val) ?? const []) {
          if (!_placeholderValues.contains(value.toLowerCase())) {
            values.add(value);
          }
        }
      }

      for (var filter in filters.entries) {
        if (filter.value != null &&
            filter.value != 'All' &&
            !(filter.value is List && (filter.value as List).isEmpty)) {
          if (filter.key == 'Jewellery Type') {
            final column = filter.value == 'Plain' ? 'Plain' : 'Studded';
            productsQuery = productsQuery.not(column, 'is', 'null');
            designerQuery = designerQuery.not(column, 'is', 'null');
            manufacturerQuery = manufacturerQuery.not(column, 'is', 'null');
            continue;
          }
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;

          if (filter.value is List) {
            productsQuery =
                productsQuery.overlaps(filterKey, filter.value as List);
            designerQuery =
                designerQuery.overlaps(filterKey, filter.value as List);
            manufacturerQuery =
                manufacturerQuery.overlaps(filterKey, filter.value as List);
          } else {
            if (filter.key == 'Metal Type') {
              final metal = filter.value.toString().trim();
              productsQuery = productsQuery.ilike(filterKey, '%$metal%');
              designerQuery = designerQuery.ilike(filterKey, '%$metal%');
              manufacturerQuery =
                  manufacturerQuery.ilike(filterKey, '%$metal%');
            } else {
              productsQuery = productsQuery.eq(filterKey, filter.value!);
              designerQuery = designerQuery.eq(filterKey, filter.value!);
              manufacturerQuery =
                  manufacturerQuery.eq(filterKey, filter.value!);
            }
          }
        }
      }

      final responses = await Future.wait([
        productsQuery.limit(5000),
        designerQuery.limit(5000),
        manufacturerQuery.limit(5000),
      ]);

      final values = <String>{};
      for (var response in responses) {
        for (var row in response) {
          addValuesFromRow(row, values);
        }
      }

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
      Map<String, dynamic> filters) async {
    try {
      dynamic applyFilters(dynamic query) {
        for (final filter in filters.entries) {
          if (filter.value == null ||
              filter.value == 'All' ||
              (filter.value is List && (filter.value as List).isEmpty) ||
              filter.key == 'Category') {
            continue;
          }
          if (filter.key == 'Jewellery Type') {
            query = query.not(
                filter.value == 'Plain' ? 'Plain' : 'Studded', 'is', 'null');
            continue;
          }
          final filterKey =
              filter.key.contains(' ') ? '"${filter.key}"' : filter.key;
          if (filter.value is List) {
            query = query.overlaps(filterKey, filter.value as List);
          } else if (filter.key == 'Metal Type') {
            final metal = filter.value.toString().trim();
            query =
                query.ilike(filterKey, metal == 'AKD' ? 'AKD%' : '%$metal%');
          } else {
            query = query.eq(filterKey, filter.value);
          }
        }
        return query;
      }

      final responses = await Future.wait([
        _fetchPaged('products', '"Category"', applyFilters),
        _fetchPaged('designerproducts', '"Category"', applyFilters),
        _fetchPaged('manufacturerproducts', '"Category"', applyFilters),
      ]);

      final Set<String> values = {};

      // 4-6. Process all three tables' results
      for (final response in responses) {
        for (final item in response) {
          _addCategoryValuesFromRow(item, values);
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
      {bool isArray = false, Map<String, dynamic> filters = const {}}) async {
    try {
      final hasActiveFilters = filters.values
          .any((v) => v != null && v != 'All' && !(v is List && v.isEmpty));
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
