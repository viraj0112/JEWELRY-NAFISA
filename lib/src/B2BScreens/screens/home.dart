import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_template.dart';

import 'package:jewelry_nafisa/src/models/filter_criteria.dart';

class HomePage extends StatefulWidget {
  final FilterCriteria? filters;
  const HomePage({super.key, this.filters});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<JewelryItem>> _future;
  late JewelryService _jewelryService;

  @override
  void initState() {
    super.initState();

    _jewelryService = JewelryService(Supabase.instance.client);
    _future = _jewelryService.getMyDesignerProducts();
  }

  // Helper method to check if a product matches the filters
  bool _matchesFilter(JewelryItem item) {
    if (widget.filters == null || widget.filters!.isEmpty) return true;
    final f = widget.filters!;
    
    // 1. Location (Mock: assumes item.users['address'] contains specific location string)
    if (f.location != null && f.location != 'India') {
      // Just an example check
      // if (item.users?['address'] != f.location) return false;
    }

    // 2. Product Type
    if (f.productType != null) {
      if (item.productType != f.productType && item.category != f.productType) return false;
    }

    // 3. Category
    if (f.category != null) {
      if (item.category != f.category && item.subCategory != f.category) return false; 
    }
    
    // 3a. Category1
    if (f.category1 != null) {
      if (item.category1 != f.category1) return false;
    }
    
    // 3b. Category2
    if (f.category2 != null) {
      if (item.category2 != f.category2) return false;
    }
    
    // 3c. Category3
    if (f.category3 != null) {
      if (item.category3 != f.category3) return false;
    }

    // 4. Metal Type
    if (f.metalType != null) {
      if (item.metalType != f.metalType && item.metalPurity != f.metalType) return false;
    }

    // 5. Demand Level (Approximation)
    if (f.demandLevel != null) {
      if (f.demandLevel == 'Rising' && (item.isTrending != true)) return false;
      if (f.demandLevel == 'High' && ((item.likes ?? 0) < 20)) return false; 
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PageTemplate(
      title: "Home",
      child: FutureBuilder<List<JewelryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No products found"));
          }

          // Apply filters
          final allProducts = snapshot.data!;
          final products = allProducts.where(_matchesFilter).toList();
          
          if (products.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.search_off, size: 48, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("No products match your filters"),
                 ],
               ),
             );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Responsive Grid Logic
              int crossAxisCount = 2; // Mobile default
              if (constraints.maxWidth > 600) crossAxisCount = 3; // Tablet
              if (constraints.maxWidth > 900) crossAxisCount = 4; // Desktop
              if (constraints.maxWidth > 1200) crossAxisCount = 5; // Large Desktop

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.72, // Adjusts height vs width of cards
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _ProductCard(item: products[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  // Change 1: Accept the specific model instead of a Map
  final JewelryItem item; 

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // Change 2: Access properties directly from the item object
    // Verify these property names match your jewelry_item.dart model
    final title = item.productTitle ?? 'Unknown Product'; 
    final category = item.category ?? '';
    final subCategory = item.subCategory ?? '';
    final price = item.price?.toString() ?? '0';

    // Image logic
    final List<String> images = item.images ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : '';

    // Location logic (Assuming nested user object or map)
    // If 'users' is a Map in your model:
    final String location = item.users?['address'] ?? 'India'; 
    // OR if 'users' is a class: item.user?.address ?? 'India';
    
    final int likes = item.likes ?? 0;
    final int saves = item.saves ?? 0;
    final bool isTrending = item.isTrending ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image Section
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                // Product Image
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    color: Colors.grey.shade100,
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.image_not_supported, color: Colors.grey)
                      : null,
                ),
                
                // Trending Badge (Top Left)
                if (isTrending)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.trending_up, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "Trending",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Details Section
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Category • SubCategory
                  Text(
                    "$category • $subCategory",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Tags Row
                  Row(
                    children: [
                      _buildTag("High demand", Colors.green.shade50, Colors.green.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTag(location, Colors.teal.shade50, Colors.teal.shade700),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Footer: Stats & Credits
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Likes
                      Icon(Icons.favorite_border, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "$likes",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      
                      // Saves
                      Icon(Icons.bookmark_border, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "$saves",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      
                      const Spacer(),
                      
                      // Price / Credits
                      Text(
                        "$price credits",
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
