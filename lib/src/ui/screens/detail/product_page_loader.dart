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
    // 1. Re-create the 'Product Title' from the slug
    // "dainty-floral-openable-gold-bracelets" -> "dainty floral openable gold bracelets"
    final String productTitle = slug.replaceAll('-', ' ');

    try {
      // 2. Search Supabase for a product with this exact title
      // We use 'ilike' for a case-insensitive match
      final response = await Supabase.instance.client
          .from('products') // Check 'products' table
          .select()
          .ilike('Product Title', productTitle)
          .maybeSingle();

      if (response != null) {
        return JewelryItem.fromJson(response);
      }
      
      // 3. If not found, check 'designerproducts' table
      final designerResponse = await Supabase.instance.client
          .from('designerproducts') // Check 'designerproducts' table
          .select()
          .ilike('Product Title', productTitle)
          .maybeSingle();
          
      if (designerResponse != null) {
        return JewelryItem.fromJson(designerResponse);
      }

      // 4. If still not found, return null
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
          return const Scaffold(
            body: Center(
              child: Text(
                'Product not found.',
                style: TextStyle(fontSize: 24),
              ),
            ),
          );
        }

        // Product was found! Show the detail screen.
        final product = snapshot.data!;
        return JewelryDetailScreen(jewelryItem: product);
      },
    );
  }
}