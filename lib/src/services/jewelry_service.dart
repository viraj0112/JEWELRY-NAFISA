// src/services/jewelry_service.dart
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

      // Combine and parse
      final allProducts = [...productsData, ...designerProductsData];

      // Shuffle for variety
      allProducts.shuffle();

      return allProducts
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
          .toList();
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
            // Case-insensitive text search on relevant columns
            '"Product Title".ilike.$ilikeQuery,'
            'description.ilike.$ilikeQuery,'
            'Category.ilike.$ilikeQuery,'
            '"Sub Category".ilike.$ilikeQuery,'
            '"Metal Type".ilike.$ilikeQuery,' // Assuming Metal Type exists
            '"Metal Color".ilike.$ilikeQuery,' // Assuming Metal Color exists
            // Array contains search (case-sensitive by default, use lowercase)
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
        return uniqueResults
            .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
            .toList();
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
            .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
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
    String? productType,
    String? category,
    int limit = 10,
  }) async {
    // ... (existing code)
    try {
      // Prefer designerproducts if category exists, fallback to products
      final tableName = (category != null && category.isNotEmpty)
          ? 'designerproducts'
          : 'products';

      var query = _supabaseClient.from(tableName).select();

      // Exclude the current item ID
      // Check if ID is likely int (products) or bigint (designerproducts)
      final isIntegerId = int.tryParse(currentItemId) != null;
      if (isIntegerId && tableName == 'products') {
        query = query.not('id', 'eq', currentItemId);
      } else if (!isIntegerId && tableName == 'designerproducts') {
        // Assuming designerproducts ID might not always be purely numeric string
        query = query.not('id', 'eq', currentItemId);
      } // Add more specific logic if ID formats differ significantly

      // Filter by Category or Product Type if provided
      if (category != null && category.isNotEmpty) {
        // Use 'Sub Category' for designerproducts, 'Category' for products
        final categoryColumn =
            tableName == 'designerproducts' ? '"Sub Category"' : 'Category';
        query = query.eq(categoryColumn, category);
      } else if (productType != null && productType.isNotEmpty) {
        // Use 'Category' for designerproducts, 'Product Type' for products
        final productTypeColumn = tableName == 'designerproducts'
            ? 'Category'
            : '"Product Type"'; // Ensure quoting for space
        query = query.eq(productTypeColumn, productType);
      }

      final response = await query.limit(limit);

      return response
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching similar products: $e');
      return [];
    }
  }

  Future<JewelryItem?> getJewelryItem(String id) async {
    // ... (existing code)
     try {
      // Try fetching from 'products' (assuming integer ID)
      final intId = int.tryParse(id);
      if (intId != null) {
        final productResponse = await _supabaseClient
            .from('products')
            .select()
            .eq('id', intId)
            .maybeSingle(); // Use maybeSingle for potentially null result

        if (productResponse != null) {
          return JewelryItem.fromJson(productResponse);
        }
      }

      final designerResponse = await _supabaseClient
          .from('designerproducts')
          .select()
          .eq('id', id)
          .maybeSingle(); // Use maybeSingle

      if (designerResponse != null) {
        return JewelryItem.fromJson(designerResponse);
      }

      debugPrint('JewelryItem with ID $id not found.');
      return null;
    } catch (e) {
      debugPrint('Error fetching single product (ID: $id): $e');
      return null;
    }
  }
}