import 'package:flutter/material.dart';

class CreatorsTabs extends StatelessWidget {
  final String selected;
  final Function(String) onSelect;
  const CreatorsTabs({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _tab('3d', '3D Artists', Icons.palette_outlined),
          const SizedBox(width: 8),
          _tab('sketch', 'Sketch Designers', Icons.brush_outlined),
          const SizedBox(width: 8),
          _tab('works', 'Uploaded Works', Icons.cloud_upload_outlined),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _tab(String key, String label, IconData icon) {
    final active = key == selected;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? Colors.black87 : Colors.black54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.black87 : Colors.black54)),
          ],
        ),
      ),
    );
  }
}
