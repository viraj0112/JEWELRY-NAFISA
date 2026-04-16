import 'dart:math' as math;

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';
import '../widgets/admin_skeletons.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.items,
    required this.searchQuery,
    required this.dateFormat,
    required this.dataService,
    required this.onRefreshRequested,
  });

  final List<InventoryItem> items;
  final String searchQuery;
  final DateFormat dateFormat;
  final NewAdminDataService dataService;
  final VoidCallback onRefreshRequested;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _busyManual = false;
  bool _busyBulk = false;
  late Future<List<InventoryItem>> _activityLogFuture;
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _refreshActivityLog();
  }

  void _refreshActivityLog() {
    _activityLogFuture = widget.dataService.fetchContentActivityLog(limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.category,
        item.status,
        item.source,
        item.ownerName,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    final featured = filtered.take(2).toList();
    final health = _inventoryHealth(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Curation Hub',
          style: TextStyle(fontSize: 46, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage your collection across the marketplace. Upload new pieces via bulk ledger or craft bespoke product pages manually.',
          style: TextStyle(color: Color(0xFF5D6D67)),
        ),
        if (_selectedItemIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCE0D8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1B7A59), size: 18),
                const SizedBox(width: 10),
                Text(
                  '${_selectedItemIds.length} items selected',
                  style: const TextStyle(
                    color: Color(0xFF0A4F3F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedItemIds.clear()),
                  child: const Text('Clear Selection'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  _manualEntryCard(),
                  const SizedBox(height: 12),
                  _bulkUploadCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _manualEntryCard()),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _bulkUploadCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Marketplace Featured Content',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: _showHistoryDialog,
              icon: const Icon(Icons.history, size: 16, color: Color(0xFF3C5A52)),
              label: const Text(
                'History',
                style: TextStyle(
                  color: Color(0xFF3C5A52),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  ...featured.map(_featuredCard),
                  const SizedBox(height: 10),
                  _faqCard(),
                  const SizedBox(height: 10),
                  _healthCard(health),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Row(
                    children: [
                      Expanded(child: featured.isNotEmpty ? _featuredCard(featured[0]) : _emptyFeatureCard()),
                      const SizedBox(width: 10),
                      Expanded(child: featured.length > 1 ? _featuredCard(featured[1]) : _emptyFeatureCard()),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _faqCard(),
                      const SizedBox(height: 10),
                      _healthCard(health),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<InventoryItem>>(
          future: _activityLogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AdminSkeletonView(variant: AdminSkeletonVariant.table);
            }
            if (snapshot.hasError) {
              return Text('Failed to load activity log: ${snapshot.error}');
            }
            final activityItems = snapshot.data ?? const <InventoryItem>[];
            return _activityLog(activityItems);
          },
        ),
      ],
    );
  }

  Widget _manualEntryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E7E4)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFBDECD5),
                child: Icon(Icons.add_circle, color: Color(0xFF0A4F3F)),
              ),
              Spacer(),
              Text(
                'SINGLE ASSET',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF44635A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Manual Product Entry',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hand-crafted entry for unique, high-value gemstones and bespoke jewelry. Add detailed photography, carat metrics, and historical provenance.',
            style: TextStyle(color: Color(0xFF5D6D67)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busyManual ? null : _showManualEntryDialog,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(_busyManual ? 'Saving...' : 'Start Entry'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF034033),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _showDraftsDialog,
                child: const Text('View Drafts'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bulkUploadCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF012F26),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE9C96E),
                child: Icon(Icons.cloud_upload, color: Color(0xFF133226)),
              ),
              Spacer(),
              Text(
                'AUTOMATION',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEAD08F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Bulk Upload (CSV)',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import high-volume inventory updates. Ideal for seasonal collection launches and stock adjustments across branches.',
            style: TextStyle(color: Color(0xFFBDD3C9)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _busyBulk ? null : _importCsvAndUpload,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1E6B58), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.file_upload, color: Color(0xFFEAD08F)),
                  const SizedBox(height: 6),
                  Text(
                    _busyBulk ? 'Processing CSV...' : 'Drop CSV or click to process',
                    style: const TextStyle(color: Color(0xFFC5DBD1), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busyBulk ? null : _importCsvAndUpload,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE9C96E),
                foregroundColor: const Color(0xFF133226),
              ),
              child: Text(_busyBulk ? 'Processing...' : 'Process Batch Ledger'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredCard(InventoryItem item) {
    final image = item.thumbUrl?.isNotEmpty == true ? item.thumbUrl! : (item.mediaUrl ?? '');
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFDDE4E0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFDDE4E0)),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF032E26).withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.source.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE9C96E),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.status} • ${item.ownerName}',
                        style: const TextStyle(color: Color(0xFFB6CEC4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1A5A49),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    color: Colors.white,
                    onPressed: () => _showItemActions(item),
                    icon: const Icon(Icons.edit),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFeatureCard() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEEB),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text('No featured content'),
    );
  }

  Widget _faqCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz, color: Color(0xFF0A4F3F)),
              Spacer(),
              Text('CONTENT MODULE', style: TextStyle(fontSize: 10, color: Color(0xFF6D7E77))),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Global FAQ Manager', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'Manage shipping policies, appraisal standards, and authentication protocols.',
            style: TextStyle(color: Color(0xFF61726C)),
          ),
          const SizedBox(height: 8),
          _faqRow('Shipping & Logistics'),
          _faqRow('Appraisal Criteria'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _manageFaq,
              child: const Text('Manage FAQ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqRow(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }

  Widget _healthCard(double health) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFECD17E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INVENTORY HEALTH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '${health.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: Color(0xFF2A2A2A)),
          ),
          const Text('Catalog integrity', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: health / 100,
            minHeight: 6,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF034033)),
          ),
        ],
      ),
    );
  }

  Widget _activityLog(List<InventoryItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Content Activity Log',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: _showAllActivityDialog,
                child: const Text('View all'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _downloadInventoryCsv(items),
                icon: const Icon(Icons.download, size: 16),
                label: Text(_selectedItemIds.isEmpty
                    ? 'Download CSV'
                    : 'Download Selected (${_selectedItemIds.length})'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE9C869),
                  foregroundColor: const Color(0xFF2F2B1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return Column(
                  children: items
                      .take(5)
                      .map((item) => _buildInventoryMobileTile(item))
                      .toList(),
                );
              }
              return _buildLogTable(items.take(5).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogTable(List<InventoryItem> rows) {
    if (rows.isEmpty) return const Text('No content activity yet.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: [
          DataColumn(
            label: Checkbox(
              value: rows.isNotEmpty &&
                  _selectedItemIds.length >= rows.length &&
                  rows.every((item) => _selectedItemIds.contains(item.id)),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedItemIds.addAll(rows.map((item) => item.id));
                  } else {
                    _selectedItemIds.removeAll(rows.map((item) => item.id));
                  }
                });
              },
            ),
          ),
          const DataColumn(label: Text('Asset Name')),
          const DataColumn(label: Text('Table')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Modified By')),
          const DataColumn(label: Text('Created')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: rows
            .map(
              (item) => DataRow(
                selected: _selectedItemIds.contains(item.id),
                onSelectChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(item.id);
                    } else {
                      _selectedItemIds.remove(item.id);
                    }
                  });
                },
                cells: [
                  DataCell(
                    Checkbox(
                      value: _selectedItemIds.contains(item.id),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedItemIds.add(item.id);
                          } else {
                            _selectedItemIds.remove(item.id);
                          }
                        });
                      },
                    ),
                  ),
                  DataCell(Text('${item.title} (#${item.id.substring(0, item.id.length.clamp(0, 8))})')),
                  DataCell(Text(item.source)),
                  DataCell(_statusChip(item.status)),
                  DataCell(Text(item.ownerName)),
                  DataCell(
                    Text(
                      item.createdAt == null ? '-' : widget.dateFormat.format(item.createdAt!),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      onPressed: () => _showItemActions(item),
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInventoryMobileTile(InventoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _selectedItemIds.contains(item.id),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedItemIds.add(item.id);
                } else {
                  _selectedItemIds.remove(item.id);
                }
              });
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF153F34),
                  ),
                ),
                Text(
                  '#${item.id.substring(0, item.id.length.clamp(0, 8))}',
                  style: const TextStyle(color: Color(0xFF61706A), fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      item.source.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B7A59),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    _statusChip(item.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF5E6F68)),
                    const SizedBox(width: 4),
                    Text(
                      item.ownerName,
                      style: const TextStyle(color: Color(0xFF5E6F68), fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      item.createdAt == null ? '-' : widget.dateFormat.format(item.createdAt!),
                      style: const TextStyle(color: Color(0xFF5E6F68), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    Color bg;
    Color fg;
    if (normalized == 'approved' || normalized == 'published') {
      bg = const Color(0xFFDDF4E8);
      fg = const Color(0xFF1E6B42);
    } else if (normalized == 'pending' || normalized == 'review') {
      bg = const Color(0xFFFFF1CE);
      fg = const Color(0xFF8A6200);
    } else {
      bg = const Color(0xFFE8ECEA);
      fg = const Color(0xFF4F605A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _showManualEntryDialog() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final mediaCtrl = TextEditingController();
    final thumbCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Product Entry'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: mediaCtrl,
                  decoration: const InputDecoration(labelText: 'Media URL'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: thumbCtrl,
                  decoration: const InputDecoration(labelText: 'Thumb URL (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !mounted) return;

    setState(() => _busyManual = true);
    try {
      await widget.dataService.createInventoryAsset(
        title: titleCtrl.text.trim(),
        category: categoryCtrl.text.trim().isEmpty ? 'General' : categoryCtrl.text.trim(),
        description: descCtrl.text.trim(),
        mediaUrl: mediaCtrl.text.trim(),
        thumbUrl: thumbCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory entry created successfully')),
      );
      widget.onRefreshRequested();
      setState(_refreshActivityLog);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create entry: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyManual = false);
    }
  }

  Future<void> _importCsvAndUpload() async {
    setState(() => _busyBulk = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty || picked.files.first.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV selection cancelled')),
          );
        }
        return;
      }

      final bytes = picked.files.first.bytes!;
      final csvString = utf8.decode(bytes, allowMalformed: true);
      final table = const CsvToListConverter().convert(csvString);
      if (table.length < 2) throw Exception('CSV has no data rows');

      final headers = table.first.map((e) => e.toString().trim().toLowerCase()).toList();
      String cell(List<dynamic> row, String key) {
        final idx = headers.indexOf(key);
        if (idx < 0 || idx >= row.length) return '';
        return row[idx].toString().trim();
      }

      final rows = <Map<String, dynamic>>[];
      for (final r in table.sublist(1)) {
        final title = cell(r, 'title');
        final mediaUrl = cell(r, 'media_url');
        if (title.isEmpty || mediaUrl.isEmpty) {
          continue;
        }
        rows.add({
          'title': title,
          'category': cell(r, 'category').isEmpty ? 'General' : cell(r, 'category'),
          'description': cell(r, 'description'),
          'media_url': mediaUrl,
          'thumb_url': cell(r, 'thumb_url').isEmpty ? null : cell(r, 'thumb_url'),
          'status': cell(r, 'status').isEmpty ? 'pending' : cell(r, 'status'),
          'source': 'bulk_admin',
        });
      }

      if (rows.isEmpty) throw Exception('No valid rows. Require columns: title, media_url');
      final inserted = await widget.dataService.bulkCreateInventoryAssets(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processed batch ledger: $inserted entries created')),
      );
      widget.onRefreshRequested();
      setState(_refreshActivityLog);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV processing failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyBulk = false);
    }
  }

  void _showDraftsDialog() {
    final drafts = widget.items.where((e) => e.status.toLowerCase() == 'draft').toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Draft Entries'),
        content: SizedBox(
          width: 540,
          child: drafts.isEmpty
              ? const Text('No drafts available.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(drafts[i].title),
                    subtitle: Text(drafts[i].category),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showItemActions(InventoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              subtitle: Text(item.title),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Item ID'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item ID copied: ${item.id}')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadInventoryCsv(List<InventoryItem> items) async {
    final rowsToExport = _selectedItemIds.isEmpty
        ? items
        : items.where((item) => _selectedItemIds.contains(item.id)).toList();

    final now = DateTime.now();
    final exportDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final rows = <List<dynamic>>[
      ['Inventory Management Report'],
      ['Generated At', exportDate],
      ['Search Query', widget.searchQuery.trim().isEmpty ? '-' : widget.searchQuery.trim()],
      ['Total Items', rowsToExport.length],
      ['Selection Status', _selectedItemIds.isEmpty ? 'All Filtered' : 'Manually Selected'],
      [],
      [
        'Item ID',
        'Title',
        'Category',
        'Status',
        'Source (Table)',
        'Owner',
        'Created At',
      ],
      ...rowsToExport.map(
        (item) => [
          item.id,
          item.title,
          item.category,
          item.status,
          item.source,
          item.ownerName,
          item.createdAt?.toIso8601String() ?? '',
        ],
      ),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final fileName = 'inventory_export_${now.toIso8601String().replaceAll(':', '-')}.csv';

    if (kIsWeb) {
      final uri = Uri.dataFromString(
        csv,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      html.AnchorElement(href: uri.toString())
        ..setAttribute('download', fileName)
        ..click();
      return;
    }

    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard (web download is automatic).'),
      ),
    );
  }

  void _manageFaq() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQ Modules'),
        content: const Text(
          'Use System Controls to edit global FAQ policy settings. '
          'Inventory screen surfaces quick links for day-to-day curation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    final historyItems = [...widget.items]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload History'),
        content: SizedBox(
          width: 900,
          child: historyItems.isEmpty
              ? const Text('No uploaded records found yet.')
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Source')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Uploader')),
                      DataColumn(label: Text('Created')),
                    ],
                    rows: historyItems
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.title)),
                              DataCell(Text(item.source)),
                              DataCell(_statusChip(item.status)),
                              DataCell(Text(item.ownerName)),
                              DataCell(
                                Text(
                                  item.createdAt == null
                                      ? '-'
                                      : widget.dateFormat.format(item.createdAt!),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllActivityDialog() async {
    var selectedTable = 'all';
    var draftFilterText = '';
    var loading = false;
    String? loadError;
    var rows = <InventoryItem>[];
    var rowsPerPage = 10;
    var currentPage = 0;
    var firstLoadDone = false;
    final filterCtrl = TextEditingController();

    Future<void> loadRows(StateSetter setDialogState) async {
      setDialogState(() {
        loading = true;
        loadError = null;
      });
      try {
        final data = await widget.dataService.fetchContentActivityLog(
          table: selectedTable,
          searchTerm: draftFilterText,
          limit: 1000, // Load more for pagination
        );
        setDialogState(() {
          rows = data;
          rowsPerPage = rows.isNotEmpty ? math.min(rowsPerPage, rows.length) : 1;
          currentPage = 0;
          loading = false;
        });
      } catch (e) {
        setDialogState(() {
          loading = false;
          loadError = '$e';
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mediaSize = MediaQuery.sizeOf(context);
          final dialogWidth = math.min(1180.0, mediaSize.width - 32);
          final dialogHeight = math.min(900.0, mediaSize.height - 32);
          final pageOptions = <int>{1, rowsPerPage, 5, 10, 20, 50}.where((value) => value > 0).toList()..sort();

          if (!firstLoadDone) {
            firstLoadDone = true;
            Future<void>.microtask(() => loadRows(setDialogState));
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'All Content Activity',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_selectedItemIds.isNotEmpty) ...[
                          Text(
                            '${_selectedItemIds.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B7A59)),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _downloadInventoryCsv(rows),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Download Selected'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE9C869),
                              foregroundColor: const Color(0xFF2F2B1F),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildTabButton('All Tables', 'all', selectedTable, (val) {
                          setDialogState(() => selectedTable = val);
                          loadRows(setDialogState);
                        }),
                        _buildTabButton('Products', 'products', selectedTable, (val) {
                          setDialogState(() => selectedTable = val);
                          loadRows(setDialogState);
                        }),
                        _buildTabButton('Designer Products', 'designerproducts', selectedTable, (val) {
                          setDialogState(() => selectedTable = val);
                          loadRows(setDialogState);
                        }),
                        _buildTabButton('Manufacturer Products', 'manufacturerproducts', selectedTable, (val) {
                          setDialogState(() => selectedTable = val);
                          loadRows(setDialogState);
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 980;

                        final filterField = Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAF8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD9E3DE)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: filterCtrl,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Filter by title, category, or uploader',
                              hintStyle: const TextStyle(color: Color(0xFF7E8F89)),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF0A4F3F)),
                              suffixIcon: draftFilterText.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      tooltip: 'Clear filter',
                                      onPressed: () {
                                        filterCtrl.clear();
                                        draftFilterText = '';
                                        loadRows(setDialogState);
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            ),
                            onSubmitted: (value) {
                              draftFilterText = value.trim();
                              loadRows(setDialogState);
                            },
                          ),
                        );

                        final rowsPerPageField = DropdownButtonFormField<int>(
                          value: rowsPerPage,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Rows / page',
                            labelStyle: const TextStyle(color: Color(0xFF61726C)),
                            filled: true,
                            fillColor: const Color(0xFFF7FAF8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFD9E3DE)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFD9E3DE)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF0A4F3F)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          items: pageOptions
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value'),
                                ),
                              )
                              .toList(),
                          onChanged: loading
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    rowsPerPage = value;
                                    currentPage = 0;
                                  });
                                },
                        );

                        final applyButton = FilledButton.icon(
                          onPressed: loading
                              ? null
                              : () {
                                  draftFilterText = filterCtrl.text.trim();
                                  loadRows(setDialogState);
                                },
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.tune, size: 18),
                          label: Text(loading ? 'Applying...' : 'Apply Filter'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0A4F3F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );

                        final countBadge = Align(
                          alignment: stacked ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F4F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${rows.length} item(s)',
                              style: const TextStyle(
                                color: Color(0xFF5D6D67),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );

                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              filterField,
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: rowsPerPageField),
                                  const SizedBox(width: 12),
                                  applyButton,
                                ],
                              ),
                              const SizedBox(height: 10),
                              countBadge,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: filterField),
                            const SizedBox(width: 12),
                            SizedBox(width: 170, child: rowsPerPageField),
                            const SizedBox(width: 12),
                            applyButton,
                            const SizedBox(width: 12),
                            countBadge,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: loading && rows.isEmpty
                            ? const AdminSkeletonView(
                                variant: AdminSkeletonVariant.table,
                                padding: EdgeInsets.zero,
                              )
                            : (loadError != null
                                ? Center(
                                    child: Text(
                                      'Failed to load activity data: $loadError',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  )
                                : (rows.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(40),
                                          child: Text(
                                            'No items match this filter.',
                                            style: TextStyle(fontSize: 16, color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    : Builder(
                                        builder: (context) {
                                          final effectiveRowsPerPage = math.max(1, math.min(rowsPerPage, rows.length));
                                          final totalPages = (rows.length / effectiveRowsPerPage).ceil();
                                          final safeCurrentPage = math.min(currentPage, math.max(0, totalPages - 1)).toInt();
                                          final start = safeCurrentPage * effectiveRowsPerPage;
                                          final end = math.min(start + effectiveRowsPerPage, rows.length);
                                          final pageRows = rows.sublist(start, end);

                                          final headerStyle = const TextStyle(fontWeight: FontWeight.bold);

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: const Color(0xFFE2E7E4)),
                                            ),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: SingleChildScrollView(
                                                    child: SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: DataTable(
                                                        showCheckboxColumn: false,
                                                        headingRowHeight: 56,
                                                        dataRowMinHeight: 54,
                                                        dataRowMaxHeight: 64,
                                                        columnSpacing: 20,
                                                        horizontalMargin: 12,
                                                        columns: [
                                                          DataColumn(
                                                            label: Checkbox(
                                                              value: pageRows.isNotEmpty &&
                                                                  pageRows.every((item) => _selectedItemIds.contains(item.id)),
                                                              onChanged: (val) {
                                                                setDialogState(() {
                                                                  setState(() {
                                                                    if (val == true) {
                                                                      _selectedItemIds.addAll(pageRows.map((item) => item.id));
                                                                    } else {
                                                                      _selectedItemIds.removeAll(pageRows.map((item) => item.id));
                                                                    }
                                                                  });
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                          DataColumn(label: Text('Asset Name', style: headerStyle)),
                                                          DataColumn(label: Text('Table', style: headerStyle)),
                                                          DataColumn(label: Text('Status', style: headerStyle)),
                                                          DataColumn(label: Text('Modified By', style: headerStyle)),
                                                          DataColumn(label: Text('Created', style: headerStyle)),
                                                          DataColumn(label: Text('Actions', style: headerStyle)),
                                                        ],
                                                        rows: pageRows
                                                            .map(
                                                              (item) => DataRow(
                                                                selected: _selectedItemIds.contains(item.id),
                                                                onSelectChanged: (val) {
                                                                  setDialogState(() {
                                                                    setState(() {
                                                                      if (val == true) {
                                                                        _selectedItemIds.add(item.id);
                                                                      } else {
                                                                        _selectedItemIds.remove(item.id);
                                                                      }
                                                                    });
                                                                  });
                                                                },
                                                                cells: [
                                                                  DataCell(
                                                                    Checkbox(
                                                                      value: _selectedItemIds.contains(item.id),
                                                                      onChanged: (val) {
                                                                        setDialogState(() {
                                                                          setState(() {
                                                                            if (val == true) {
                                                                              _selectedItemIds.add(item.id);
                                                                            } else {
                                                                              _selectedItemIds.remove(item.id);
                                                                            }
                                                                          });
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                  DataCell(Text('${item.title} (#${item.id.substring(0, item.id.length.clamp(0, 8))})')),
                                                                  DataCell(Text(item.source)),
                                                                  DataCell(_statusChip(item.status)),
                                                                  DataCell(Text(item.ownerName)),
                                                                  DataCell(
                                                                    Text(
                                                                      item.createdAt == null ? '-' : widget.dateFormat.format(item.createdAt!),
                                                                    ),
                                                                  ),
                                                                  DataCell(
                                                                    IconButton(
                                                                      onPressed: () => _showItemActions(item),
                                                                      icon: const Icon(Icons.more_horiz),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )
                                                            .toList(),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Showing ${rows.isEmpty ? 0 : start + 1}-${end} of ${rows.length}',
                                                        style: const TextStyle(color: Color(0xFF5D6D67), fontWeight: FontWeight.w600),
                                                      ),
                                                      const Spacer(),
                                                      IconButton(
                                                        tooltip: 'Previous page',
                                                        onPressed: safeCurrentPage == 0
                                                            ? null
                                                            : () {
                                                                setDialogState(() {
                                                                  currentPage = safeCurrentPage - 1;
                                                                });
                                                              },
                                                        icon: const Icon(Icons.chevron_left),
                                                      ),
                                                      Text(
                                                        'Page ${safeCurrentPage + 1} of ${math.max(1, totalPages)}',
                                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Next page',
                                                        onPressed: safeCurrentPage >= totalPages - 1
                                                            ? null
                                                            : () {
                                                                setDialogState(() {
                                                                  currentPage = safeCurrentPage + 1;
                                                                });
                                                              },
                                                        icon: const Icon(Icons.chevron_right),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    filterCtrl.dispose();
  }

  Widget _buildTabButton(String title, String value, String selectedValue, Function(String) onSelect) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF034033) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF034033) : const Color(0xFFDDE4E0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF5D6D67),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  double _inventoryHealth(List<InventoryItem> items) {
    if (items.isEmpty) return 0;
    final valid = items.where((item) {
      final hasImage = (item.thumbUrl?.isNotEmpty ?? false) || (item.mediaUrl?.isNotEmpty ?? false);
      final hasTitle = item.title.trim().isNotEmpty;
      final hasCategory = item.category.trim().isNotEmpty;
      return hasImage && hasTitle && hasCategory;
    }).length;
    return (valid / items.length) * 100;
  }
}

class _InventoryDataSource extends DataTableSource {
  _InventoryDataSource({
    required this.items,
    required this.dateFormat,
    required this.onAction,
    required this.statusBuilder,
  });

  final List<InventoryItem> items;
  final DateFormat dateFormat;
  final void Function(InventoryItem) onAction;
  final Widget Function(String) statusBuilder;

  @override
  DataRow? getRow(int index) {
    if (index >= items.length) return null;
    final item = items[index];
    return DataRow(
      cells: [
        DataCell(Text('${item.title} (#${item.id.substring(0, item.id.length.clamp(0, 8))})')),
        DataCell(Text(item.source)),
        DataCell(statusBuilder(item.status)),
        DataCell(Text(item.ownerName)),
        DataCell(
          Text(
            item.createdAt == null ? '-' : dateFormat.format(item.createdAt!),
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () => onAction(item),
            icon: const Icon(Icons.more_horiz),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => items.length;

  @override
  int get selectedRowCount => 0;
}
