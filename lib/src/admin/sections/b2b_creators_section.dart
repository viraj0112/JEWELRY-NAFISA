import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart';

class B2BCreatorsSection extends StatefulWidget {
  const B2BCreatorsSection({super.key});

  @override
  State<B2BCreatorsSection> createState() => _B2BCreatorsSectionState();
}

class _B2BCreatorsSectionState extends State<B2BCreatorsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();

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
        Text('B2B Creators Management',
            style:
                GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
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

  Widget _buildApprovalQueue() {
    return FutureBuilder<List<AppUser>>(
      future: _adminService.getPendingCreators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final pendingCreators = snapshot.data ?? [];
        if (pendingCreators.isEmpty) {
          return const Center(child: Text('No pending approvals.'));
        }

        return StyledCard(
          child: ListView.separated(
            itemCount: pendingCreators.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final creator = pendingCreators[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(creator.username ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(creator.email ?? 'No Email'),
                trailing: Wrap(
                  spacing: 4.0,
                  children: [
                    TextButton(
                        onPressed: () => _updateStatus(creator.id, 'approved'),
                        child: const Text('Approve')),
                    TextButton(
                      onPressed: () => _updateStatus(creator.id, 'rejected'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _updateStatus(String userId, String status) async {
    try {
      await _adminService.updateCreatorStatus(userId, status);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Creator status updated to $status.'),
          backgroundColor: Colors.green));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red));
    }
  }

  Widget _buildCreatorDirectory() {
    return FutureBuilder<List<AppUser>>(
      future: _adminService.getApprovedCreators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final creators = snapshot.data ?? [];
        if (creators.isEmpty) {
          return const Center(child: Text('No approved creators found.'));
        }

        return StyledCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Business Name')),
              DataColumn(label: Text('Joined Date')),
            ],
            rows: creators.map((creator) {
              return DataRow(cells: [
                DataCell(Text(creator.username ?? 'N/A')),
                DataCell(Text(creator.email ?? 'No Email')),
                DataCell(Text(creator.businessName ?? 'N/A')),
                DataCell(Text(DateFormat.yMMMd().format(creator.createdAt))),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildUploadedContent() {
    return FutureBuilder<List<Asset>>(
      future: _adminService.getUploadedContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return const Center(child: Text('No content uploaded yet.'));
        }

        return StyledCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Thumbnail')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Creator')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Upload Date')),
            ],
            rows: assets.map((asset) {
              return DataRow(cells: [
                DataCell(Image.network(asset.mediaUrl,
                    width: 40, height: 40, fit: BoxFit.cover)),
                DataCell(Text(asset.title)),
                DataCell(Text(asset.ownerUsername ?? 'N/A')),
                DataCell(Chip(
                    label: Text(asset.status),
                    backgroundColor: Colors.orange.withOpacity(0.1))),
                DataCell(Text(DateFormat.yMMMd().format(asset.createdAt))),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}
