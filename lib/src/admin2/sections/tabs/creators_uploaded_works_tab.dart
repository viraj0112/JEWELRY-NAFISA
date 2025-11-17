import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/creators_provider.dart';
import '../../widgets/work_card.dart';

class CreatorsUploadedWorksTab extends StatelessWidget {
  final List<WorkModel> works; // We ignore this input effectively and use provider directly for filtering
  final List<CreatorModel> creators;
  
  const CreatorsUploadedWorksTab({super.key, required this.works, required this.creators});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();
    
    // Requirement: "uploaded work will show all approved works"
    final list = provider.approvedWorks; 

    if (list.isEmpty) {
      return const Center(child: Text('No approved works found'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width > 1200) crossAxisCount = 4;
        else if (width > 900) crossAxisCount = 3;
        else if (width > 600) crossAxisCount = 2;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1 / 1.15,
          ),
          itemCount: list.length,
          itemBuilder: (context, idx) {
            final w = list[idx];
            final creator = creators.firstWhere(
              (c) => c.id == w.creatorId, 
              orElse: () => CreatorModel(
                id: 'unknown',
                fullName: 'Unknown',
                email: null,
                avatarUrl: null,
                approvalStatus: 'approved',
                businessType: 'unknown',
                location: null,
                isApproved: false,
                role: 'designer',
                createdAt: DateTime.now(),
              )
            );
            
            return WorkCard(
              work: w,
              creatorName: creator.fullName,
              onTap: () {
                // Simple detail view for works
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: Text(w.title),
                  content: Text('Work by ${creator.fullName}\nCategory: ${w.category}\nStatus: ${w.status}'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                ));
              },
            );
          },
        );
      }),
    );
  }
}