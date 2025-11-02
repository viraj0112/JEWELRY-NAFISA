// lib/src/services/jewelry_service.dart
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
            // Order designer products by creation date
            .order('created_at', ascending: false)
      ]);

      final List<dynamic> productsData = responses[0] as List<dynamic>;
      final List<dynamic> designerProductsData = responses[1] as List<dynamic>;

      final List<JewelryItem> productItems = productsData
          .map((json) => JewelryItem.fromJson(
              json as Map<String, dynamic>,
              isDesignerProduct: false)) // <-- SET FLAG
          .toList();

      final List<JewelryItem> designerProductItems = designerProductsData
          .map((json) => JewelryItem.fromJson(
              json as Map<String, dynamic>,
              isDesignerProduct: true)) // <-- SET FLAG
          .toList();

      // Combine and parse
      final allProducts = [...productItems, ...designerProductItems];

      // Shuffle for variety
      allProducts.shuffle();

      return allProducts;
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  // ... (existing searchProducts method)
  Future<List<JewelryItem>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    // Prepare the query term for ilike and array contains
    final String ilikeQuery = '%$query%';
    final String arrayQuery = '{${query.toLowerCase()}}'; // For .cs operator

    try {
      // Query 'products' table
      final productsResponse = await _supabaseClient
          .from('products')
          .select()
          .or(
            // Case-insensitive text search on relevant columns
            '"Product Title".ilike.$ilikeQuery,'
            'Description.ilike.$ilikeQuery,'
            '"Collection Name".ilike.$ilikeQuery,'
            '"Product Type".ilike.$ilikeQuery,'
            'Category.ilike.$ilikeQuery,'
            '"Sub Category".ilike.$ilikeQuery,'
            '"Metal Type".ilike.$ilikeQuery,'
            '"Metal Color".ilike.$ilikeQuery,'
            // Array contains search (case-sensitive by default, use lowercase)
            '"Product Tags".cs.$arrayQuery,'
            '"Stone Type".cs.$arrayQuery,'
            '"Stone Color".cs.$arrayQuery',
          )
          .limit(50); // Limit results for performance

      // Query 'designerproducts' table
      final designerResponse = await _supabaseClient
          .from('designerproducts')
          .select()
          .or(
            // FIX: Columns must be quoted and capitalized
            '"Product Title".ilike.$ilikeQuery,' // Assumes 'title' in designerproducts
            'Description.ilike.$ilikeQuery,'
            '"Collection Name".ilike.$ilikeQuery,'
            '"Product Type".ilike.$ilikeQuery,'
            'Category.ilike.$ilikeQuery,'
            '"Sub Category".ilike.$ilikeQuery,'
            '"Metal Type".ilike.$ilikeQuery,'
            '"Metal Color".ilike.$ilikeQuery,'
            // Array columns
            '"Product Tags".cs.$arrayQuery,'
            '"Stone Type".cs.$arrayQuery,'
            '"Stone Color".cs.$arrayQuery',
          )
          .limit(50); // Limit results for performance

      // Combine results
      final List<dynamic> combinedData = [
        ...productsResponse,
        ...designerResponse,
      ];

      // Remove duplicates
      final uniqueResults = {
        for (var json in combinedData)
          (json as Map<String, dynamic>)['id'].toString(): json
      }.values.toList();

      if (uniqueResults.isNotEmpty) {
        // Need to check which table it came from to set isDesignerProduct
        return uniqueResults.map((json) {
          final map = json as Map<String, dynamic>;
          // Simple check: if designer_id exists, it's a designer product
          final isDesigner = map.containsKey('designer_id');
          return JewelryItem.fromJson(map, isDesignerProduct: isDesigner);
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }

  // --- NEW TRENDING METHOD ---
  Future<List<JewelryItem>> getTrendingProducts({int limit = 20}) async {
    try {
      // Call the new SQL function created in step 1
      final response = await _supabaseClient.rpc(
        'get_trending_products_v2', // Name of the SQL function
        params: {'limit_count': limit}, // Parameter for the function
      );

      if (response is List) {
        // The RPC returns JSON, so we parse it directly
        return response
            .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>,
                isDesignerProduct: true)) // Assuming trending are designer
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching trending products: $e');
      return []; // Return empty list on error
    }
  }
  // --- END NEW TRENDING METHOD ---

  Future<List<JewelryItem>> fetchSimilarItems({
    required String currentItemId,
    required bool isDesigner, // Need to know which table to query
    String? productType,
    String? category,
    String? subCategory,
    int limit = 10,
  }) async {
    // Check if all relevant fields are null or empty
    if ((productType == null || productType.isEmpty) &&
        (category == null || category.isEmpty) &&
        (subCategory == null || subCategory.isEmpty)) {
      return [];
    }

    try {
      final response = await _supabaseClient.rpc(
        'get_similar_products', // Same function name
        params: {
          // Pass new parameters to the SQL function
          'p_product_type': productType,
          'p_category': category,
          'p_sub_category': subCategory,
          'p_limit': limit,
          'p_exclude_id': currentItemId,
          // 'p_is_designer': isDesigner, // <-- FIX: REMOVED THIS PARAMETER
        },
      ) as List<dynamic>;

      return response
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>,
              isDesignerProduct:
                  isDesigner)) // Pass flag based on original item
          .toList();
    } catch (e) {
      debugPrint('Error fetching similar products via RPC: $e');
      return [];
    }
  }

  Future<JewelryItem?> getJewelryItem(String id) async {
    try {
      // Try fetching from 'designerproducts' first (since UUIDs are common)
      final designerResponse = await _supabaseClient
          .from('designerproducts')
          .select()
          .eq('id', id)
          .maybeSingle(); // Use maybeSingle

      if (designerResponse != null) {
        return JewelryItem.fromJson(designerResponse, isDesignerProduct: true);
      }

      // If not found, try fetching from 'products' (assuming integer ID)
      final intId = int.tryParse(id);
      if (intId != null) {
        final productResponse = await _supabaseClient
            .from('products')
            .select()
            .eq('id', intId)
            .maybeSingle(); // Use maybeSingle for potentially null result

        if (productResponse != null) {
          return JewelryItem.fromJson(productResponse, isDesignerProduct: false);
        }
      }

      debugPrint('JewelryItem with ID $id not found in either table.');
      return null;
    } catch (e) {
      debugPrint('Error fetching single product (ID: $id): $e');
      return null;
    }
  }

  // --- NEW METHOD ---
  Future<List<String>> getInitialSearchIdeas({int limit = 15}) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_initial_search_ideas',
        params: {'limit_count': limit},
      ) as List<dynamic>;

      // The RPC returns a list of text, so cast directly
      return response.map((item) => item.toString()).toList();
    } catch (e) {
      debugPrint('Error fetching search ideas: $e');
      // Return a fallback list on error
      return ['Rings', 'Necklaces', 'Earrings', 'Gold', 'Diamond'];
    }
  }
  // --- END NEW METHOD ---
}