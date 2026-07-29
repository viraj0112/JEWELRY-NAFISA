import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/creators_provider.dart';

typedef VoidString = void Function(String id);

class CreatorCard extends StatelessWidget {
  final CreatorModel creator;
  final VoidString? onApprove;
  final VoidString? onReject;
  final VoidCallback onOpenPortfolio;
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
    final hasDocs = (creator.workFileUrl?.isNotEmpty ?? false) ||
        (creator.businessCardUrl?.isNotEmpty ?? false);

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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
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
                            child: Text(creator.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusBg(creator.approvalStatus),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(_statusText(creator.approvalStatus),
                              style: TextStyle(
                                  color: _statusColor(creator.approvalStatus),
                                  fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${creator.email ?? '-'} • ${creator.location ?? '-'}',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Specialization: ',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54)),
                        Text(creator.businessType,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        Text('Works: ${creator.worksCount}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (creator.approvalStatus.toLowerCase() == 'pending' &&
                      onApprove != null)
                    ElevatedButton.icon(
                      onPressed: () => onApprove!(creator.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  if (creator.approvalStatus.toLowerCase() == 'pending' &&
                      onReject != null)
                    OutlinedButton.icon(
                      onPressed: () => onReject!(creator.id),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: hasDocs ? onOpenPortfolio : null,
                    icon: Icon(
                      hasDocs
                          ? Icons.folder_open_outlined
                          : Icons.folder_off_outlined,
                      size: 16,
                    ),
                    label: Text(hasDocs ? 'View Docs' : 'No Docs'),
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

  /// Shows a dialog with the creator's uploaded signup documents.
  static void showDocumentsDialog(BuildContext context, CreatorModel creator) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 680,
          constraints: const BoxConstraints(maxHeight: 550),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFDAD7E7),
                    child: Text(
                      _initialsStatic(creator.fullName),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(creator.fullName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(
                          '${creator.email ?? ''} • ${creator.role.toUpperCase()}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6C7C76)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text('Signup Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DocCard(
                          label: 'Portfolio / Work File',
                          icon: Icons.folder_outlined,
                          url: creator.workFileUrl,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DocCard(
                          label: 'Business Card',
                          icon: Icons.contact_mail_outlined,
                          url: creator.businessCardUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initialsStatic(String n) {
    final parts = n.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Reusable card for previewing a single document (image or file link).
class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String? url;

  bool get _isImage {
    if (url == null) return false;
    final lower = url!.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = url?.isNotEmpty ?? false;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUrl ? const Color(0xFFD0DDD7) : const Color(0xFFE8E8E8),
        ),
        color: hasUrl ? Colors.white : const Color(0xFFF5F5F5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasUrl ? const Color(0xFFE8F5EE) : const Color(0xFFF0F0F0),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: hasUrl
                        ? const Color(0xFF0A4F3F)
                        : const Color(0xFF9E9E9E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasUrl
                            ? const Color(0xFF0A4F3F)
                            : const Color(0xFF9E9E9E),
                      )),
                ),
                if (hasUrl)
                  const Icon(Icons.check_circle,
                      size: 16, color: Color(0xFF1B7A59)),
              ],
            ),
          ),
          if (!hasUrl)
            Container(
              height: 140,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 32, color: Color(0xFFBDBDBD)),
                  SizedBox(height: 6),
                  Text('Not uploaded',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ],
              ),
            )
          else if (_isImage)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(11)),
              child: Stack(
                children: [
                  Image.network(
                    url!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: const Color(0xFFF5F5F5),
                      alignment: Alignment.center,
                      child: const Text('Failed to load',
                          style: TextStyle(color: Color(0xFF9E9E9E))),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => launchUrl(Uri.parse(url!),
                            mode: LaunchMode.externalApplication),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.open_in_new,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () => launchUrl(Uri.parse(url!),
                  mode: LaunchMode.externalApplication),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(11)),
              child: Container(
                height: 140,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_drive_file_outlined,
                        size: 32, color: Color(0xFF0A4F3F)),
                    SizedBox(height: 6),
                    Text('Tap to open document',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A4F3F),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

