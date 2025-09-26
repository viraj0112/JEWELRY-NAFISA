
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/jewelry_item.dart';

class JewelryService {
  final SupabaseClient _supabaseClient;

  JewelryService(this._supabaseClient);

  Future<List<JewelryItem>> getProducts({int limit = 50, int offset = 0}) async {
    try {
      final response = await _supabaseClient
          .from('products')
          .select()
          .limit(limit)
          .range(offset, offset + limit - 1); 

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  Future<List<JewelryItem>> fetchSimilarItems({
    required String currentItemId,
    String? category,
    int limit = 10,
  }) async {
    try {
      var query = _supabaseClient
          .from('products')
          .select()
          .not('id', 'eq', currentItemId); 

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      final response = await query.limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching similar products: $e');
      return [];
    }
  }

  Future<JewelryItem?> getJewelryItem(String id) async {
    try {
      final response = await _supabaseClient
          .from('products')
          .select()
          .eq('id', id)
          .single();
      return JewelryItem.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching single product: $e');
      return null;
    }
  }
}