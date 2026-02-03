import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/jewelry_item.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class JewelryService {
  final SupabaseClient _supabaseClient;
  
  static const String _baseUrl = 'https://dagina-ai-image-search.hf.space/search';
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
          .map((json) => JewelryItem.fromJson(json as Map<String, dynamic>)) // <-- SET FLAG
          .toList();

      final List<JewelryItem> designerProductItems = designerProductsData
          .map((json) {
            final map = json as Map<String, dynamic>;
            map['is_designer_product'] = true;
            return JewelryItem.fromJson(map);
          }) // <-- SET FLAG
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

  Future<List<JewelryItem>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    try {
      // --- OPTIMIZED: Use Full Text Search RPC ---
      final response = await _supabaseClient.rpc(
        'search_products_fts',
        params: {
          'search_query': query,
          'limit_count': 50,
        },
      );

      if (response is List) {
        return response.map((json) {
          final map = json as Map<String, dynamic>;
          // The RPC returns 'is_designer_product' directly
          return JewelryItem.fromJson(map);
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching products: $e');
      // Fallback to old method if RPC fails (optional, but good for safety)
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
            .map((json) {
              final map = json as Map<String, dynamic>;
              map['is_designer_product'] = true;
              return JewelryItem.fromJson(map);
            }) // Assuming trending are designer
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching trending products: $e');
      return []; // Return empty list on error
    }
  }
  // --- END NEW TRENDING METHOD ---

  static Future<List<dynamic>> searchByImage(
    Uint8List imageBytes, {
    SupabaseClient? supabaseClient,
  }) async {
    // Upload to Supabase bucket if client is provided
    if (supabaseClient != null) {
      try {
        // Get the authenticated user
        final user = supabaseClient.auth.currentUser;
        if (user != null) {
          // Generate a unique filename with user ID
          final userId = user.id;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'private/search_queries/$userId/$timestamp.jpg';

          await supabaseClient.storage.from('search-images').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          debugPrint('Image saved to Supabase: $fileName');
        } else {
          debugPrint('User not authenticated, skipping image upload');
        }
      } catch (e) {
        debugPrint('Error uploading image to Supabase: $e');
        // Continue with search even if upload fails
      }
    }

    // Proceed with image search
    final uri = Uri.parse(_baseUrl);

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file', // MUST match FastAPI UploadFile param
        imageBytes,
        filename: 'query.jpg',
        contentType: http.MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        "FastAPI error ${streamedResponse.statusCode}: $responseBody",
      );
    }

    return jsonDecode(responseBody) as List<dynamic>;
  }


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
          'p_is_designer': isDesigner,
        },
      ) as List<dynamic>;

      return response
          .map((json) {
            final map = json as Map<String, dynamic>;
            // The SQL function already returns is_designer_product, so use it if available
            if (!map.containsKey('is_designer_product')) {
              map['is_designer_product'] = isDesigner;
            }
            return JewelryItem.fromJson(map);
          })
          .toList();
    } catch (e) {
      debugPrint('Error fetching similar products via RPC: $e');
      return [];
    }
  }

  Future<JewelryItem?> getJewelryItem(String id, {bool? isDesignerProduct}) async {
    try {
      final intId = int.tryParse(id);
      
      // If we know it's a designer product, query designerproducts table directly
      if (isDesignerProduct == true) {
        final designerResponse = await _supabaseClient
            .from('designerproducts')
            .select()
            .eq('id', intId ?? id)
            .maybeSingle();

        if (designerResponse != null) {
          designerResponse['is_designer_product'] = true;
          return JewelryItem.fromJson(designerResponse);
        }
        debugPrint('Designer product with ID $id not found.');
        return null;
      }
      
      // If we know it's NOT a designer product, query products table directly
      if (isDesignerProduct == false && intId != null) {
        final productResponse = await _supabaseClient
            .from('products')
            .select()
            .eq('id', intId)
            .maybeSingle();

        if (productResponse != null) {
          return JewelryItem.fromJson(productResponse);
        }
        debugPrint('Product with ID $id not found.');
        return null;
      }
      
      // If product type is unknown, check both tables (for backward compatibility)
      // Since both tables use integer IDs, we need to check both
      if (intId != null) {
        // Check products table first
        final productResponse = await _supabaseClient
            .from('products')
            .select()
            .eq('id', intId)
            .maybeSingle();

        if (productResponse != null) {
          return JewelryItem.fromJson(productResponse);
        }
        
        // If not found in products, check designerproducts
        final designerResponse = await _supabaseClient
            .from('designerproducts')
            .select()
            .eq('id', intId)
            .maybeSingle();

        if (designerResponse != null) {
          designerResponse['is_designer_product'] = true;
          return JewelryItem.fromJson(designerResponse);
        }
      } else {
        // Non-integer ID, try designerproducts
        final designerResponse = await _supabaseClient
            .from('designerproducts')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (designerResponse != null) {
          designerResponse['is_designer_product'] = true;
          return JewelryItem.fromJson(designerResponse);
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

Future<List<JewelryItem>> getMyDesignerProducts() async {
  final user = _supabaseClient.auth.currentUser;
  
  // Return empty list if no user is authenticated
  if (user == null) return [];

  try {
    final response = await _supabaseClient
        .from('designerproducts')
        .select('''
          *,
          users (
            business_name,
            address,
            country
          )
        ''')
        .eq('user_id', user.id) // Security: Only fetch rows belonging to this user
        .order('created_at', ascending: false);

    // Map the response to your JewelryItem model
    return (response as List)
        .map((json) => JewelryItem.fromJson(json))
        .toList();
  } catch (e) {
    debugPrint("Error fetching user designer products: $e");
    return [];
  }
}

  Future<void> logView(
      {String? pinId, int? productId, String? countryCode}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return; // Don't log views for guests

      await _supabaseClient.from('views').insert({
        'user_id': userId,
        'pin_id': pinId,
        'product_id': productId,
        'country': countryCode, // You can get this from an IP lookup service
      });
    } catch (e) {
      // Fail silently, as logging a view is not a critical error
      debugPrint('Error logging view: $e');
    }
  }

  /// Adds a like for a pin or a product
  Future<void> addLike({String? pinId, int? productId}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to like an item');
      }

      await _supabaseClient.from('likes').insert({
        'user_id': userId,
        'pin_id': pinId,
        'product_id': productId,
      });
    } catch (e) {
      debugPrint('Error adding like: $e');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  /// Removes a like based on the pin or product ID
  Future<void> removeLike({String? pinId, int? productId}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be logged in to unlike an item');
      }

      final query =
          _supabaseClient.from('likes').delete().eq('user_id', userId);

      if (pinId != null) {
        query.eq('pin_id', pinId);
      } else if (productId != null) {
        query.eq('product_id', productId);
      } else {
        throw Exception('Must provide a pinId or productId');
      }
    } catch (e) {
      debugPrint('Error removing like: $e');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  Future<int> getProductLikeCount(int productId) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_product_like_count',
        params: {'p_product_id': productId},
      );

      return response as int;
    } catch (e) {
      debugPrint('Error getting like count: $e');
      return 0;
    }
  }

  Future<bool> checkIfLiked({String? pinId, int? productId}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return false;

      // Start the query builder
      var queryBuilder =
          _supabaseClient.from('likes').select('id').eq('user_id', userId);
      if (pinId != null) {
        queryBuilder = queryBuilder.eq('pin_id', pinId);
      } else if (productId != null) {
        queryBuilder = queryBuilder.eq('product_id', productId);
      } else {
        return false;
      }

      final response = await queryBuilder.limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if liked: $e');
      return false;
    }
  }

  // Future<List<JewelryItem>> findSimilarProductsByImage(
  //     Uint8List imageBytes) async {
  //   try {
  //     final response = await _supabaseClient.functions.invoke(
  //       'find-similar-products', // The name of your edge function
  //       body: imageBytes,
  //     );

  //     if (response.data is List) {
  //       final dataList = response.data as List;
  //       return dataList.map((json) {
  //         // This works because your SQL returns a boolean
  //         final bool isDesigner = json['is_designer_product'] ?? false;

  //         // This works because your SQL returns "Product Title", "Image", etc.
  //         return JewelryItem.fromJson(
  //           json as Map<String, dynamic>,
  //         );
  //       }).toList();
  //     }
  //     return [];
  //   } catch (e) {
  //     debugPrint('Error calling findSimilarProductsByImage: $e');
  //     // throw Exception('Could not find similar items: $e');
  //     return [];
  //   }
  // }

  // --- FILTER OPTIONS METHODS ---

  /// Fetches distinct Product Type values from both products and designerproducts tables
  Future<List<String>> getDistinctProductTypes() async {
    try {
      final responses = await Future.wait([
        _supabaseClient
            .from('products')
            .select('"Product Type"')
            .not('Product Type', 'is', null),
        _supabaseClient
            .from('designerproducts')
            .select('"Product Type"')
            .not('Product Type', 'is', null),
      ]);

      final Set<String> uniqueTypes = {};
      
      for (var response in responses) {
        if (response is List) {
          for (var item in response) {
            final type = item['Product Type']?.toString().trim();
            if (type != null && type.isNotEmpty) {
              uniqueTypes.add(type);
            }
          }
        }
      }

      final result = uniqueTypes.toList()..sort();
      return result;
    } catch (e) {
      debugPrint('Error fetching distinct product types: $e');
      return [];
    }
  }

  /// Fetches distinct Category values from both products and designerproducts tables
  Future<List<String>> getDistinctCategories() async {
    try {
      final responses = await Future.wait([
        _supabaseClient
            .from('products')
            .select('"Category"')
            .not('Category', 'is', null),
        _supabaseClient
            .from('designerproducts')
            .select('"Category"')
            .not('Category', 'is', null),
      ]);

      final Set<String> uniqueCategories = {};
      
      for (var response in responses) {
        if (response is List) {
          for (var item in response) {
            final category = item['Category']?.toString().trim();
            if (category != null && category.isNotEmpty) {
              uniqueCategories.add(category);
            }
          }
        }
      }

      final result = uniqueCategories.toList()..sort();
      return result;
    } catch (e) {
      debugPrint('Error fetching distinct categories: $e');
      return [];
    }
  }

  /// Fetches distinct Metal Type values from both products and designerproducts tables
  Future<List<String>> getDistinctMetalTypes() async {
    try {
      final responses = await Future.wait([
        _supabaseClient
            .from('products')
            .select('"Metal Type"')
            .not('Metal Type', 'is', null),
        _supabaseClient
            .from('designerproducts')
            .select('"Metal Type"')
            .not('Metal Type', 'is', null),
      ]);

      final Set<String> uniqueMetalTypes = {};
      
      for (var response in responses) {
        if (response is List) {
          for (var item in response) {
            final metalType = item['Metal Type']?.toString().trim();
            if (metalType != null && metalType.isNotEmpty) {
              uniqueMetalTypes.add(metalType);
            }
          }
        }
      }

      final result = uniqueMetalTypes.toList()..sort();
      return result;
    } catch (e) {
      debugPrint('Error fetching distinct metal types: $e');
      return [];
    }
  }

  /// Fetches distinct Category1, Category2, Category3 values grouped by category
  /// Returns a map where keys are category names and values are lists of sub-categories
  Future<Map<String, Set<String>>> getCategorySubFilters() async {
    try {
      final responses = await Future.wait([
        _supabaseClient
            .from('products')
            .select('"Category1", "Category2", "Category3"'),
        _supabaseClient
            .from('designerproducts')
            .select('"Category1", "Category2", "Category3"'),
      ]);

      final Map<String, Set<String>> subFilters = {
        'Category1': {},
        'Category2': {},
        'Category3': {},
      };
      
      for (var response in responses) {
        if (response is List) {
          for (var item in response) {
            // Category1
            final cat1 = item['Category1']?.toString().trim();
            if (cat1 != null && cat1.isNotEmpty) {
              subFilters['Category1']!.add(cat1);
            }
            
            // Category2
            final cat2 = item['Category2']?.toString().trim();
            if (cat2 != null && cat2.isNotEmpty) {
              subFilters['Category2']!.add(cat2);
            }
            
            // Category3
            final cat3 = item['Category3']?.toString().trim();
            if (cat3 != null && cat3.isNotEmpty) {
              subFilters['Category3']!.add(cat3);
            }
          }
        }
      }

      return subFilters;
    } catch (e) {
      debugPrint('Error fetching category sub-filters: $e');
      return {
        'Category1': {},
        'Category2': {},
        'Category3': {},
      };
    }
  }
}
