import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/geo_analytics_widget.dart';
import '../../services/geo_analytics_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Designer Geo Analytics Screen
/// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = Supabase.instance.client;

  static const _primary = Color(0xFF0A4F3F);
  static const _accent = Color(0xFFD4AF37);
  static const _bgPage = Color(0xFFF3F5F4);

  bool _isLoading = true;
  String? _errorMessage;
  GeoAnalyticsData _data = GeoAnalyticsData.empty;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final productIds =
          await GeoAnalyticsService.getDesignerProductIds(user.id);

      if (productIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _data = GeoAnalyticsData.empty;
        });
        return;
      }

      final data =
          await GeoAnalyticsService.fetchGeoData(productIds: productIds);

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching designer analytics: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load analytics';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text('Loading analytics...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_data.totalViews == 0 &&
        _data.totalLikes == 0 &&
        _data.totalShares == 0 &&
        _data.totalSaves == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No analytics data yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics will appear here once your products\nreceive views, likes, shares, or saves.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: GeoAnalyticsWidget(
          data: _data,
          title: 'Designer Analytics',
          subtitle:
              'Analyze views, likes, shares and saves of your products by country, state and pincode.',
          primaryColor: _primary,
          accentColor: _accent,
        ),
      ),
    );
  }
}
