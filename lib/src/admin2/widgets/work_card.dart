import 'package:flutter/material.dart';
import '../providers/creators_provider.dart';

class WorkCard extends StatelessWidget {
  final WorkModel work;
  final String creatorName;
  final VoidCallback onTap;

  const WorkCard({super.key, required this.work, required this.creatorName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Center(
                      child: Icon(work.category == '3D Model' ? Icons.threed_rotation : Icons.brush, size: 36, color: Colors.black26),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: _statusBg(work.status), borderRadius: BorderRadius.circular(8)),
                      child: Text(work.status[0].toUpperCase() + work.status.substring(1), style: TextStyle(color: _statusColor(work.status), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(8)),
                      child: Text(work.category, style: const TextStyle(color: Colors.black87)),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(work.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('by $creatorName', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _tiny(Icons.remove_red_eye, '${work.views}'),
                    const SizedBox(width: 12),
                    _tiny(Icons.favorite_border, '${work.saves}'),
                    const SizedBox(width: 12),
                    _tiny(Icons.share_outlined, '${work.shares}'),
                  ],
                )
              ]),
            )
          ],
        ),
      ),
    );
  }

  Widget _tiny(IconData icon, String text) => Row(children: [Icon(icon, size: 14, color: Colors.black54), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.black54, fontSize: 13))]);

  Color _statusBg(String s) {
    if (s.toLowerCase().contains('publish')) return Colors.blue.shade50;
    if (s.toLowerCase().contains('review')) return Colors.orange.shade50;
    return Colors.grey.shade100;
  }

  Color _statusColor(String s) {
    if (s.toLowerCase().contains('publish')) return Colors.blue.shade800;
    if (s.toLowerCase().contains('review')) return Colors.orange.shade800;
    return Colors.black87;
  }
}
