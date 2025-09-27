import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart'; // Using the new StyledCard

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // TODO: Fetch initial user data from Supabase based on filter
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Users Management', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () { /* TODO: Implement Add User functionality */ },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add User'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          tabs: const [
            Tab(text: 'Members (Premium)'),
            Tab(text: 'Non-Members (Free)'),
            Tab(text: 'B2B Creators'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserTable('Members'),
              _buildUserTable('Non-Members'),
              _buildUserTable('B2B Creators'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserTable(String userType) {
    // TODO: Fetch data from Supabase for the specific userType
    return StyledCard(
      child: Column(
        children: [
          // The search and filter row for the table
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search in $userType...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // A responsive DataTable
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Joined Date')),
                  DataColumn(label: Text('Actions')),
                ],
                // Placeholder data
                rows: List.generate(15, (index) => DataRow(cells: [
                    DataCell(Text('$userType User ${index + 1}')),
                    DataCell(Text('user${index+1}@email.com')),
                    DataCell(Chip(
                      label: Text(index % 3 == 0 ? 'Inactive' : 'Active'),
                      backgroundColor: (index % 3 == 0 ? Colors.red : Colors.green).withOpacity(0.1),
                      side: BorderSide.none,
                    )),
                    DataCell(Text('2025-09-2${8 - index}')),
                    DataCell(Row(
                      children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, size: 20)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                      ],
                    )),
                ])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}