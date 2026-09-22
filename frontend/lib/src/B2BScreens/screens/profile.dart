import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/widgets/password_form.dart';
import 'package:jewelry_nafisa/src/auth/password_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/designer_profile.dart';
import 'package:jewelry_nafisa/src/models/manufacturer_profile.dart';
import 'package:jewelry_nafisa/src/widgets/edit_business_profile_dialog.dart';
import 'page_template.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';
import 'package:jewelry_nafisa/src/utils/handbook.dart';

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
  int _totalLikes = 0;

  // Premium — fetched from users table
  final bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // -------------------------------------------------------------------------
  // Data fetching
  // -------------------------------------------------------------------------

  Future<void> _fetchAll() async {
    // Sequential on purpose: the metrics need _profileType (which product
    // table is this user's), and it is only known once the profile loads.
    await _fetchProfile();
    await _fetchMetrics();
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

      // Try designer profile first. maybeSingle(), not single(): having no
      // designer_profiles row is the ordinary case for a manufacturer, and
      // single() reported it by throwing - which the empty catch that used to
      // sit here swallowed along with any real failure (RLS denial, network
      // error), leaving the screen blank with no clue why.
      final designerData = await _supabase
          .from('designer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (designerData != null) {
        if (mounted) {
          setState(() {
            _profile = DesignerProfile.fromMap(designerData);
            _profileType = 'designer';
          });
        }
        return;
      }

      // Otherwise look for a manufacturer profile.
      final manufacturerData = await _supabase
          .from('manufacturer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (manufacturerData != null && mounted) {
        setState(() {
          _profile = ManufacturerProfile.fromMap(manufacturerData);
          _profileType = 'manufacturer';
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchMetrics() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;
    final table = _isManufacturer ? 'manufacturerproducts' : 'designerproducts';

    // Each figure is loaded and shown independently, so one failing query
    // can no longer zero out the others.
    try {
      final live = await _supabase
          .from(table)
          .count(CountOption.exact)
          .eq('user_id', userId);
      // Uploads still awaiting (or refused) approval live in `assets`;
      // approved ones already appear in the product table above.
      final pending = await _supabase
          .from('assets')
          .count(CountOption.exact)
          .eq('owner_id', userId)
          .eq('source', table)
          .neq('status', 'approved');
      if (mounted) setState(() => _totalProducts = live + pending);
    } catch (e) {
      debugPrint('Error counting products: $e');
    }

    try {
      final ids = await _productIds(table, userId);
      final views = await _countEvents('views', table, ids);
      final likes = await _countEvents('likes', table, ids);
      if (mounted) {
        setState(() {
          // A view of a product is what earns it a credit (same figure as the
          // "credits" on the Home cards).
          _totalCredits = views;
          _totalLikes = likes;
        });
      }
    } catch (e) {
      debugPrint('Error counting views/likes: $e');
    }
  }

  /// All of this user's product ids in [table], paged past PostgREST's
  /// 1000-row response cap.
  Future<List<String>> _productIds(String table, String userId) async {
    final ids = <String>[];
    const page = 1000;
    for (var from = 0;; from += page) {
      final rows = await _supabase
          .from(table)
          .select('id')
          .eq('user_id', userId)
          .order('id')
          .range(from, from + page - 1);
      ids.addAll(rows.map((r) => '${r['id']}'));
      if (rows.length < page) break;
    }
    return ids;
  }

  /// Rows in [eventTable] (views / likes) for these products. Events store the
  /// numeric product id as text in `item_id`, scoped by `item_table`.
  Future<int> _countEvents(
      String eventTable, String table, List<String> ids) async {
    var total = 0;
    const chunk = 200; // keeps the IN (...) list well under URL limits
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      total += await _supabase
          .from(eventTable)
          .count(CountOption.exact)
          .eq('item_table', table)
          .inFilter('item_id', part);
    }
    return total;
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  bool get _isManufacturer => _profileType == 'manufacturer';

  void _openEditProfile() {
    if (_profile == null) return;
    showDialog(
      context: context,
      builder: (context) => EditBusinessProfileDialog(
        profile: _profile,
        profileType: _profileType,
        onProfileUpdated: _fetchAll,
      ),
    );
  }

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
      eyebrow: 'Your account',
      title: "Profile",
      subtitle: 'Business details, plan and account security.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 80),
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
                    icon: const Icon(Icons.logout_rounded,
                        size: 17, color: B2BColors.danger),
                    label: Text(
                      'Sign Out',
                      style: B2BText.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: B2BColors.danger,
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
      decoration: b2bCardDecoration(),
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
                    colors: [B2BColors.primary, B2BColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: B2BColors.gold, width: 2),
                  boxShadow: B2BShadows.soft,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: B2BText.serif(size: 32, color: Colors.white),
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
                      style: B2BText.serif(size: 26),
                    ),
                    const SizedBox(height: 8),
                    _buildAccountBadge(),
                  ],
                ),
              ),

              // Settings menu
              PopupMenuButton<String>(
                tooltip: 'Account settings',
                icon: const Icon(Icons.settings_outlined,
                    color: B2BColors.muted, size: 20),
                position: PopupMenuPosition.under,
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      _openEditProfile();
                    case 'password':
                      final saved = await showChangePasswordDialog(context);
                      if (saved && mounted) setState(() {});
                    case 'refresh':
                      setState(() => _isLoading = true);
                      await _fetchAll();
                    case 'handbook':
                      await openHandbook(context);
                    case 'signout':
                      await _signOut();
                  }
                },
                itemBuilder: (context) {
                  final hasPassword = PasswordService.hasPassword(
                      Supabase.instance.client.auth.currentUser);
                  PopupMenuItem<String> item(
                          String value, IconData icon, String label,
                          {Color? color}) =>
                      PopupMenuItem(
                        value: value,
                        child: Row(children: [
                          Icon(icon, size: 18, color: color ?? B2BColors.primary),
                          const SizedBox(width: 12),
                          Text(label,
                              style: B2BText.sans(
                                  size: 14, color: color ?? B2BColors.ink)),
                        ]),
                      );
                  return [
                    item('edit', Icons.storefront_outlined, 'Edit profile'),
                    item('password', Icons.lock_reset_rounded,
                        hasPassword ? 'Reset password' : 'Set a password'),
                    item('refresh', Icons.refresh_rounded, 'Refresh stats'),
                    item('handbook', Icons.menu_book_outlined,
                        'Help & Handbook'),
                    const PopupMenuDivider(),
                    item('signout', Icons.logout_rounded, 'Sign out',
                        color: B2BColors.danger),
                  ];
                },
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
                  icon: Icons.favorite_border_rounded,
                  value: _formatNumber(_totalLikes),
                  label: 'Total Likes',
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
            colors: [Color(0xFFC9A66B), B2BColors.gold],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        color: B2BColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Free Account',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: B2BColors.inkSoft,
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
          colors: [Color(0xFFFCF8F1), B2BColors.goldSoft],
        ),
        borderRadius: BorderRadius.circular(B2BRadius.lg),
        border: Border.all(color: const Color(0xFFE8D9BD)),
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
                colors: [Color(0xFFC9A66B), B2BColors.gold],
              ),
              borderRadius: BorderRadius.circular(B2BRadius.lg),
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 24),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upgrade to Premium', style: B2BText.serif(size: 23)),
                const SizedBox(height: 8),
                const Text(
                  'Unlock full insights, detailed GEO analytics, and advanced features to grow your business faster.',
                  style: TextStyle(fontSize: 14, color: B2BColors.inkSoft),
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
                            Expanded(
                                child: _buildFeatureItem(
                                    features[0].$1, features[0].$2)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildFeatureItem(
                                    features[1].$1, features[1].$2)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildFeatureItem(
                                    features[2].$1, features[2].$2)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildFeatureItem(
                                    features[3].$1, features[3].$2)),
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
                    color: B2BColors.primary,
                    borderRadius: BorderRadius.circular(B2BRadius.md),
                    boxShadow: B2BShadows.soft,
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
            color: B2BColors.primary,
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
                      color: B2BColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: B2BColors.muted)),
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
          colors: [Color(0xFFF3F8F5), B2BColors.primarySoft],
        ),
        borderRadius: BorderRadius.circular(B2BRadius.lg),
        border: Border.all(color: B2BColors.primaryTint),
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
                    colors: [Color(0xFFC9A66B), B2BColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(B2BRadius.md),
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
                          color: B2BColors.ink),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You have access to all features',
                      style: TextStyle(fontSize: 14, color: B2BColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Next billing date: January 9, 2026',
            style: TextStyle(fontSize: 14, color: B2BColors.muted),
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
                  color: B2BColors.primary,
                  fontWeight: FontWeight.w600),
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
      decoration: b2bCardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: B2BColors.border, width: 1)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Account Settings', style: B2BText.serif(size: 20)),
            ),
          ),
          _buildSettingItem('Edit Profile', 'Update your business information',
              icon: Icons.storefront_outlined, onTap: _openEditProfile),
          const Divider(height: 1, thickness: 1, color: B2BColors.border),
          Builder(builder: (context) {
            // Google-created accounts without a password see "Set a password".
            final hasPassword = PasswordService.hasPassword(
                Supabase.instance.client.auth.currentUser);
            return _buildSettingItem(
              hasPassword ? 'Reset password' : 'Set a password',
              hasPassword
                  ? 'Choose a new password for your account'
                  : 'Add a password to sign in with your email',
              icon: Icons.lock_reset_rounded,
              onTap: () async {
                final saved = await showChangePasswordDialog(context);
                if (saved && mounted) setState(() {});
              },
            );
          }),
          // _buildSettingItem(
          //     'Notification Preferences', 'Manage your notification settings'),
          // const Divider(height: 1, thickness: 1, color: B2BColors.surfaceAlt),
          // _buildSettingItem(
          //     'Privacy & Security', 'Control your privacy settings'),
          // const Divider(height: 1, thickness: 1, color: B2BColors.surfaceAlt),
          // _buildSettingItem('Help & Support', 'Get help with your account'),
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
        color: B2BColors.canvas,
        borderRadius: BorderRadius.circular(B2BRadius.md),
        border: Border.all(color: B2BColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: B2BColors.gold),
          const SizedBox(height: 8),
          Text(
            value,
            style: B2BText.serif(size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: B2BColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle,
      {VoidCallback? onTap, IconData? icon}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: B2BColors.primarySoft,
                  borderRadius: BorderRadius.circular(B2BRadius.sm),
                ),
                child: Icon(icon, size: 19, color: B2BColors.primary),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: B2BText.sans(
                          size: 15, weight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: B2BText.sans(size: 13, color: B2BColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: B2BColors.faint),
          ],
        ),
      ),
    );
  }
}
