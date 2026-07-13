import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

/// "Edit in Sheets" bulk workflow for the B2B catalog:
///   Export  - column-selectable CSV download of the user's products
///             (all, or only the ones selected on the home grid).
///   Import  - pick an edited CSV back up, validate it (error detection),
///             then Sync: rows whose SKU matches an existing product
///             OVERWRITE that product's values for every column present in
///             the CSV; unmatched SKUs are inserted as new products when
///             "Publish new products" is enabled.
///   History - previous syncs from the b2b_sync_history table.
class EditInSheetsDialog extends StatefulWidget {
  const EditInSheetsDialog({
    super.key,
    required this.tableName,
    this.selectedIds = const [],
  });

  /// 'designerproducts' or 'manufacturerproducts'.
  final String tableName;

  /// When non-empty, Export is scoped to these product ids.
  final List<String> selectedIds;

  @override
  State<EditInSheetsDialog> createState() => _EditInSheetsDialogState();
}

/// One row's validation problem, surfaced in the Import tab.
class _RowIssue {
  _RowIssue(this.rowNumber, this.message);
  final int rowNumber; // 1-based, matching what the user sees in a sheet
  final String message;
}

class _EditInSheetsDialogState extends State<EditInSheetsDialog> {
  static const _teal = Colors.teal;

  // Columns the sheet round-trip supports. SKU is the match key and is
  // always exported. Array-valued columns ("Images"/"Category"/"Metal Color"/
  // "Studded"/"Product Tags") round-trip as "a | b | c".
  static const List<String> _allColumns = [
    'SKU',
    'Product Title',
    'Description',
    'Price',
    'Product Type',
    'Category',
    'Sub Category',
    'Metal Type',
    'Metal Purity',
    'Metal Finish',
    'Metal Color',
    'Metal Weight',
    'Plain',
    'Studded',
    'Gender',
    'Theme',
    'Dimension',
    'Plating',
    'Product Tags',
    'Images',
  ];

  static const Set<String> _arrayColumns = {'Studded', 'Product Tags'};

  final _supabase = Supabase.instance.client;

  // Export state
  late final Set<String> _exportColumns = _allColumns.toSet();
  bool _exporting = false;

  // Import state
  String? _fileName;
  List<String> _csvHeaders = [];
  List<List<dynamic>> _csvRows = [];
  List<_RowIssue> _issues = [];
  List<String> _ignoredHeaders = [];
  bool _overwriteBySku = true;
  bool _publishNew = true;
  bool _syncing = false;
  String? _syncSummary;

  String get _userId => _supabase.auth.currentUser?.id ?? '';

  // ───────────────────────────── EXPORT ─────────────────────────────

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      var query =
          _supabase.from(widget.tableName).select('*').eq('user_id', _userId);
      if (widget.selectedIds.isNotEmpty) {
        final ids =
            widget.selectedIds.map((e) => int.tryParse(e) ?? e).toList();
        query = query.inFilter('id', ids);
      }
      final rows = await query.order('created_at', ascending: false);

      final columns =
          _allColumns.where((c) => _exportColumns.contains(c)).toList();
      final data = <List<dynamic>>[columns];
      for (final row in rows) {
        data.add(columns.map((c) => _cellForExport(row, c)).toList());
      }

      final csvContent = const ListToCsvConverter().convert(data);
      final blob = html.Blob([csvContent], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            '${widget.tableName}_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported ${rows.length} product(s) to CSV'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _cellForExport(Map<String, dynamic> row, String column) {
    // "Images"/"Category"/"Metal Color" are text[] arrays; others scalar.
    final value = row[column];
    if (value == null) return '';
    if (value is List) return value.map((e) => '$e').join(' | ');
    return '$value';
  }

  // ───────────────────────────── IMPORT ─────────────────────────────

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    // UTF-8, tolerant of a leading BOM Excel likes to add.
    final content =
        utf8.decode(file.bytes!, allowMalformed: true).replaceFirst('﻿', '');
    final parsed = const CsvToListConverter(shouldParseNumbers: false)
        .convert(content, eol: '\n');
    if (parsed.isEmpty) {
      setState(() {
        _fileName = file.name;
        _csvHeaders = [];
        _csvRows = [];
        _issues = [_RowIssue(0, 'The file is empty.')];
        _ignoredHeaders = [];
        _syncSummary = null;
      });
      return;
    }

    final headers =
        parsed.first.map((h) => h.toString().trim()).toList(growable: false);
    final rows = parsed.skip(1).where((r) => r.any((c) => '$c'.trim().isNotEmpty)).toList();

    setState(() {
      _fileName = file.name;
      _csvHeaders = headers;
      _csvRows = rows;
      _syncSummary = null;
      _validate();
    });
  }

  /// Error detection: structural problems block syncing entirely; row-level
  /// problems skip just those rows (reported with their sheet row number).
  void _validate() {
    final issues = <_RowIssue>[];
    _ignoredHeaders = _csvHeaders
        .where((h) => h.isNotEmpty && !_allColumns.contains(h))
        .toList();

    if (!_csvHeaders.contains('SKU')) {
      issues.add(_RowIssue(
          1, 'Missing required "SKU" column — SKU is the overwrite match key.'));
      _issues = issues;
      return;
    }

    final skuIndex = _csvHeaders.indexOf('SKU');
    final titleIndex = _csvHeaders.indexOf('Product Title');
    final seenSkus = <String>{};
    for (var i = 0; i < _csvRows.length; i++) {
      final sheetRow = i + 2; // +1 for header, +1 for 1-based
      final row = _csvRows[i];
      final sku =
          skuIndex < row.length ? '${row[skuIndex]}'.trim() : '';
      if (sku.isEmpty) {
        issues.add(_RowIssue(sheetRow, 'Empty SKU — row will be skipped.'));
        continue;
      }
      if (!seenSkus.add(sku)) {
        issues.add(_RowIssue(sheetRow,
            'Duplicate SKU "$sku" — only the first occurrence is synced.'));
      }
      if (row.length > _csvHeaders.length) {
        issues.add(_RowIssue(sheetRow,
            'Row has more cells than the header — extra cells are ignored.'));
      }
      final title =
          titleIndex >= 0 && titleIndex < row.length ? '${row[titleIndex]}'.trim() : '';
      if (title.isEmpty && titleIndex >= 0) {
        issues.add(_RowIssue(
            sheetRow, 'Empty Product Title for SKU "$sku" (allowed, but check it).'));
      }
    }
    _issues = issues;
  }

  bool get _hasBlockingIssue =>
      _csvHeaders.isNotEmpty && !_csvHeaders.contains('SKU');

  List<String>? _splitList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final sep = trimmed.contains('|') ? '|' : ',';
    final parts = trimmed
        .split(sep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  /// Builds the column->value map for one CSV row, containing ONLY columns
  /// present in the CSV (so an omitted column never clobbers existing data).
  Map<String, dynamic> _rowToProductData(List<dynamic> row) {
    final data = <String, dynamic>{};
    for (var j = 0; j < _csvHeaders.length && j < row.length; j++) {
      final header = _csvHeaders[j];
      if (!_allColumns.contains(header) || header == 'SKU') continue;
      final raw = '${row[j]}'.trim();
      final value = raw.isEmpty ? null : raw;

      if (header == 'Images' ||
          header == 'Category' ||
          header == 'Metal Color') {
        // Unified text[] arrays.
        data[header] = value == null ? null : _splitList(value);
      } else if (_arrayColumns.contains(header)) {
        data[header] = value == null ? null : _splitList(value);
      } else {
        data[header] = value;
      }
    }
    return data;
  }

  Future<void> _syncProducts() async {
    if (_csvRows.isEmpty || _hasBlockingIssue || _userId.isEmpty) return;
    setState(() {
      _syncing = true;
      _syncSummary = null;
    });

    var updated = 0, inserted = 0, skipped = 0, failed = 0;
    final failures = <String>[];
    try {
      // Existing SKU -> id map for THIS user's products only.
      final existing = await _supabase
          .from(widget.tableName)
          .select('id,"SKU"')
          .eq('user_id', _userId);
      final skuToId = <String, dynamic>{
        for (final row in existing)
          if ('${row['SKU'] ?? ''}'.trim().isNotEmpty)
            '${row['SKU']}'.trim(): row['id'],
      };

      final skuIndex = _csvHeaders.indexOf('SKU');
      final seen = <String>{};
      for (final row in _csvRows) {
        final sku = skuIndex < row.length ? '${row[skuIndex]}'.trim() : '';
        if (sku.isEmpty || !seen.add(sku)) {
          skipped++;
          continue;
        }
        final data = _rowToProductData(row);
        try {
          final existingId = skuToId[sku];
          if (existingId != null) {
            if (_overwriteBySku) {
              await _supabase
                  .from(widget.tableName)
                  .update(data)
                  .eq('id', existingId)
                  .eq('user_id', _userId);
              updated++;
            } else {
              skipped++;
            }
          } else if (_publishNew) {
            await _supabase.from(widget.tableName).insert({
              ...data,
              'SKU': sku,
              'user_id': _userId,
            });
            inserted++;
          } else {
            skipped++;
          }
        } catch (e) {
          failed++;
          if (failures.length < 5) failures.add('SKU $sku: $e');
        }
      }

      // Record the sync (best-effort: history must never fail the sync).
      try {
        await _supabase.from('b2b_sync_history').insert({
          'user_id': _userId,
          'table_name': widget.tableName,
          'file_name': _fileName ?? 'unknown.csv',
          'updated_count': updated,
          'inserted_count': inserted,
          'skipped_count': skipped,
          'failed_count': failed,
          'error_details': failures,
        });
      } catch (e) {
        debugPrint('Could not record sync history: $e');
      }

      setState(() {
        _syncSummary = 'Sync complete — $updated overwritten, '
            '$inserted published as new, $skipped skipped'
            '${failed > 0 ? ', $failed FAILED' : ''}.'
            '${failures.isEmpty ? '' : '\n${failures.join('\n')}'}';
      });
    } catch (e) {
      setState(() => _syncSummary = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width < 820 ? size.width - 24 : 780,
        height: size.height < 700 ? size.height - 24 : 660,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_outlined, color: _teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Edit in Sheets — ${widget.tableName == 'manufacturerproducts' ? 'Manufacturer' : 'Designer'} catalog',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      // `true` tells the caller to refresh its product list.
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: _teal,
                indicatorColor: _teal,
                tabs: [
                  Tab(text: 'Export CSV'),
                  Tab(text: 'Import & Sync'),
                  Tab(text: 'Sync History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildExportTab(),
                    _buildImportTab(),
                    _SyncHistoryTab(tableName: widget.tableName),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedIds.isEmpty
                ? 'Exports ALL your products. Select products on the home screen first to export a subset.'
                : 'Exports the ${widget.selectedIds.length} selected product(s).',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          const Text('Columns to include',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allColumns.map((c) {
              final checked = _exportColumns.contains(c);
              final isKey = c == 'SKU';
              return FilterChip(
                label: Text(c + (isKey ? ' (key)' : '')),
                selected: checked,
                onSelected: isKey
                    ? null // SKU is always exported - it's the sync key
                    : (v) => setState(() =>
                        v ? _exportColumns.add(c) : _exportColumns.remove(c)),
                selectedColor: _teal.withOpacity(0.12),
                checkmarkColor: _teal,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportCsv,
            style: FilledButton.styleFrom(backgroundColor: _teal),
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download),
            label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
          ),
          const SizedBox(height: 10),
          Text(
            'Open the file in Excel / Google Sheets, edit values, then use "Import & Sync" to write changes back. Multi-value cells (Images, Category, Metal Color, Studded, Product Tags) use " | " between values.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _syncing ? null : _pickCsv,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(_fileName ?? 'Choose CSV file'),
                style: OutlinedButton.styleFrom(foregroundColor: _teal),
              ),
              const SizedBox(width: 12),
              if (_csvRows.isNotEmpty)
                Text('${_csvRows.length} data row(s)',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade700)),
            ],
          ),
          if (_ignoredHeaders.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ignored columns (not part of the product schema): ${_ignoredHeaders.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
          if (_issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_issues.length} issue(s) detected',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A3412))),
                  const SizedBox(height: 6),
                  ..._issues.take(12).map((i) => Text(
                        'Row ${i.rowNumber}: ${i.message}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9A3412)),
                      )),
                  if (_issues.length > 12)
                    Text('…and ${_issues.length - 12} more',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9A3412))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _overwriteBySku,
            onChanged: (v) => setState(() => _overwriteBySku = v ?? true),
            title: const Text('Overwrite products with matching SKU',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Existing values will be replaced for all columns included in the CSV.',
                style: TextStyle(fontSize: 12)),
            activeColor: _teal,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _publishNew,
            onChanged: (v) => setState(() => _publishNew = v ?? true),
            title: const Text('Publish new products to all sales channels',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Rows whose SKU has no match are added to your catalog as new products.',
                style: TextStyle(fontSize: 12)),
            activeColor: _teal,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed:
                (_csvRows.isEmpty || _hasBlockingIssue || _syncing)
                    ? null
                    : _syncProducts,
            style: FilledButton.styleFrom(backgroundColor: _teal),
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync),
            label: Text(_syncing ? 'Syncing…' : 'Sync Products'),
          ),
          if (_syncSummary != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Text(_syncSummary!,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF065F46))),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncHistoryTab extends StatefulWidget {
  const _SyncHistoryTab({required this.tableName});
  final String tableName;

  @override
  State<_SyncHistoryTab> createState() => _SyncHistoryTabState();
}

class _SyncHistoryTabState extends State<_SyncHistoryTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await Supabase.instance.client
        .from('b2b_sync_history')
        .select()
        .eq('user_id', userId)
        .eq('table_name', widget.tableName)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Sync history is unavailable: ${snap.error}\n\n(If this is a fresh environment, run the b2b_sync_history migration.)',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: Text('No syncs yet.',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final errors = (r['error_details'] as List?) ?? [];
            return ListTile(
              dense: true,
              leading: Icon(
                (r['failed_count'] ?? 0) > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: (r['failed_count'] ?? 0) > 0
                    ? Colors.orange
                    : Colors.teal,
              ),
              title: Text('${r['file_name'] ?? 'unknown.csv'}',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${r['updated_count'] ?? 0} overwritten • ${r['inserted_count'] ?? 0} new • '
                '${r['skipped_count'] ?? 0} skipped • ${r['failed_count'] ?? 0} failed'
                '${errors.isEmpty ? '' : '\n${errors.join('\n')}'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '${r['created_at'] ?? ''}'.split('.').first.replaceAll('T', ' '),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            );
          },
        );
      },
    );
  }
}
