import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/creators_provider.dart';
import '../../widgets/creator_card.dart';
import '../../widgets/work_card.dart'; // Used to display mini work cards in dialog

class Creators3DTab extends StatelessWidget {
  final List<CreatorModel> creators;
  const Creators3DTab({super.key, required this.creators});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();
    
    // Filter for 3D artists
    final list = provider.filteredCreators.where((c) {
      final spec = c.businessType.toLowerCase();
      // Also include if they have uploaded 3D models regardless of their self-proclaimed type
      final has3DWork = provider.works.any((w) => w.creatorId == c.id && w.category == '3D Model');
      return spec.contains('3d') || spec.contains('model') || has3DWork;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: list.isEmpty
          ? const Center(child: Text('No 3D artists found'))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final c = list[idx];
                return CreatorCard(
                  creator: c,
                  onApprove: (id) => provider.approveCreator(id),
                  onReject: (id) => provider.rejectCreator(id),
                  onOpenPortfolio: (id) {},
                  onEmail: (id) {},
                  onTap: () => _showSubmissionDetails(context, c, provider),
                );
              },
            ),
    );
  }

  void _showSubmissionDetails(BuildContext context, CreatorModel creator, CreatorsProvider provider) {
    final pendingWorks = provider.getPendingWorksForCreator(creator.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submissions by ${creator.fullName}'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending Approval: ${pendingWorks.length} items', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (pendingWorks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No pending submissions found.'),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: pendingWorks.length,
                    separatorBuilder: (_,__) => const Divider(),
                    itemBuilder: (context, index) {
                      final w = pendingWorks[index];
                      return ListTile(
                        leading: Container(
                          width: 50, height: 50,
                          color: Colors.grey.shade200,
                          child: w.mediaUrl.isNotEmpty 
                             ? Image.network(w.mediaUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.image)) 
                             : const Icon(Icons.image),
                        ),
                        title: Text(w.title),
                        subtitle: Text('Category: ${w.category}\nSubmitted: ${w.createdAt.toIso8601String().split('T')[0]}'),
                        isThreeLine: true,
                        trailing: Chip(label: Text(w.status), backgroundColor: Colors.orange.shade50),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}