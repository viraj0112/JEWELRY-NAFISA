import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'chart_card.dart';

class GeoMapWidget extends StatefulWidget {
  const GeoMapWidget({super.key});

  @override
  State<GeoMapWidget> createState() => _GeoMapWidgetState();
}

class _GeoMapWidgetState extends State<GeoMapWidget> {
  String selectedCountry = 'Global';
  String selectedPeriod = '30d';

  final List<Map<String, dynamic>> topCountries = [
    {
      'country': 'United States',
      'flag': '🇺🇸',
      'users': 12450,
      'percentage': 45.2,
      'change': '+12.3%',
      'isPositive': true,
    },
    {
      'country': 'United Kingdom',
      'flag': '🇬🇧',
      'users': 8920,
      'percentage': 32.4,
      'change': '+8.7%',
      'isPositive': true,
    },
    {
      'country': 'Canada',
      'flag': '🇨🇦',
      'users': 3240,
      'percentage': 11.8,
      'change': '+15.2%',
      'isPositive': true,
    },
    {
      'country': 'Australia',
      'flag': '🇦🇺',
      'users': 1890,
      'percentage': 6.9,
      'change': '+5.4%',
      'isPositive': true,
    },
    {
      'country': 'Germany',
      'flag': '🇩🇪',
      'users': 980,
      'percentage': 3.6,
      'change': '-2.1%',
      'isPositive': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ChartCard(
      title: 'Geographic Distribution',
      subtitle: 'User locations and engagement by region',
      showViewDetails: true,
      onViewDetails: () {
        // Navigate to detailed geographic analytics
      },
      actions: [
        _buildPeriodSelector(),
        const SizedBox(width: 8),
        _buildCountrySelector(),
      ],
      chart: Column(
        children: [
          // World map visualization (simplified with colored regions)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Stack(
              children: [
                // Background map representation
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade50,
                        Colors.purple.shade50,
                      ],
                    ),
                  ),
                ),
                // Overlay with country activity indicators
                Positioned(
                  left: 60,
                  top: 80,
                  child: _buildActivityDot('🇺🇸', 45.2),
                ),
                Positioned(
                  left: 180,
                  top: 60,
                  child: _buildActivityDot('🇬🇧', 32.4),
                ),
                Positioned(
                  left: 80,
                  top: 40,
                  child: _buildActivityDot('🇨🇦', 11.8),
                ),
                Positioned(
                  right: 40,
                  bottom: 40,
                  child: _buildActivityDot('🇦🇺', 6.9),
                ),
                Positioned(
                  left: 200,
                  top: 80,
                  child: _buildActivityDot('🇩🇪', 3.6),
                ),
                // Center info
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Global Reach',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '127 Countries',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Top countries list
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Countries',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              ...topCountries.take(5).map((country) => _buildCountryRow(country)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDot(String flag, double percentage) {
    return Container(
      width: percentage * 0.8 + 20, // Size based on percentage
      height: percentage * 0.8 + 20,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          flag,
          style: TextStyle(
            fontSize: percentage * 0.3 + 8,
          ),
        ),
      ),
    );
  }

  Widget _buildCountryRow(Map<String, dynamic> country) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            country['flag'],
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country['country'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${country['users'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} users',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${country['percentage']}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    country['isPositive'] 
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                    size: 10,
                    color: country['isPositive'] 
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    country['change'],
                    style: TextStyle(
                      fontSize: 10,
                      color: country['isPositive'] 
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return PopupMenuButton<String>(
      initialValue: selectedPeriod,
      onSelected: (value) {
        setState(() {
          selectedPeriod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedPeriod,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'today', child: Text('Today')),
        const PopupMenuItem(value: '7d', child: Text('7 days')),
        const PopupMenuItem(value: '30d', child: Text('30 days')),
        const PopupMenuItem(value: '90d', child: Text('90 days')),
      ],
    );
  }

  Widget _buildCountrySelector() {
    return PopupMenuButton<String>(
      initialValue: selectedCountry,
      onSelected: (value) {
        setState(() {
          selectedCountry = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCountry,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Global', child: Text('Global')),
        const PopupMenuItem(value: 'United States', child: Text('United States')),
        const PopupMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
        const PopupMenuItem(value: 'Canada', child: Text('Canada')),
        const PopupMenuItem(value: 'Australia', child: Text('Australia')),
      ],
    );
  }
}