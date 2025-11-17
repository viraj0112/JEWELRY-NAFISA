import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/creators_provider.dart';
import '../../widgets/creator_card.dart';

class CreatorsSketchTab extends StatelessWidget {
  final List<CreatorModel> creators;
  const CreatorsSketchTab({super.key, required this.creators});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();
    final list = provider.filteredCreators.where((c) {
      final spec = c.businessType.toLowerCase();
      return spec.contains('sketch') ||
          spec.contains('art') ||
          spec.contains('deco') ||
          spec.contains('illustration') ||
          spec.contains('draw');
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: list.isEmpty
          ? const Center(child: Text('No sketch designers found'))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final c = list[idx];
                return CreatorCard(
                  creator: c,
                  // --- ADD THESE LINES ---
                  onApprove: (id) => provider.approveCreator(id),
                  onReject: (id) => provider.rejectCreator(id),
                  // -----------------------
                  onOpenPortfolio: (id) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Open portfolio for $id')));
                  },
                  onEmail: (id) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Email creator $id')));
                  },
                );
              },
            ),
    );
  }
}
