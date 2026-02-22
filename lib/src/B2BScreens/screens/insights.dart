import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'dart:ui';

class InsightsPage extends StatefulWidget {
  final bool isManufacturer;

  const InsightsPage({super.key, this.isManufacturer = false});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final JewelryService _jewelryService;
  bool _isLoading = true;

  // Metrics
  int _totalViews = 0;
  int _totalLikes = 0;
  int _totalSaves = 0;
  int _totalShares = 0;

  // Growth (mocked — needs historical data)
  double _viewsGrowth = 12.0;
  double _likesGrowth = 8.0;
  double _savesGrowth = 15.0;
  double _sharesGrowth = 5.0;

  // Lists
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentActivity = [];

  // Geo analytics: [{location: "District, State", percentage: 42.5}, ...]
  List<Map<String, dynamic>> _geoAnalytics = [];

  // Premium status
  bool _isPremiumDesigner = false;

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(_supabase);
    _fetchData();
  }

  // -------------------------------------------------------------------------
  // Data Fetching
  // -------------------------------------------------------------------------

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.id;

      // 1. Fetch premium status from users table (replace 'is_premium' with your column)
      // final userResponse = await _supabase
      //     .from('users')
      //     .select('is_premium')
      //     .eq('id', userId)
      //     .maybeSingle();
      // _isPremiumDesigner = true;

      // 2. Fetch products based on role
      List<dynamic> productsData = [];

      if (widget.isManufacturer) {
        productsData = await _supabase
            .from('manufacturerproducts')
            .select('id, "Product Title", "Image", created_at')
            .eq('user_id', userId);
      } else {
        // Designer: try designerproducts first
        productsData = await _supabase
            .from('designerproducts')
            .select('id, "Product Title", "Image", created_at')
            .eq('user_id', userId);

        if (productsData.isEmpty) {
          productsData = await _supabase
              .from('products')
              .select('id, "Product Title", "Image", created_at')
              .eq('user_id', userId);
        }
      }

      if (productsData.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final productIds = productsData.map((e) => e['id'].toString()).toList();
      final productsMap = {for (var e in productsData) e['id'].toString(): e};
      final idsString = '(${productIds.map((id) => '"$id"').join(',')})';

      // 3. Fetch metrics in parallel
      final results = await Future.wait([
        _supabase.from('views').select('item_id').filter('item_id', 'in', idsString),
        _supabase.from('likes').select('item_id').filter('item_id', 'in', idsString),
        _supabase.from('shares').select('item_id').filter('item_id', 'in', idsString),
      ]);

      final viewsResponse = results[0] as List;
      final likesResponse = results[1] as List;
      final sharesResponse = results[2] as List;

      // 4. Geo Analytics (only fetch if unlocked)
      List<Map<String, dynamic>> geoData = [];
      if (widget.isManufacturer || _isPremiumDesigner) {
        geoData = await _fetchGeoAnalytics(productIds);
      }

      // 5. Top Products by views
      final Map<String, int> productViewCounts = {};
      for (var v in viewsResponse) {
        final pid = v['item_id'].toString();
        productViewCounts[pid] = (productViewCounts[pid] ?? 0) + 1;
      }

      List<Map<String, dynamic>> sortedProducts = List.from(productsData);
      sortedProducts.sort((a, b) {
        int viewsA = productViewCounts[a['id'].toString()] ?? 0;
        int viewsB = productViewCounts[b['id'].toString()] ?? 0;
        return viewsB.compareTo(viewsA);
      });

      final top4 = sortedProducts.take(4).map((p) {
        int count = productViewCounts[p['id'].toString()] ?? 0;
        String imgUrl = '';
        if (p['Image'] != null && p['Image'] is List && (p['Image'] as List).isNotEmpty) {
          imgUrl = p['Image'][0];
        } else if (p['Images'] != null) {
          imgUrl = p['Images'];
        }
        return {
          'id': p['id'],
          'name': p['Product Title'] ?? 'Unknown Product',
          'views': count,
          'credits': '$count credits',
          'change': 'increase',
          'image': imgUrl,
        };
      }).toList();

      // 6. Recent Activity from created_at
      List<Map<String, dynamic>> activityLog = [];
      for (var p in productsData) {
        if (p['created_at'] != null) {
          DateTime dt = DateTime.parse(p['created_at']);
          activityLog.add({
            'type': 'upload',
            'title': 'Product uploaded - ${p['Product Title'] ?? 'Unknown'}',
            'time': dt,
            'isPositive': true,
          });
        }
      }
      activityLog.sort((a, b) => b['time'].compareTo(a['time']));
      if (activityLog.length > 5) activityLog = activityLog.sublist(0, 5);

      if (mounted) {
        setState(() {
          _totalViews = viewsResponse.length;
          _totalLikes = likesResponse.length;
          _totalShares = sharesResponse.length;
          _totalSaves = 0;
          _topProducts = top4;
          _recentActivity = activityLog;
          _geoAnalytics = geoData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching insights: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------------------
  // Geo Analytics — Use RPC function for overall portfolio analytics
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchGeoAnalytics(List<String> itemIds) async {
    try {
      if (itemIds.isEmpty) return [];

      // Call the RPC function that returns aggregated geo analytics for all items
      final geoDataMap = await _jewelryService.getGeoAnalytics(itemIds);
      
      if (geoDataMap.isEmpty) return [];

      // Aggregate geo data from all products
      final locationCounts = <String, int>{};
      int totalViews = 0;

      // Iterate through all products and their geo data
      for (var geoList in geoDataMap.values) {
        for (var entry in geoList) {
          final location = entry['location'] as String?;
          final count = entry['percentage'] as num?; // This is actually the count from RPC
          
          if (location != null && location.isNotEmpty && count != null) {
            locationCounts[location] = (locationCounts[location] ?? 0) + count.toInt();
            totalViews += count.toInt();
          }
        }
      }

      if (totalViews == 0) return [];

      // Convert to percentages, sorted descending
      final sorted = locationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.map((e) => {
        'location': e.key,
        'percentage': (e.value / totalViews) * 100,
      }).toList();
    } catch (e) {
      debugPrint('Error fetching geo analytics: $e');
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  bool get _isUnlocked => widget.isManufacturer || _isPremiumDesigner;

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Metrics Grid
                  LayoutBuilder(builder: (context, constraints) {
                    double cardWidth = (constraints.maxWidth - (16 * 3)) / 4;
                    if (cardWidth < 240) cardWidth = 240;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildMetricCard("Total Views", _formatNumber(_totalViews),
                            "+$_viewsGrowth% vs last month",
                            Icons.remove_red_eye_outlined, Colors.blue,
                            width: cardWidth),
                        _buildMetricCard("Total Likes", _formatNumber(_totalLikes),
                            "+$_likesGrowth% vs last month",
                            Icons.favorite_border, Colors.red,
                            width: cardWidth),
                        _buildMetricCard("Total Saves", _formatNumber(_totalSaves),
                            "+$_savesGrowth% vs last month",
                            Icons.bookmark_border, Colors.purple,
                            width: cardWidth),
                        _buildMetricCard("Total Shares", _formatNumber(_totalShares),
                            "+$_sharesGrowth% vs last month",
                            Icons.share_outlined, Colors.green,
                            width: cardWidth),
                      ],
                    );
                  }),

                  const SizedBox(height: 32),

                  // Top Products + Traffic Analysis (Geo)
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          _buildTopProductsCard(),
                          const SizedBox(height: 24),
                          _buildTrafficAnalysisCard(),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildTopProductsCard()),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: _buildTrafficAnalysisCard()),
                        ],
                      );
                    }
                  }),

                  const SizedBox(height: 32),

                  _buildRecentActivityCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI Widgets
  // -------------------------------------------------------------------------

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    double? width,
  }) {
    return Container(
      width: width ?? 250,
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
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600)),
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
              Text("Top Products",
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
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
                    child: Text("$idx",
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Builder(builder: (context) {
                      String url = product['image'] ?? '';
                      if (url.isEmpty) {
                        return Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200]);
                      }
                      return CachedNetworkImage(
                        imageUrl: url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[300]),
                        errorWidget: (c, e, s) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[200]),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['name'],
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        Text(product['credits'],
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ),
                  const Icon(Icons.show_chart,
                      color: Colors.green, size: 16),
                ],
              ),
            );
          }),
          if (_topProducts.isEmpty)
            const Center(child: Text("No products found")),
        ],
      ),
    );
  }

  /// Traffic Analysis card — shows real geo data for unlocked users,
  /// blurred upgrade prompt for free designers.
  Widget _buildTrafficAnalysisCard() {
    final topGeo = _geoAnalytics.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // ── Content (always rendered, blurred when locked) ──────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Row(
                children: [
                  Text("Traffic Analysis",
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.trending_up,
                      size: 16, color: Colors.amberAccent),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Top viewer locations across all your products",
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),

              // Geo list
              if (topGeo.isEmpty)
                _buildGeoRow('None', 0)
              else
                ...topGeo.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildGeoRow(
                        entry['location'] as String,
                        (entry['percentage'] as double).round(),
                      ),
                    )),

              const SizedBox(height: 20),

              // Insight banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: Colors.black, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topGeo.isNotEmpty
                            ? 'Highest demand from ${topGeo.first['location']} '
                                '(${(topGeo.first['percentage'] as double).toStringAsFixed(1)}% of views)'
                            : 'No demand data available yet',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),

          // ── Premium blur overlay (free designers only) ──────────────────
          if (!_isUnlocked)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
    );
  }

  Widget _buildGeoRow(String location, int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF374151)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981)),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Color(0xFFFFB800), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            "Unlock Full Insights",
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Get access to detailed GEO analytics, demand trends, and actionable insights.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Upgrade to Premium",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
              Text("Recent Activity",
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          ..._recentActivity.map((activity) {
            final date = activity['time'] as DateTime;
            final timeAgo = DateTime.now().difference(date);
            String timeStr;
            if (timeAgo.inDays > 0) {
              timeStr = "${timeAgo.inDays} days ago";
            } else if (timeAgo.inHours > 0) {
              timeStr = "${timeAgo.inHours} hours ago";
            } else {
              timeStr = "${timeAgo.inMinutes} mins ago";
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: (activity['isPositive'] ?? false)
                          ? Colors.green
                          : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity['title'],
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(timeStr,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_recentActivity.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("No recent activity",
                  style: GoogleFonts.inter(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}