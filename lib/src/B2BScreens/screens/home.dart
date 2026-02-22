import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_template.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';

class HomePage extends StatefulWidget {
  final FilterCriteria? filters;
  final bool isManufacturer;

  const HomePage({super.key, this.filters, this.isManufacturer = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<JewelryItem>> _future;
  late JewelryService _jewelryService;
  List<Map<String, dynamic>> _geoAnalytics = [];


  @override
  void initState() {
    super.initState();

    _jewelryService = JewelryService(Supabase.instance.client);
    _future = widget.isManufacturer 
        ? _jewelryService.getMyManufacturerProducts()
        : _jewelryService.getMyDesignerProducts();
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
              if (constraints.maxWidth > 1200) crossAxisCount = 4; // Keep 4 columns on large screens

              return Center(
                // child: ConstrainedBox(
                //   constraints: const BoxConstraints(maxWidth: 1280), // max-w-7xl from Tailwind
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.70, // Slightly taller cards
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ProductCard(item: products[index], isManufacturer: widget.isManufacturer);
                    },
                  ),
                );
              // );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final JewelryItem item;
  final bool isManufacturer;

  const _ProductCard({required this.item, this.isManufacturer = false});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isHovered = false;
  bool _isTapped = false; // New state for mobile tap

  // Helper to determine demand level
  String _getDemandLevel() {
    final likes = widget.item.likes ?? 0;
    final isTrending = widget.item.isTrending ?? false;
    
    if (isTrending || likes > 1000) return 'High demand';
    if (likes > 500) return 'Rising demand';
    return 'Medium demand';
  }

  // Helper to get demand level colors
  (Color bg, Color fg, Color border) _getDemandColors() {
    final demand = _getDemandLevel();
    if (demand == 'High demand') {
      return (
        const Color(0xFFD1FAE5), // emerald-100
        const Color(0xFF047857), // emerald-700
        const Color(0xFFA7F3D0), // emerald-200
      );
    } else if (demand == 'Rising demand') {
      return (
        const Color(0xFFFEF3C7), // amber-100
        const Color(0xFFB45309), // amber-700
        const Color(0xFFFDE68A), // amber-200
      );
    } else {
      return (
        const Color(0xFFF3F4F6), // gray-100
        const Color(0xFF374151), // gray-700
        const Color(0xFFE5E7EB), // gray-200
      );
    }
  }

  void _showInsights(BuildContext context) {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints.expand(width: MediaQuery.of(context).size.width),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InsightsBottomSheet(
        item: widget.item, 
        isManufacturer: widget.isManufacturer,
        geoAnalytics: widget.item.geoAnalytics ?? [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.productTitle ?? 'Unknown Product'; 
    final category = widget.item.category ?? '';
    final subCategory = widget.item.subCategory ?? '';
    final price = widget.item.price?.toString() ?? '0';

    // Image logic
    final List<String> images = widget.item.images ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : '';

    // Location logic
    final String location = widget.item.users?['address'] ?? 'India'; 
    
    final int likes = widget.item.likes ?? 0;
    final int saves = widget.item.saves ?? 0;
    final int credits = widget.item.credits ?? 0;
    final bool isTrending = widget.item.isTrending ?? false;
    
    final demandLevel = _getDemandLevel();
    final demandColors = _getDemandColors();

    // Check if should show overlay (hover OR tap)
    final bool showOverlay = _isHovered || _isTapped;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          setState(() => _isTapped = !_isTapped);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 20 : 6,
                offset: Offset(0, _isHovered ? 8 : 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Section with 3:4 aspect ratio
                Expanded(
                  child: Stack(
                    children: [
                      // Product Image
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFF3F4F6),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Color(0xFF9CA3AF),
                                      size: 48,
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Color(0xFF9CA3AF),
                                  size: 48,
                                ),
                              ),
                      ),
                      
                      // Trending Badge (Top Left)
                      if (isTrending)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFBBF24),
                                  Color(0xFFF59E0B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.trending_up,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Trending",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Overlay with Action Buttons (Hover OR Tap)
                      if (showOverlay)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.4),
                                ],
                              ),
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // View Insights Button (Compact for Mobile)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() => _isTapped = false); // Close overlay
                                        _showInsights(context);
                                      },
                                      icon: const Icon(Icons.visibility, size: 18),
                                      label: const Text(
                                        'View Insights',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Action Buttons Row
                                    // Row(
                                    //   mainAxisAlignment: MainAxisAlignment.center,
                                    //   mainAxisSize: MainAxisSize.min,
                                    //   children: [
                                    //     // Like Button
                                    //     Container(
                                    //       width: 44,
                                    //       height: 44,
                                    //       decoration: const BoxDecoration(
                                    //         color: Colors.white,
                                    //         shape: BoxShape.circle,
                                    //       ),
                                    //       child: IconButton(
                                    //         icon: const Icon(Icons.favorite_border, size: 20),
                                    //         padding: EdgeInsets.zero,
                                    //         onPressed: () {
                                    //           // Handle like
                                    //         },
                                    //       ),
                                    //     ),
                                    //     const SizedBox(width: 12),
                                        
                                    //     // Save Button
                                    //     Container(
                                    //       width: 44,
                                    //       height: 44,
                                    //       decoration: const BoxDecoration(
                                    //         color: Colors.white,
                                    //         shape: BoxShape.circle,
                                    //       ),
                                    //       child: IconButton(
                                    //         icon: const Icon(Icons.bookmark_border, size: 20),
                                    //         padding: EdgeInsets.zero,
                                    //         onPressed: () {
                                    //           // Handle save
                                    //         },
                                    //       ),
                                    //     ),
                                    //   ],
                                    // ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Details Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Category • SubCategory
                      Text(
                        "$category · $subCategory",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Demand Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: demandColors.$1,
                          border: Border.all(
                            color: demandColors.$3,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              demandLevel,
                              style: TextStyle(
                                color: demandColors.$2,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "·",
                              style: TextStyle(
                                color: demandColors.$2,
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: demandColors.$2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Footer: Stats & Credits
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Likes
                          const Icon(
                            Icons.favorite_border,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$likes",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Saves
                          const Icon(
                            Icons.bookmark_border,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$saves",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Price / Credits
                          Text(
                            "$credits credits",
                            style: const TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _InsightsBottomSheet extends StatelessWidget {
  final dynamic item; // Replace 'dynamic' with your JewelryItem model
  final bool isManufacturer;
  final List<Map<String, dynamic>> geoAnalytics;

  const _InsightsBottomSheet({
    super.key, 
    required this.item, 
    this.isManufacturer = false,
    this.geoAnalytics = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Data Extraction
    final title = item.productTitle ?? 'Unknown Product';
    final category = item.category ?? '';
    final subCategory = item.subCategory ?? '';
    final metalType = item.metalType ?? '';
    final metalPurity = item.metalPurity ?? '';
    final weight = item.metalWeight?.toString() ?? '0';
    final List<String> images = item.images ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : '';
    final int likes = item.likes ?? 0;
    final int saves = item.saves ?? 0;
    final int shares = item.share ?? 0; 
    final int credits = item.credits ?? 0;
    
    // Premium logic: Manufacturers always see full insights, designers don't unless paying
    final bool isPremium = isManufacturer ? true : false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // 2. Header
          _buildHeader(context),

          // 3. Scrollable Content
          Flexible(
            child: ScrollConfiguration(
              // REMOVES THE SCROLLBAR HANDLE
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildProductInfo(imageUrl, title, category, subCategory, weight, metalPurity, metalType),
                          const SizedBox(height: 24),
                          _buildStatsRow(likes, saves, shares, credits),
                        ],
                      ),
                    ),

                    // 4. Locked Section (GEO & Insights)
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGeoHeader(),
                              const SizedBox(height: 16),
                              // Display geo analytics if available
                              if (geoAnalytics.isNotEmpty)
                                ...geoAnalytics.take(5).map((geo) {
                                  final location = geo['location'] as String? ?? 'Unknown';
                                  final percentage = (geo['percentage'] as num?)?.toInt() ?? 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _LocationProgress(city: location, percentage: percentage),
                                  );
                                }).toList()
                              else ...[
                                // Fallback if no geo data
                                const _LocationProgress(city: 'Mumbai', percentage: 42),
                                const SizedBox(height: 12),
                                const _LocationProgress(city: 'Delhi', percentage: 28),
                                const SizedBox(height: 12),
                                const _LocationProgress(city: 'Bangalore', percentage: 18),
                              ],
                              const SizedBox(height: 24),
                              _buildInsightCard(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),

                        // PREMIUM OVERLAY
                        if (!isPremium)
                          Positioned.fill(
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                                child: Container(
                                  color: Colors.white.withOpacity(0.3),
                                  alignment: Alignment.center,
                                  child: _buildUpgradeCard(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helper Methods ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          const Text('Post Insights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), shape: const CircleBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo(String url, String title, String cat, String sub, String w, String p, String m) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url.isNotEmpty 
            ? Image.network(url, width: 80, height: 80, fit: BoxFit.cover)
            : Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.image)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$cat · $sub', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Text('${w}g · $p $m', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int l, int s, int sh, int c) {
    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.favorite, iconColor: Colors.red, value: '$l', label: 'Likes', bgColor: const Color(0xFFF9FAFB))),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(icon: Icons.bookmark, iconColor: Colors.blue, value: '$s', label: 'Saves', bgColor: const Color(0xFFF9FAFB))),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(icon: Icons.share, iconColor: Colors.purple, value: '$sh', label: 'Shares', bgColor: const Color(0xFFF9FAFB))),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          icon: Icons.trending_up, 
          iconColor: Colors.amberAccent, 
          value: '$c', 
          label: 'Credits', 
          bgColor: const Color(0xFFECFDF5),
          border: Colors.amberAccent,
          valueColor: Colors.amberAccent,
        )),
      ],
    );
  }

  Widget _buildUpgradeCard() {
  return Container(
    // Restrict width but let height be dynamic
    constraints: const BoxConstraints(maxWidth: 320),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // Reduced vertical padding
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFFB800), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min, // Crucial: This prevents vertical expansion
      children: [
        // Crown/Premium Icon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFB800),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          "Unlock Full Insights",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Get access to detailed GEO analytics, demand trends, and actionable insights.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey, 
            fontSize: 13, 
            height: 1.4, // Improves readability without adding height
          ),
        ),
        const SizedBox(height: 20),
        // Upgrade Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14), // Slightly thinner button
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildGeoHeader() {
    return Row(
      children: const [
        Text('Top GEO Locations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(width: 8),
        Icon(Icons.trending_up, size: 16, color: Colors.amberAccent),
      ],
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.trending_up, color: Colors.black, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text('Demand increasing in West India, peak season approaching', style: TextStyle(color: Color(0xFF065F46)))),
        ],
      ),
    );
  }
}

// Keep your existing _StatCard and _LocationProgress classes below...

// Stat Card Widget - Column layout for 1 row with 4 columns
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color bgColor;
  final Color? border;
  final Color? valueColor;
  final Color? labelColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.bgColor,
    this.border,
    this.valueColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: border != null ? Border.all(color: border!, width: 1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF111827), // gray-900
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor ?? const Color(0xFF6B7280), // gray-600
            ),
          ),
        ],
      ),
    );
  }
}

// Location Progress Widget
class _LocationProgress extends StatelessWidget {
  final String city;
  final int percentage;

  const _LocationProgress({
    required this.city,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              city,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151), // gray-700
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827), // gray-900
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFF3F4F6), // gray-100
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF10B981), // emerald-500
            ),
          ),
        ),
      ],
    );
  }
}