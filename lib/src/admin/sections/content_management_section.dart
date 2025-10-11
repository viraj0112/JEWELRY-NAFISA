import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart';

class ContentManagementSection extends StatefulWidget {
  const ContentManagementSection({super.key});

  @override
  State<ContentManagementSection> createState() =>
      _ContentManagementSectionState();
}

class _ContentManagementSectionState extends State<ContentManagementSection>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String assetId, String status) async {
    // Implement the logic to update the asset status in your AdminService
    // For example: await _adminService.updateAssetStatus(assetId, status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product status updated to $status'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Creator Uploads'),
            Tab(text: 'B2B Products'),
            Tab(text: 'Scraped Content'),
            Tab(text: 'User Boards'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUploadedContent(),
              _buildB2BProducts(),
              _buildScrapedContent(),
              _buildUserBoards(),
            ],
          ),
        ),
      ],
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
            child: Text(
              'No content has been uploaded yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
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

  Widget _buildB2BProducts() {
    return StreamBuilder<List<Asset>>(
      stream: _adminService.getB2BProducts(),
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
            child: Text(
              'No B2B products have been uploaded for approval.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return StyledCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Thumbnail')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Creator')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: assets.map((asset) {
              return DataRow(cells: [
                DataCell(Image.network(asset.mediaUrl,
                    width: 40, height: 40, fit: BoxFit.cover)),
                DataCell(Text(asset.title)),
                DataCell(Text(asset.ownerUsername ?? 'N/A')),
                DataCell(Text(asset.ownerEmail ?? 'N/A')),
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
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateStatus(asset.id, 'approved'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateStatus(asset.id, 'rejected'),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildScrapedContent() {
    return StreamBuilder<List<Asset>>(
      stream: _adminService.getScrapedContent(),
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
            child: Text(
              'No scraped content found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return StyledCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Thumbnail')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Scraped Date')),
            ],
            rows: assets.map((asset) {
              return DataRow(cells: [
                DataCell(Image.network(asset.mediaUrl,
                    width: 40, height: 40, fit: BoxFit.cover)),
                DataCell(Text(asset.title)),
                DataCell(Text(asset.source ?? 'N/A')),
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

  Widget _buildUserBoards() {
    return StreamBuilder<List<Board>>(
      stream: _adminService.getBoards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final boards = snapshot.data ?? [];
        if (boards.isEmpty) {
          return const Center(
            child: Text(
              'No user boards have been created yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: boards.length,
          itemBuilder: (context, index) {
            final board = boards[index];
            return Card(
              child: ListTile(
                title: Text(board.name),
                subtitle: Text('Created by: ${board.userId}'),
                trailing: Text(DateFormat.yMMMd().format(board.createdAt)),
              ),
            );
          },
        );
      },
    );
  }
}