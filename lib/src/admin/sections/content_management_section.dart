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

class _ContentManagementSectionState extends State<ContentManagementSection> {
  final AdminService _adminService = AdminService();
  // FIX: Changed from Future to Stream
  late Stream<List<Asset>> _assetsStream;

  @override
  void initState() {
    super.initState();
    // FIX: Assign the stream from the service
    _assetsStream = _adminService.getUploadedContent();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Changed from FutureBuilder to StreamBuilder
    return StreamBuilder<List<Asset>>(
      stream: _assetsStream,
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
                    // FIX: Added dynamic color based on status
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