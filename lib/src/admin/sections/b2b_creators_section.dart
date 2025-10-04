import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';
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

  Future<void> _updateStatus(String userId, String status) async {
    try {
      await _adminService.updateCreatorStatus(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Creator status updated to $status.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red));
      }
    }
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
            Tab(text: 'Approval Queue'),
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
    return StreamBuilder<List<AppUser>>(
      stream: _adminService.getPendingCreators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final pendingCreators = snapshot.data ?? [];
        if (pendingCreators.isEmpty) {
          return const Center(
              child: Text('No pending approvals.',
                  style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingCreators.length,
          itemBuilder: (context, index) {
            final creator = pendingCreators[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(creator.businessName ?? creator.username ?? 'N/A'),
                subtitle: Text(creator.email ?? 'No Email'),
                trailing: Wrap(
                  spacing: 8.0,
                  children: [
                    ElevatedButton(
                      onPressed: () => _updateStatus(creator.id, 'approved'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Approve'),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateStatus(creator.id, 'rejected'),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreatorDirectory() {
    // Note: This now uses a default FilterState. You might want to connect this
    // to your global filter provider later.
    return StreamBuilder<List<AppUser>>(
      stream: _adminService.getUsers(
        userType: 'B2B Creators',
        filterState: FilterState.defaultFilters().copyWith(status: 'approved'),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final creators = snapshot.data ?? [];
        if (creators.isEmpty) {
          return const Center(
              child: Text('No approved creators found.',
                  style: TextStyle(color: Colors.grey)));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
    return StreamBuilder<List<Asset>>(
      stream: _adminService.getUploadedContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final assets = snapshot.data ?? [];
        if (assets.isEmpty) {
          return const Center(
              child: Text('No content uploaded yet.',
                  style: TextStyle(color: Colors.grey)));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                DataCell(
                  Chip(
                    label: Text(
                      asset.status,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: asset.status == 'approved'
                        ? Colors.green
                        : asset.status == 'pending'
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                DataCell(Text(DateFormat.yMMMd().format(asset.createdAt))),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}