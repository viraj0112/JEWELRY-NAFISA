import 'package:flutter/material.dart';
import 'chart_card.dart';

class ConversionFunnelWidget extends StatefulWidget {
  const ConversionFunnelWidget({super.key});

  @override
  State<ConversionFunnelWidget> createState() => _ConversionFunnelWidgetState();
}

class _ConversionFunnelWidgetState extends State<ConversionFunnelWidget> {
  String selectedPeriod = '30d';
  bool comparePeriod = false;

  final List<Map<String, dynamic>> funnelData = [
    {
      'stage': 'Signups',
      'count': 1000,
      'percentage': 100,
      'lastWeek': 950,
      'lastWeekPercentage': 100,
      'color': const Color(0xFF10B981),
    },
    {
      'stage': 'Credit Use',
      'count': 750,
      'percentage': 75,
      'lastWeek': 690,
      'lastWeekPercentage': 73,
      'color': const Color(0xFFF59E0B),
    },
    {
      'stage': 'Membership',
      'count': 280,
      'percentage': 28,
      'lastWeek': 240,
      'lastWeekPercentage': 25,
      'color': const Color(0xFF8B5CF6),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ChartCard(
      title: 'Conversion Funnel',
      subtitle: 'User journey from signup to membership',
      actions: [
        _buildCompareToggle(),
        const SizedBox(width: 8),
        _buildPeriodSelector(),
      ],
      chart: Column(
        children: [
          // Funnel visualization
          Container(
            height: 200,
            child: _buildFunnelChart(),
          ),
          const SizedBox(height: 20),
          // Funnel stages
          Column(
            children: funnelData.map((stage) => _buildFunnelStage(stage)).toList(),
          ),
          const SizedBox(height: 16),
          // Bottom summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      children: [
                        const TextSpan(text: 'Overall conversion rate: '),
                        TextSpan(
                          text: '28%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (comparePeriod) ...[
                          const TextSpan(text: ' (vs '),
                          const TextSpan(
                            text: '25%',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const TextSpan(text: ' last week)'),
                        ],
                      ],
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

  Widget _buildFunnelChart() {
    return Stack(
      children: [
        // Background funnel shape
        CustomPaint(
          size: const Size(double.infinity, 200),
          painter: FunnelPainter(funnelData: funnelData),
        ),
        // Stage labels overlaid on funnel
        ...funnelData.asMap().entries.map((entry) {
          final index = entry.key;
          final stage = entry.value;
          final topOffset = 20.0 + (index * 60.0);
          
          return Positioned(
            left: 20,
            top: topOffset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                stage['stage'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFunnelStage(Map<String, dynamic> stage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: stage['color'],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stage['stage'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stage['count'].toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${stage['percentage']}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (comparePeriod) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  Text(
                    'Last week:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stage['lastWeek'].toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${stage['lastWeekPercentage']}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompareToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          comparePeriod = !comparePeriod;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: comparePeriod ? Theme.of(context).primaryColor : Colors.transparent,
          border: Border.all(
            color: comparePeriod ? Theme.of(context).primaryColor : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              comparePeriod ? Icons.toggle_on : Icons.toggle_off,
              size: 16,
              color: comparePeriod ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              'Compare',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: comparePeriod ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
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
}

class FunnelPainter extends CustomPainter {
  final List<Map<String, dynamic>> funnelData;

  FunnelPainter({required this.funnelData});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final stageHeight = size.height / funnelData.length;
    
    for (int i = 0; i < funnelData.length; i++) {
      final stage = funnelData[i];
      final percentage = stage['percentage'] / 100.0;
      final color = stage['color'] as Color;
      
      paint.color = color.withOpacity(0.8);
      
      final topY = i * stageHeight;
      final bottomY = (i + 1) * stageHeight;
      
      // Calculate widths based on percentage
      final topWidth = size.width * percentage;
      final bottomWidth = i < funnelData.length - 1 
        ? size.width * (funnelData[i + 1]['percentage'] / 100.0)
        : size.width * percentage * 0.8;
      
      // Create trapezoid path
      final path = Path();
      path.moveTo((size.width - topWidth) / 2, topY);
      path.lineTo((size.width + topWidth) / 2, topY);
      path.lineTo((size.width + bottomWidth) / 2, bottomY);
      path.lineTo((size.width - bottomWidth) / 2, bottomY);
      path.close();
      
      canvas.drawPath(path, paint);
      
      // Draw border
      paint
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}