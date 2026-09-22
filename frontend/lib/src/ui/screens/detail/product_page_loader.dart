// lib/src/ui/screens/detail/product_page_loader.dart

import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductPageLoader extends StatefulWidget {
  /// Either a UUID (when [lookupByUid] is true) or a legacy title slug.
  final String productSlug;

  /// When true, [productSlug] is treated as the `uid` UUID column value and
  /// an exact match is performed. When false (default) a fuzzy title search
  /// is used for backward-compatibility with old slug-style URLs.
  final bool lookupByUid;

  const ProductPageLoader({
    super.key,
    required this.productSlug,
    this.lookupByUid = false,
  });

  @override
  State<ProductPageLoader> createState() => _ProductPageLoaderState();
}

class _ProductPageLoaderState extends State<ProductPageLoader> {
  late Future<JewelryItem?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = widget.lookupByUid
        ? _fetchProductByUid(widget.productSlug)
        : _fetchProductBySlug(widget.productSlug);
  }

  // ── NEW: Fetch by UUID ──────────────────────────────────────────────────────
  // Queries all three product tables in parallel and returns the first hit.
  // Because uuid is globally unique across tables, we never get a collision.
  Future<JewelryItem?> _fetchProductByUid(String uid) async {
    final client = Supabase.instance.client;
    try {
      final results = await Future.wait([
        client.from('products').select().eq('uid', uid).maybeSingle(),
        client.from('designerproducts').select().eq('uid', uid).maybeSingle(),
        client
            .from('manufacturerproducts')
            .select()
            .eq('uid', uid)
            .maybeSingle(),
      ]);

      if (results[0] != null) {
        return JewelryItem.fromJson(results[0] as Map<String, dynamic>);
      }
      if (results[1] != null) {
        final map = results[1] as Map<String, dynamic>;
        map['is_designer_product'] = true;
        return JewelryItem.fromJson(map);
      }
      if (results[2] != null) {
        final map = results[2] as Map<String, dynamic>;
        map['is_manufacturer_product'] = true;
        return JewelryItem.fromJson(map);
      }

      debugPrint('Product not found for uid: $uid');
      return null;
    } catch (e) {
      debugPrint("Error fetching product by uid '$uid': $e");
      return null;
    }
  }

  // ── LEGACY: Fetch by fuzzy title slug ──────────────────────────────────────
  Future<JewelryItem?> _fetchProductBySlug(String slug) async {
    final client = Supabase.instance.client;

    // Split slug into tokens so we can try shorter prefixes when the full slug
    // doesn't match (e.g. slug has SKU appended: "studded-bracelet-18kd-lk-0060brct7")
    final tokens = slug.split('-').where((t) => t.isNotEmpty).toList();

    // Try from full slug down to the first 3 tokens
    for (int take = tokens.length; take >= 3; take--) {
      final searchTerm = tokens.sublist(0, take).join('%');
      debugPrint("Slug lookup attempt: ILIKE '%$searchTerm%'");

      try {
        final response = await client
            .from('products')
            .select()
            .ilike('Product Title', '%$searchTerm%')
            .limit(1)
            .maybeSingle();

        if (response != null) {
          debugPrint('Found in products after $take tokens');
          return JewelryItem.fromJson(response);
        }

        final designerResponse = await client
            .from('designerproducts')
            .select()
            .ilike('Product Title', '%$searchTerm%')
            .limit(1)
            .maybeSingle();

        if (designerResponse != null) {
          debugPrint('Found in designerproducts after $take tokens');
          designerResponse['is_designer_product'] = true;
          return JewelryItem.fromJson(designerResponse);
        }

        final mfrResponse = await client
            .from('manufacturerproducts')
            .select()
            .ilike('Product Title', '%$searchTerm%')
            .limit(1)
            .maybeSingle();

        if (mfrResponse != null) {
          debugPrint('Found in manufacturerproducts after $take tokens');
          mfrResponse['is_manufacturer_product'] = true;
          return JewelryItem.fromJson(mfrResponse);
        }
      } catch (e) {
        debugPrint("Error fetching product by slug '$slug' (take=$take): $e");
      }
    }

    debugPrint("Product not found for slug: $slug");
    return null;
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

        return JewelryDetailScreen(jewelryItem: snapshot.data!);
      },
    );
  }
}
