import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart'; // Using StyledCard

class B2BCreatorsSection extends StatefulWidget {
  const B2BCreatorsSection({super.key});

  @override
  State<B2BCreatorsSection> createState() => _B2BCreatorsSectionState();
}

class _B2BCreatorsSectionState extends State<B2BCreatorsSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('B2B Creators Management', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          tabs: const [
            Tab(text: 'Profile Approval Queue'),
            Tab(text: 'Creator Directory'),
            Tab(text: 'Uploaded Content'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildApprovalQueue(),
              _buildCreatorDirectory(),
              _buildUploadedContent(),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 1: Profile Approval Queue ---
  Widget _buildApprovalQueue() {
    // TODO: Fetch creators awaiting approval from Supabase
    final pendingCreators = [
      {'name': 'Helena Wren', 'skills': '3D Modeling, Sketching', 'date': '2025-09-26'},
      {'name': 'Leo Rivera', 'skills': 'Sketch Design', 'date': '2025-09-25'},
    ];

    return StyledCard(
      child: ListView.separated(
        itemCount: pendingCreators.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final creator = pendingCreators[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(creator['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(creator['skills']!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () {}, child: const Text('Approve')),
                const SizedBox(width: 8),
                TextButton(onPressed: () {}, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Reject')),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: Creator Directory ---
  Widget _buildCreatorDirectory() {
    // TODO: Fetch all approved creators from Supabase
    return StyledCard(
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, skill, or region...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Skills')),
                  DataColumn(label: Text('Region')),
                  DataColumn(label: Text('Works')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: List.generate(8, (index) => DataRow(cells: [
                    const DataCell(Text('Approved Creator')),
                    const DataCell(Text('3D Modeling')),
                    const DataCell(Text('USA')),
                    const DataCell(Text('24')),
                    DataCell(IconButton(onPressed: (){}, icon: const Icon(Icons.visibility_outlined))),
                ])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Uploaded Content Status ---
  Widget _buildUploadedContent() {
    // TODO: Fetch creators' uploaded content from Supabase
    return StyledCard(
      child: Column(
        children: [
           const TextField(
            decoration: InputDecoration(
              hintText: 'Search by creator or content title...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
           const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Creator')),
                  DataColumn(label: Text('Content Title')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Upload Date')),
                ],
                rows: List.generate(12, (index) {
                  final status = index % 3 == 0 ? 'Flagged' : (index % 3 == 1 ? 'Live' : 'Draft');
                  final color = index % 3 == 0 ? Colors.red : (index % 3 == 1 ? Colors.green : Colors.grey);
                  return DataRow(cells: [
                    const DataCell(Text('Creator Name')),
                    const DataCell(Text('Elegant Diamond Ring')),
                    DataCell(Chip(label: Text(status), backgroundColor: color.withOpacity(0.1), side: BorderSide.none)),
                    const DataCell(Text('2025-09-20')),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}