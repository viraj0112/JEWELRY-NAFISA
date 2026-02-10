import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/designer_profile.dart';
import 'page_template.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  DesignerProfile? _profile;
  
  // Dynamic metrics
  int _totalProducts = 0;
  int _totalCredits = 0;
  int _profileViews = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchMetrics();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await _supabase
          .from('designer_profiles')
          .select()
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profile = DesignerProfile.fromMap(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.id;

      // 1. Fetch User's Products
      List<dynamic> productsData = await _supabase
          .from('designerproducts')
          .select('id, "Product Title", "Image"')
          .eq('user_id', userId);

      // Fallback to products table if no designer products
      if (productsData.isEmpty) {
        productsData = await _supabase
            .from('products')
            .select('id, "Product Title", "Image", "created_at"')
            .eq('user_id', userId);
      }

      final productCount = productsData.length;
      
      if (productsData.isEmpty) {
        setState(() {
          _totalProducts = 0;
          _totalCredits = 0;
          _profileViews = 0;
          _isLoading = false;
        });
        return;
      }

      // Get product IDs
      final productIds = productsData.map((e) => e['id'].toString()).toList();
      final idsString = '(${productIds.map((id) => '"$id"').join(',')})';

      // 2. Fetch Views (Credits)
      final viewsResponse = await _supabase
          .from('views')
          .select('item_id')
          .filter('item_id', 'in', idsString);

      final totalViews = viewsResponse.length;

      // 3. Fetch Profile Views (if you have a separate table for profile views)
      // For now, we'll use total product views as profile views
      // If you have a separate profile_views table, query it here
      int profileViewsCount = totalViews; // Or fetch from profile_views table

      if (mounted) {
        setState(() {
          _totalProducts = productCount;
          _totalCredits = totalViews; // Credits = views
          _profileViews = profileViewsCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching metrics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // Optional: Navigate to login if not handled by auth state listener
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PageTemplate(
        title: "Profile",
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Default values if profile fetch fails or empty
    final businessName = _profile?.businessName ?? "Manufacturer Account";
    final initial = businessName.isNotEmpty ? businessName[0].toUpperCase() : "M";

    return PageTemplate(
      title: "Profile",
      child: Center(
        child: ListView(
          padding: const EdgeInsets.all(16).copyWith(bottom: 80),
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Row - Avatar, Name & Settings
                  Row(
                    children: [
                      // Avatar with Gradient
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF34D399), // emerald-400
                              Color(0xFF059669), // emerald-600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Name and Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              businessName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Premium Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFBBF24), // amber-400
                                    Color(0xFFEAB308), // yellow-500
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.workspace_premium,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Premium Member',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Settings Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats Grid - 3 Columns (NOW DYNAMIC)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.upload_outlined,
                          value: _totalProducts.toString(),
                          label: 'Total Products',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.trending_up,
                          value: _formatNumber(_totalCredits),
                          label: 'Total Credits',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.visibility_outlined,
                          value: _formatNumber(_profileViews),
                          label: 'Profile Views',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Premium Member Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFECFDF5), // emerald-50
                    Color(0xFFD1FAE5), // green-50
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFA7F3D0), // emerald-200
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and Title Row
                  Row(
                    children: [
                      // Crown Icon with Gradient Background
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFBBF24), // amber-400
                              Color(0xFFEAB308), // yellow-500
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Title and Subtitle
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium Member',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You have access to all features',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Next Billing
                  const Text(
                    'Next billing date: January 9, 2026',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Manage Subscription Button
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Manage subscription',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF059669), // emerald-600
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Account Settings Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFF3F4F6),
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Account Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  
                  // Settings Items
                  _buildSettingItem(
                    'Edit Profile',
                    'Update your business information',
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                  
                  _buildSettingItem(
                    'Notification Preferences',
                    'Manage your notification settings',
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                  
                  _buildSettingItem(
                    'Privacy & Security',
                    'Control your privacy settings',
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                  
                  _buildSettingItem(
                    'Help & Support',
                    'Get help with your account',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sign Out Button
            Center(
              child: TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(
                  Icons.logout,
                  size: 16,
                  color: Color(0xFFDC2626), // red-600
                ),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDC2626), // red-600
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // gray-50
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF059669), // emerald-600
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827), // gray-900
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280), // gray-600
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle) {
    return InkWell(
      onTap: () {
        // Handle navigation
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827), // gray-900
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280), // gray-600
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF9CA3AF), // gray-400
            ),
          ],
        ),
      ),
    );
  }
}