import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/geo_analytics_service.dart';
import 'package:jewelry_nafisa/src/widgets/geo_analytics_widget.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:jewelry_nafisa/src/widgets/blur_up_placeholder.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Determine user type
  bool _isManufacturer = false;

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

  // Geo analytics data (shared widget data model)
  GeoAnalyticsData _geoData = GeoAnalyticsData.empty;

  // Premium status
  bool _isPremiumDesigner = false;

  @override
  void initState() {
    super.initState();

    // Get user profile to determine if manufacturer
    final userProfile =
        Provider.of<UserProfileProvider>(context, listen: false).userProfile;
    _isManufacturer = userProfile?.manufacturerProfile != null;

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

      if (_isManufacturer) {
        productsData = await _supabase
            .from('manufacturerproducts')
            .select('id, "Product Title", "Image", created_at, images_arr')
            .eq('user_id', userId);
      } else {
        // Designer: try designerproducts first
        productsData = await _supabase
            .from('designerproducts')
            .select('id, "Product Title", "Image", created_at, images_arr')
            .eq('user_id', userId);

        if (productsData.isEmpty) {
          productsData = await _supabase
              .from('products')
              .select('id, "Product Title", "Image", created_at, images_arr')
              .eq('user_id', userId);
        }
      }

      if (productsData.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final productIds = productsData.map((e) => e['id'].toString()).toList();

      // 3. Fetch metrics in parallel using correct Supabase SDK syntax
      final results = await Future.wait([
        _supabase
            .from('views')
            .select('item_id')
            .inFilter('item_id', productIds),
        _supabase
            .from('likes')
            .select('item_id')
            .inFilter('item_id', productIds),
        _supabase
            .from('shares')
            .select('item_id')
            .inFilter('item_id', productIds),
        _supabase
            .from('saves')
            .select('item_id')
            .inFilter('item_id', productIds),
      ]);

      final viewsResponse = results[0] as List;
      final likesResponse = results[1] as List;
      final sharesResponse = results[2] as List;
      final savesResponse = results[3] as List;

      // 4. Geo Analytics — use shared service
      GeoAnalyticsData geoData = GeoAnalyticsData.empty;
      if (_isManufacturer || _isPremiumDesigner) {
        geoData =
            await GeoAnalyticsService.fetchGeoData(productIds: productIds);
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
        final imagesArr = p['images_arr'];
        if (imagesArr is List && imagesArr.isNotEmpty) {
          imgUrl = imagesArr[0];
        } else if (p['Image'] != null &&
            p['Image'] is List &&
            (p['Image'] as List).isNotEmpty) {
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
          _totalSaves = savesResponse.length;
          _topProducts = top4;
          _recentActivity = activityLog;
          _geoData = geoData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching insights: $e');
      if (mounted) setState(() => _isLoading = false);
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

  bool get _isUnlocked => _isManufacturer || _isPremiumDesigner;

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
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Metrics Grid
                  // Metrics Grid — 2×2 on mobile, 4-in-a-row on wider screens
                  LayoutBuilder(builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 600;
                    final crossCount = isSmall ? 2 : 4;
                    final spacing = isSmall ? 12.0 : 16.0;
                    final cardWidth =
                        (constraints.maxWidth - (spacing * (crossCount - 1))) /
                            crossCount;

                    final cards = [
                      _buildMetricCard(
                          "Total Views",
                          _formatNumber(_totalViews),
                          "+$_viewsGrowth% vs last month",
                          Icons.remove_red_eye_outlined,
                          Colors.blue,
                          width: cardWidth,
                          compact: isSmall),
                      _buildMetricCard(
                          "Total Likes",
                          _formatNumber(_totalLikes),
                          "+$_likesGrowth% vs last month",
                          Icons.favorite_border,
                          Colors.red,
                          width: cardWidth,
                          compact: isSmall),
                      _buildMetricCard(
                          "Total Saves",
                          _formatNumber(_totalSaves),
                          "+$_savesGrowth% vs last month",
                          Icons.bookmark_border,
                          Colors.purple,
                          width: cardWidth,
                          compact: isSmall),
                      _buildMetricCard(
                          "Total Shares",
                          _formatNumber(_totalShares),
                          "+$_sharesGrowth% vs last month",
                          Icons.share_outlined,
                          Colors.green,
                          width: cardWidth,
                          compact: isSmall),
                    ];

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: cards,
                    );
                  }),

                  const SizedBox(height: 32),

                  // Top Products
                  _buildTopProductsCard(),

                  const SizedBox(height: 32),

                  // Geo Analytics — Full widget with tabs
                  if (_isUnlocked)
                    GeoAnalyticsWidget(
                      data: _geoData,
                      title: 'Geographic Insights',
                      subtitle:
                          'Analyze views, likes, shares and saves of your products by country, state and pincode.',
                      primaryColor: const Color(0xFF0A4F3F),
                      accentColor: const Color(0xFFD4AF37),
                    )
                  else
                    _buildLockedGeoCard(),

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
    bool compact = false,
  }) {
    return Container(
      width: width ?? 250,
      padding: EdgeInsets.all(compact ? 14 : 20),
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
            padding: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: compact ? 16 : 20),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: compact ? 10 : 11,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                            width: 40, height: 40, color: Colors.grey[200]);
                      }
                      return CachedNetworkImage(
                        imageUrl: url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => SizedBox(
                            width: 40,
                            height: 40,
                            child: createBlurUpPlaceholder()),
                        errorWidget: (c, e, s) => Container(
                            width: 40, height: 40, color: Colors.grey[200]),
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
                                fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        Text(product['credits'],
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ),
                  const Icon(Icons.show_chart, color: Colors.green, size: 16),
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

  /// Locked geo analytics card — shown for free designers.
  Widget _buildLockedGeoCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // Blurred placeholder
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Geographic Insights',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Detailed country, state, and pincode breakdown',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 32),
              // Placeholder rows
              for (int i = 0; i < 4; i++) ...[
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
          // Blur overlay with upgrade prompt
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.4),
                  alignment: Alignment.center,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFD4AF37), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: Color(0xFFD4AF37), shape: BoxShape.circle),
                          child: const Icon(Icons.workspace_premium,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text('Unlock Full Insights',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          'Get access to detailed GEO analytics, demand trends, and actionable insights.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Upgrade to Premium',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
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
                                fontSize: 13, fontWeight: FontWeight.w500)),
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
