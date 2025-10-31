// [This is the corrected code for: lib/src/ui/screens/detail/product_page_loader.dart]

import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductPageLoader extends StatefulWidget {
  final String productSlug;

  const ProductPageLoader({super.key, required this.productSlug});

  @override
  State<ProductPageLoader> createState() => _ProductPageLoaderState();
}

class _ProductPageLoaderState extends State<ProductPageLoader> {
  late Future<JewelryItem?> _productFuture;
  late final JewelryService _jewelryService;

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(Supabase.instance.client);
    _productFuture = _fetchProductBySlug(widget.productSlug);
  }

  Future<JewelryItem?> _fetchProductBySlug(String slug) async {
    // <-- FIX: Re-create a fuzzy search term from the slug
    // "hearty-bliss-gemstone-pendant" -> "hearty%bliss%gemstone%pendant"
    final String productSearchTerm = slug.replaceAll('-', '%');

    try {
      // 2. Search Supabase for a product with this
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .ilike('Product Title', productSearchTerm) // <-- FIX: Use fuzzy search term
          .maybeSingle();
      
      if (response != null) {
        return JewelryItem.fromJson(response);
      }
      
      // 3. If not found, check 'designerproducts' table
      final designerResponse = await Supabase.instance.client
          .from('designerproducts') // Check 'designerproducts' table
          .select()
          .ilike('Product Title', productSearchTerm) // <-- FIX: Use fuzzy search term
          .maybeSingle();
          
      if (designerResponse != null) {
        return JewelryItem.fromJson(designerResponse);
      }

      // 4. If still not found, return null
      debugPrint("Product not found in 'products' or 'designerproducts' for slug: $slug (Search term: $productSearchTerm)");
      return null;

    } catch (e) {
      debugPrint("Error fetching product by slug '$slug': $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JewelryItem?>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Product not found. The link may be invalid or the item may have been removed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        }

        // Product was found! Show the detail screen.
        final product = snapshot.data!;
        
        // Use replace to show the detail screen without stacking on the loader
        return JewelryDetailScreen(jewelryItem: product);
      },
    );
  }
}