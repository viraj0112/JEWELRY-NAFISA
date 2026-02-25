import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/designer_profile.dart';
import 'package:jewelry_nafisa/src/models/manufacturer_profile.dart';
import 'page_template.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  dynamic _profile; // DesignerProfile or ManufacturerProfile
  String _profileType = ''; // 'designer' or 'manufacturer'

  // Dynamic metrics
  int _totalProducts = 0;
  int _totalCredits = 0;
  int _profileViews = 0;

  // Premium — fetched from users table
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // -------------------------------------------------------------------------
  // Data fetching
  // -------------------------------------------------------------------------

  Future<void> _fetchAll() async {
    await Future.wait([_fetchProfile(), _fetchMetrics()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Fetch premium status (replace 'is_premium' with your actual column)
      // final userRow = await _supabase
      //     .from('users')
      //     .select('is_premium')
      //     .eq('id', user.id)
      //     .maybeSingle();
      // _isPremium = userRow?['is_premium'] ?? false;

      // Try designer profile first
      try {
        final data = await _supabase
            .from('designer_profiles')
            .select()
            .eq('user_id', user.id)
            .single();
        if (mounted) {
          setState(() {
            print('designer${data}');
            _profile = DesignerProfile.fromMap(data);
            _profileType = 'designer';
          });
        }
        return;
      } catch (_) {}

      // Try manufacturer profile
      try {
        final data = await _supabase
            .from('manufacturer_profiles')
            .select()
            .eq('user_id', user.id)
            .single();
        if (mounted) {
          setState(() {
            print('manufacturer ${data}');
            _profile = ManufacturerProfile.fromMap(data);
            _profileType = 'manufacturer';
          });
        }
      } catch (e) {
        debugPrint('Error fetching manufacturer profile: $e');
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final userId = user.id;
      List<dynamic> productsData;
      if (_profileType == 'manufacturer'){
        productsData = await _supabase
          .from('designerproducts')
          .select('id')
          .eq('user_id', userId);

      }else{
  productsData = await _supabase
            .from('manufacturerproducts')
            .select('id')
            .eq('user_id', userId);
      }
      // Products — try designerproducts → manufacturerproducts → products
      


      if (productsData.isEmpty) {
        productsData = await _supabase
            .from('products')
            .select('id')
            .eq('user_id', userId);
      }

      if (productsData.isEmpty) {
        if (mounted) setState(() => _totalProducts = 0);
        return;
      }

      final productIds = productsData.map((e) => e['id'].toString()).toList();
      final idsString = '(${productIds.map((id) => '"$id"').join(',')})';

      // Views = credits
      final viewsResponse = await _supabase
          .from('views')
          .select('item_id')
          .filter('item_id', 'in', idsString);

      if (mounted) {
        setState(() {
          _totalProducts = productsData.length;
          _totalCredits = viewsResponse.length;
          _profileViews = viewsResponse.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching metrics: $e');
    }
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  bool get _isManufacturer => _profileType == 'manufacturer';

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PageTemplate(
        title: "Profile",
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final businessName = _profile?.businessName ??
        (_isManufacturer ? 'Manufacturer Account' : 'Designer Account');
    final initial =
        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'M';

    return PageTemplate(
      title: "Profile",
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl
          child: ScrollConfiguration(
  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32)
                .copyWith(bottom: 80),
            children: [
              // ── Header Card ─────────────────────────────────────────────
              _buildHeaderCard(initial, businessName),

              const SizedBox(height: 24),

              // ── Premium / Upgrade Card ───────────────────────────────────
              // Manufacturer never sees this card
              if (!_isManufacturer)
                _isPremium
                    ? _buildPremiumMemberCard()
                    : _buildUpgradeBannerCard(),

              if (!_isManufacturer) const SizedBox(height: 24),

              // ── Account Settings ────────────────────────────────────────
              _buildSettingsCard(),

              const SizedBox(height: 24),

              // ── Sign Out ────────────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout,
                      size: 16, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header Card
  // -------------------------------------------------------------------------

  Widget _buildHeaderCard(String initial, String businessName) {
    return Container(
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
          // Top row: avatar + name + badge + settings
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
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

              // Name + badge
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
                    _buildAccountBadge(),
                  ],
                ),
              ),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Color(0xFF6B7280), size: 20),
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stats row
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
    );
  }

  /// Badge under the name:
  /// - Manufacturer → no badge (manufacturers don't have premium tiers)
  /// - Designer + Premium → gold "Premium Member" badge
  /// - Designer + Free → gray "Free Account" badge (matches HTML reference)
  Widget _buildAccountBadge() {
    if (_isManufacturer) return const SizedBox.shrink();

    if (_isPremium) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFEAB308)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.workspace_premium, size: 12, color: Colors.white),
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
      );
    }

    // Free account — matches HTML: bg-gray-100 text-gray-700
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Free Account',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Upgrade Banner (free designer) — matches HTML reference exactly
  // -------------------------------------------------------------------------

  Widget _buildUpgradeBannerCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF9C3)], // amber-50 → yellow-50
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D), width: 2), // amber-200
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crown icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBBF24), Color(0xFFEAB308)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 24),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock full insights, detailed GEO analytics, and advanced features to grow your business faster.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 24),

                // Feature grid — 2 columns
                LayoutBuilder(builder: (context, constraints) {
                  final twoCol = constraints.maxWidth > 400;
                  final features = [
                    ('Unblurred Insights', 'View complete GEO and demand data'),
                    ('Advanced Analytics', 'Detailed trends and forecasts'),
                    ('Priority Support', 'Get help when you need it'),
                    ('Unlimited Uploads', 'No limits on products'),
                  ];
                  if (twoCol) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildFeatureItem(features[0].$1, features[0].$2)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFeatureItem(features[1].$1, features[1].$2)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildFeatureItem(features[2].$1, features[2].$2)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildFeatureItem(features[3].$1, features[3].$2)),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: features
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildFeatureItem(f.$1, f.$2),
                            ))
                        .toList(),
                  );
                }),

                const SizedBox(height: 24),

                // Upgrade button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFEAB308)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Upgrade Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981), // emerald-500
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Premium Member Card (premium designer only)
  // -------------------------------------------------------------------------

  Widget _buildPremiumMemberCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFEAB308)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Member',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You have access to all features',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Next billing date: January 9, 2026',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
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
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Account Settings Card
  // -------------------------------------------------------------------------

  Widget _buildSettingsCard() {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Account Settings',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827)),
              ),
            ),
          ),
          _buildSettingItem('Edit Profile', 'Update your business information'),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          _buildSettingItem(
              'Notification Preferences', 'Manage your notification settings'),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          _buildSettingItem(
              'Privacy & Security', 'Control your privacy settings'),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          _buildSettingItem('Help & Support', 'Get help with your account'),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Reusable Widgets
  // -------------------------------------------------------------------------

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF059669)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}