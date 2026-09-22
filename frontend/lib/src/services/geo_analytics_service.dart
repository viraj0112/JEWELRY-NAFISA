import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/geo_analytics_widget.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Shared Geo Analytics Data Service
/// ─────────────────────────────────────────────────────────────────────────────
/// Fetches engagement data (views, likes, shares, saves) from Supabase and
/// aggregates it by country, state, and pincode.
///
/// Used by Admin, Designer, and B2B/Manufacturer analytics screens.
/// ─────────────────────────────────────────────────────────────────────────────

class GeoAnalyticsService {
  static final _supabase = Supabase.instance.client;

  /// Fetch geo analytics for a specific list of product IDs.
  /// If [productIds] is null, fetch platform-wide data (admin mode).
  static Future<GeoAnalyticsData> fetchGeoData({
    List<String>? productIds,
  }) async {
    try {
      List viewsRows, likesRows, sharesRows, savesRows;

      if (productIds == null || productIds.isEmpty) {
        // Admin mode — fetch everything
        final results = await Future.wait([
          _supabase
              .from('views')
              .select('item_id, item_table, country, state, pincode'),
          _supabase
              .from('likes')
              .select('item_id, item_table, country, state, pincode'),
          _supabase.from('shares').select('item_id, item_table'),
          _supabase
              .from('saves')
              .select('item_id, item_table, country, state, pincode'),
        ]);
        viewsRows = results[0] as List;
        likesRows = results[1] as List;
        sharesRows = results[2] as List;
        savesRows = results[3] as List;
      } else {
        // Scoped mode — filter by product IDs
        final results = await Future.wait([
          _supabase
              .from('views')
              .select('item_id, item_table, country, state, pincode')
              .inFilter('item_id', productIds),
          _supabase
              .from('likes')
              .select('item_id, item_table, country, state, pincode')
              .inFilter('item_id', productIds),
          _supabase
              .from('shares')
              .select('item_id, item_table')
              .inFilter('item_id', productIds),
          _supabase
              .from('saves')
              .select('item_id, item_table, country, state, pincode')
              .inFilter('item_id', productIds),
        ]);
        viewsRows = results[0] as List;
        likesRows = results[1] as List;
        sharesRows = results[2] as List;
        savesRows = results[3] as List;
      }

      // ── Aggregate by geo location ─────────────────────────────────────────
      final byCountry = <String, Map<String, int>>{};
      final byState = <String, Map<String, int>>{};
      final byPincode = <String, Map<String, int>>{};
      // ── Aggregate by product ──────────────────────────────────────────────
      final byProduct = <String, Map<String, int>>{};
      final itemTables = <String, String>{};
      // ── Aggregate by state + product ("most engaged product per region") ──
      final byStateProduct = <String, Map<String, Map<String, int>>>{};

      void aggregate(List rows, String metricKey, {bool hasGeo = true}) {
        for (final row in rows) {
          // per-product tracking
          final id = (row['item_id'] as String?)?.trim() ?? '';
          final table = (row['item_table'] as String?)?.trim() ?? '';
          if (id.isNotEmpty) {
            byProduct.putIfAbsent(
                id,
                () => <String, int>{
                      'views': 0,
                      'likes': 0,
                      'shares': 0,
                      'saves': 0
                    });
            byProduct[id]![metricKey] = (byProduct[id]![metricKey] ?? 0) + 1;
            if (table.isNotEmpty) itemTables[id] = table;
          }

          if (!hasGeo) continue;
          final country = (row['country'] as String?)?.trim() ?? '';
          final state = (row['state'] as String?)?.trim() ?? '';
          final pincode = (row['pincode'] as String?)?.trim() ?? '';

          if (state.isNotEmpty && id.isNotEmpty) {
            final stateMap = byStateProduct.putIfAbsent(state, () => {});
            final productMetrics = stateMap.putIfAbsent(
                id,
                () => <String, int>{
                      'views': 0,
                      'likes': 0,
                      'shares': 0,
                      'saves': 0
                    });
            productMetrics[metricKey] = (productMetrics[metricKey] ?? 0) + 1;
          }

          if (country.isNotEmpty) {
            byCountry.putIfAbsent(
                country,
                () => <String, int>{
                      'views': 0,
                      'likes': 0,
                      'shares': 0,
                      'saves': 0
                    });
            byCountry[country]![metricKey] =
                (byCountry[country]![metricKey] ?? 0) + 1;
          }
          if (state.isNotEmpty) {
            byState.putIfAbsent(
                state,
                () => <String, int>{
                      'views': 0,
                      'likes': 0,
                      'shares': 0,
                      'saves': 0
                    });
            byState[state]![metricKey] = (byState[state]![metricKey] ?? 0) + 1;
          }
          if (pincode.isNotEmpty) {
            byPincode.putIfAbsent(
                pincode,
                () => <String, int>{
                      'views': 0,
                      'likes': 0,
                      'shares': 0,
                      'saves': 0
                    });
            byPincode[pincode]![metricKey] =
                (byPincode[pincode]![metricKey] ?? 0) + 1;
          }
        }
      }

      aggregate(viewsRows, 'views');
      aggregate(likesRows, 'likes');
      aggregate(sharesRows, 'shares', hasGeo: false);
      aggregate(savesRows, 'saves');

      return GeoAnalyticsData(
        totalViews: viewsRows.length,
        totalLikes: likesRows.length,
        totalShares: sharesRows.length,
        totalSaves: savesRows.length,
        byCountry: byCountry,
        byState: byState,
        byPincode: byPincode,
        byProduct: byProduct,
        itemTables: itemTables,
        byStateProduct: byStateProduct,
      );
    } catch (e) {
      debugPrint('Error fetching geo analytics: $e');
      return GeoAnalyticsData.empty;
    }
  }

  /// Get product IDs for a designer user.
  static Future<List<String>> getDesignerProductIds(String userId) async {
    try {
      var products = await _supabase
          .from('designerproducts')
          .select('id')
          .eq('user_id', userId);

      if ((products as List).isEmpty) {
        products =
            await _supabase.from('products').select('id').eq('user_id', userId);
      }

      return (products as List).map((e) => e['id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching designer product IDs: $e');
      return [];
    }
  }

  /// Get product IDs for a B2B/manufacturer user.
  static Future<List<String>> getManufacturerProductIds(String userId) async {
    try {
      var products = await _supabase
          .from('manufacturerproducts')
          .select('id')
          .eq('user_id', userId);

      if ((products as List).isEmpty) {
        products = await _supabase
            .from('designerproducts')
            .select('id')
            .eq('user_id', userId);
      }

      if ((products as List).isEmpty) {
        products =
            await _supabase.from('products').select('id').eq('user_id', userId);
      }

      return (products as List).map((e) => e['id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching manufacturer product IDs: $e');
      return [];
    }
  }
}
