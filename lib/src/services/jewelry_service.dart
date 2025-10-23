import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/jewelry_item.dart';

class JewelryService {
  final SupabaseClient _supabaseClient;

  JewelryService(this._supabaseClient);

  Future<List<JewelryItem>> getProducts(
      {int limit = 50, int offset = 0}) async {
    try {
      final responses = await Future.wait([
        _supabaseClient
            .from('products')
            .select()
            .limit(limit)
            .range(offset, offset + limit - 1),
        _supabaseClient
            .from('designerproducts')
            .select()
            .limit(limit)
            .range(offset, offset + limit - 1)
      ]);

      final List<dynamic> productsData = responses[0] as List<dynamic>;
      final List<dynamic> designerProductsData = responses[1] as List<dynamic>;

      final allProducts = [...productsData, ...designerProductsData];

      return allProducts
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
      var query = _supabaseClient.from('products').select();

      final isIntegerId = int.tryParse(currentItemId) != null;
      if (isIntegerId) {
        query = query.not('id', 'eq', currentItemId);
      }

      if (category != null && category.isNotEmpty) {
        query = query.eq('Category', category);
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
      // 1. Try to fetch from 'products' table.
      // We'll respect the original logic of trying to parse an int.
      final intId = int.tryParse(id);
      if (intId != null) {
        final productResponse = await _supabaseClient
            .from('products')
            .select()
            .eq('id', intId) // Use the integer ID
            .limit(1); // Use limit(1) instead of single()

        if (productResponse.isNotEmpty) {
          // Found in 'products'
          return JewelryItem.fromJson(productResponse.first);
        }
      }

      // 2. If not found (or if ID wasn't an int), try 'designerproducts'.
      // We'll try matching the original string ID.
      final designerResponse = await _supabaseClient
          .from('designerproducts')
          .select()
          .eq('id', id) // Use the original string ID
          .limit(1); // Use limit(1) instead of single()

      if (designerResponse.isNotEmpty) {
        // Found in 'designerproducts'
        return JewelryItem.fromJson(designerResponse.first);
      }

      // 3. If not found in either table
      debugPrint(
          'getJewelryItem: Product with ID $id not found in products or designerproducts.');
      return null;
    } catch (e) {
      // This will catch any other unexpected errors
      debugPrint('Error fetching single product (ID: $id): $e');
      return null;
    }
  }
}
