// Reusable UI Components for Analytics Section
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String description;
  final List<Color> gradientColors;
  final VoidCallback? onExport;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    required this.description,
    required this.gradientColors,
    this.onExport,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onExport != null) ...[
            const SizedBox(width: 12),
            IconButton(
              onPressed: onExport,
              icon: const Icon(
                FontAwesomeIcons.download,
                size: 16,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final Border? border;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.shadows,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border,
        boxShadow: shadows ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FilterBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;

  const FilterBar({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: padding,
      backgroundColor: Colors.grey.shade50,
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: children,
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyle? style;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.style,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                    Text(text),
                  ],
                )
              : Text(text),
    );
  }
}

class SortableTableHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool isSorted;
  final bool sortAscending;

  const SortableTableHeader({
    super.key,
    required this.title,
    this.onTap,
    this.isSorted = false,
    this.sortAscending = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;
  final Color? trendColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
    this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: color.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        trend!.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: trendColor ?? (trend!.startsWith('+') ? Colors.green : Colors.red),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: trendColor ?? (trend!.startsWith('+') ? Colors.green : Colors.red),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EngagementIcon extends StatelessWidget {
  final String type;
  final Color? color;

  const EngagementIcon({
    super.key,
    required this.type,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = color ?? _getColorForType(type);
    IconData iconData = _getIconForType(type);

    return Icon(iconData, color: iconColor, size: 16);
  }

  static Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'views':
        return Colors.grey.shade400;
      case 'likes':
        return Colors.red.shade400;
      case 'comments':
        return Colors.blue.shade400;
      case 'saves':
        return Colors.amber.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  static IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'views':
        return FontAwesomeIcons.eye;
      case 'likes':
        return FontAwesomeIcons.heart;
      case 'comments':
        return FontAwesomeIcons.comment;
      case 'saves':
        return FontAwesomeIcons.bookmark;
      default:
        return FontAwesomeIcons.eye;
    }
  }
}

class ProbabilityBadge extends StatelessWidget {
  final int probability;

  const ProbabilityBadge({
    super.key,
    required this.probability,
  });

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor) = _getProbabilityColors();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$probability% likely',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color backgroundColor, Color textColor) _getProbabilityColors() {
    if (probability > 80) {
      return (Colors.green.shade100, Colors.green.shade800);
    } else if (probability >= 70) {
      return (Colors.amber.shade100, Colors.amber.shade800);
    } else {
      return (Colors.orange.shade100, Colors.orange.shade800);
    }
  }
}

class CustomTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabChanged;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color? color;
  final double height;
  final String? label;

  const ProgressBar({
    super.key,
    required this.value,
    required this.maxValue,
    this.color,
    this.height = 8,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue * 100).clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!),
              Text('${percentage.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: height,
              width: percentage / 100 * (context.screenWidth - 48),
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

extension _ScreenWidth on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
}