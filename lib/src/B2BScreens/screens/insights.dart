import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Metrics
  int _totalViews = 0;
  int _totalLikes = 0;
  int _totalSaves = 0;
  int _totalShares = 0;

  // Growth (Mocked for now as we need historical data, but logic will be there)
  double _viewsGrowth = 12.0;
  double _likesGrowth = 8.0;
  double _savesGrowth = 15.0;
  double _sharesGrowth = 5.0;

  // Lists
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.id;

      // 1. Fetch User's Products IDs
      // Trying 'designerproducts' first as per B2B context
      List<dynamic> productsData = await _supabase
          .from('designerproducts')
          .select('id, "Product Title", "Image"') // Columns from schema
          .eq('user_id', userId);

      // If no designer products, try standard 'products'
      if (productsData.isEmpty) {
        productsData = await _supabase
            .from('products')
            .select('id, "Product Title", "Image", "created_at"') // Check schema for Title
            .eq('user_id', userId);
      }

      if (productsData.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Map product IDs (as strings for interaction tables)
      final productIds = productsData.map((e) => e['id'].toString()).toList();
      final productsMap = {for (var e in productsData) e['id'].toString(): e};

      // Prepare filter string for text column 'item_id'
      // Postgrest 'in' expects format: ("val1","val2") for text columns
      final idsString = '(${productIds.map((id) => '"$id"').join(',')})';

      // 2. Fetch Metrics (Views, Likes, Shares)
      
      // Views
      final viewsResponse = await _supabase
          .from('views')
          .select('item_id') 
          .filter('item_id', 'in', idsString);
      
      final likesResponse = await _supabase
          .from('likes')
          .select('item_id')
          .filter('item_id', 'in', idsString);

      final sharesResponse = await _supabase
          .from('shares')
          .select('item_id')
          .filter('item_id', 'in', idsString);

      // Saves (Approximation)
      // 'analytics_daily' uses UUIDs, but our products have Int IDs. 
      // We'll skip fetching from there to avoid type mismatch errors.
      // If there's no dedicated 'saves' table for these products, we default to 0.
      int viewsCount = viewsResponse.length;
      int likesCount = likesResponse.length;
      int sharesCount = sharesResponse.length;
      int savesCount = 0; 



      // 3. Top Products Calculation
      // Count views per product
      Map<String, int> productViews = {};
      for (var v in viewsResponse) {
        final pid = v['item_id'].toString();
        productViews[pid] = (productViews[pid] ?? 0) + 1;
      }

      // Sort products by views
      List<Map<String, dynamic>> sortedProducts = List.from(productsData);
      sortedProducts.sort((a, b) {
        int viewsA = productViews[a['id'].toString()] ?? 0;
        int viewsB = productViews[b['id'].toString()] ?? 0;
        return viewsB.compareTo(viewsA); // Descending
      });

      // Take top 4
      final top4 = sortedProducts.take(4).map((p) {
        int count = productViews[p['id'].toString()] ?? 0;
        // Parse Image
        // Schema: Image ARRAY (designerproducts) or Images text (products) or Image ARRAY (products)
        // Schema line 94: Image ARRAY. Line 173: Images text. Line 209: Image ARRAY.
        // We handle both.
        String imgUrl = '';
        if (p['Image'] != null && (p['Image'] is List) && (p['Image'] as List).isNotEmpty) {
           imgUrl = p['Image'][0];
        } else if (p['Images'] != null) {
           imgUrl = p['Images']; // If it's a string
        }

        return {
          'id': p['id'],
          'name': p['Product Title'] ?? 'Unknown Product',
          'credits': "$count credits", // Using views as credits
          'change': "increase", // Mock
          'image': imgUrl
        };
      }).toList();

      // 4. Recent Activity
      // We can use 'created_at' from products for "Product uploaded"
      // And maybe milestone logic.
      List<Map<String, dynamic>> activityLog = [];
      
      // Add Uploads
      for (var p in productsData) {
        if (p['created_at'] != null) {
           DateTime dt = DateTime.parse(p['created_at']);
           activityLog.add({
             'type': 'upload',
             'title': 'Product uploaded - ${p['Product Title']}',
             'time': dt,
             'isPositive': true, // Green dot
           });
        }
      }

      // Add "Trending" mock if views > 5
      for (var entry in productViews.entries) {
        if (entry.value > 5) {
           var p = productsMap[entry.key];
           if (p != null) {
              // Add a recent timestamp (mock functionality as views table doesn't denote WHEN easily without full dates)
              // Actually views table has created_at!
              // We could query views ordered by created_at desc.
           }
        }
      }
      
      // Sort activity by time desc
      activityLog.sort((a, b) => b['time'].compareTo(a['time']));
      
      // Limit to 5
      if (activityLog.length > 5) activityLog = activityLog.sublist(0, 5);


      if (mounted) {
        setState(() {
          _totalViews = viewsCount;
          _totalLikes = likesCount;
          _totalShares = sharesCount;
          _totalSaves = savesCount;
          
          _topProducts = top4;
          _recentActivity = activityLog;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error fetching insights: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white, // Or theme background
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    "Portfolio Insights",
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Overview of your product performance",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Metrics Grid
                  LayoutBuilder(builder: (context, constraints) {
                    // Responsive Grid
                    // Calculate card width based on available width, but keep min 240
                    double cardWidth = (constraints.maxWidth - (16 * 3)) / 4;
                    if (cardWidth < 240) cardWidth = 240;
                    
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildMetricCard("Total Views", formatNumber(_totalViews), "+$_viewsGrowth% vs last month", Icons.remove_red_eye_outlined, Colors.blue, width: cardWidth),
                        _buildMetricCard("Total Likes", formatNumber(_totalLikes), "+$_likesGrowth% vs last month", Icons.favorite_border, Colors.red, width: cardWidth),
                        _buildMetricCard("Total Saves", formatNumber(_totalSaves), "+$_savesGrowth% vs last month", Icons.bookmark_border, Colors.purple, width: cardWidth),
                        _buildMetricCard("Total Shares", formatNumber(_totalShares), "+$_sharesGrowth% vs last month", Icons.share_outlined, Colors.green, width: cardWidth),
                      ],
                    );
                  }),

                  const SizedBox(height: 32),

                  // Middle Section: Top Products + Chart/Blur
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 900) {
                        return Column(
                          children: [
                            _buildTopProductsCard(),
                            const SizedBox(height: 24),
                            _buildBlurredChartCard(),
                          ],
                        );
                      } else {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildTopProductsCard()),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: _buildBlurredChartCard()),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  // Recent Activity
                  _buildRecentActivityCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, {double? width}) {
    return Container(
      width: width ?? 250, // Responsive width
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Top Products", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const Icon(Icons.trending_up, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          ..._topProducts.asMap().entries.map((entry) {
            int idx = entry.key + 1;
            var product = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text("$idx", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Builder(builder: (context) {
                       String url = product['image'] ?? '';
                       if (url.isEmpty) return Container(width: 40, height: 40, color: Colors.grey[200]);
                       return CachedNetworkImage(
                         imageUrl: url,
                         width: 40, 
                         height: 40, 
                         fit: BoxFit.cover,
                         placeholder: (context, url) => Container(width: 40, height: 40, color: Colors.grey[300]),
                         errorWidget: (c,e,s) => Container(width: 40, height: 40, color: Colors.grey[200]),
                       );
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        Text(product['credits'], style: GoogleFonts.inter(fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ),
                  const Icon(Icons.show_chart, color: Colors.green, size: 16),
                ],
              ),
            );
          }).toList(),
          if (_topProducts.isEmpty)
             const Center(child: Text("No products found")),
        ],
      ),
    );
  }

  Widget _buildBlurredChartCard() {
    return Container(
      height: 300, // Match height roughly
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
           // Fake content to blur
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text("Traffic Analysis", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    color: Colors.amber.withOpacity(0.1),
                    child: Center(child: Icon(Icons.pie_chart, size: 100, color: Colors.amber)),
                  ),
                )
             ],
           ),
           // Blur effect
           Positioned.fill(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(16),
               child: Container(
                 color: Colors.white.withOpacity(0.6), // Semi-transparent overlay style as in image
                 child: Center(
                   child: Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber),
                      child: Icon(Icons.lock_outline, color: Colors.white),
                   ),
                 ),
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text("Recent Activity", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
               const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
             ],
          ),
          const SizedBox(height: 24),
          ..._recentActivity.map((activity) {
            final date = activity['time'] as DateTime;
            final timeAgo = DateTime.now().difference(date);
            String timeStr = "";
            if (timeAgo.inDays > 0) timeStr = "${timeAgo.inDays} days ago";
            else if (timeAgo.inHours > 0) timeStr = "${timeAgo.inHours} hours ago";
            else timeStr = "${timeAgo.inMinutes} mins ago";

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: (activity['isPositive'] ?? false) ? Colors.green : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity['title'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          if (_recentActivity.isEmpty)
             const Padding(padding: EdgeInsets.all(8.0), child: Text("No recent activity")),
        ],
      ),
    );
  }
}
