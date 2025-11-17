import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;     // e.g. approved / pending / rejected / published / under_review
  final double? fontSize;
  final EdgeInsets? padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final String normalized = status.toLowerCase().trim();

    final Color bg = _backgroundFor(normalized);
    final Color textColor = _textFor(normalized);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _title(normalized),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: fontSize ?? 13,
        ),
      ),
    );
  }

  // -------------------------------
  // Helpers
  // -------------------------------

  String _title(String s) {
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  Color _backgroundFor(String s) {
    switch (s) {
      case 'approved':
        return Colors.green.shade50;
      case 'pending':
        return Colors.orange.shade50;
      case 'rejected':
        return Colors.red.shade50;
      case 'published':
        return Colors.blue.shade50;
      case 'under_review':
      case 'under review':
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _textFor(String s) {
    switch (s) {
      case 'approved':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade800;
      case 'rejected':
        return Colors.red.shade700;
      case 'published':
        return Colors.blue.shade800;
      case 'under_review':
      case 'under review':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }
}
