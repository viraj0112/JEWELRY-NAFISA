import 'package:flutter/material.dart';
import '../providers/creators_provider.dart';

typedef VoidString = void Function(String id);

class CreatorCard extends StatelessWidget {
  final CreatorModel creator;
  final VoidString? onApprove;
  final VoidString? onReject;
  final VoidString onOpenPortfolio;
  final VoidString onEmail;
  final VoidCallback? onTap; // Added onTap for showing details

  const CreatorCard({
    super.key,
    required this.creator,
    required this.onOpenPortfolio,
    required this.onEmail,
    this.onApprove,
    this.onReject,
    this.onTap,
  });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _statusText(String s) {
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap, // Trigger detail view
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFDAD7E7),
                child: Text(
                  _initials(creator.fullName),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            creator.fullName, 
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                          )
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusBg(creator.approvalStatus),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusText(creator.approvalStatus), 
                            style: TextStyle(color: _statusColor(creator.approvalStatus), fontWeight: FontWeight.w600)
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${creator.email ?? '-'} • ${creator.location ?? '-'}', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Specialization: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                        Text(creator.businessType, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        Text('Works: ${creator.worksCount}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (creator.approvalStatus.toLowerCase() == 'pending' && onApprove != null)
                    ElevatedButton.icon(
                      onPressed: () => onApprove!(creator.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  if (creator.approvalStatus.toLowerCase() == 'pending' && onReject != null)
                    OutlinedButton.icon(
                      onPressed: () => onReject!(creator.id),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => onOpenPortfolio(creator.id),
                    child: const Text('Portfolio'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green.shade50;
      case 'pending':
        return Colors.orange.shade50;
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  String _initials(String n) {
    final parts = n.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}