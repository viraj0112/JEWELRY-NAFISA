import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductUploadSection extends StatefulWidget {
  const ProductUploadSection({super.key});

  @override
  _ProductUploadSectionState createState() => _ProductUploadSectionState();
}

class _ProductUploadSectionState extends State<ProductUploadSection> {
  bool _isLoading = false;
  String? _fileName;
  // **FIX 1**: Changed 'late' back to nullable. This is safer.
  List<List<dynamic>>? _csvData;

  void _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final csvString = utf8.decode(bytes, allowMalformed: true);
        final List<List<dynamic>> csvTable =
            const CsvToListConverter().convert(csvString);

        setState(() {
          _csvData = csvTable;
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadToSupabase() async {
    if (_csvData == null || _csvData!.length < 2) {
      _showErrorSnackBar('No data to upload or header is missing.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = _csvData![0].map((e) => e.toString().trim()).toList();
      final rows = _csvData!.sublist(1);

      final List<Map<String, dynamic>> productList = [];
      for (final row in rows) {
        final product = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          if (i < row.length) {
            final String header = headers[i];
            final dynamic value = row[i];
            if (header == 'tags' && value is String) {
              product[header] = value.split(',').map((t) => t.trim()).toList();
            } else if (header == 'price' && value is String) {
              final cleanedPriceString =
                  value.replaceAll('₹', '').replaceAll(',', '').trim();
              product[header] = double.tryParse(cleanedPriceString);
            } else {
              product[header] = value;
            }
          }
        }
        productList.add(product);
      }
      await Supabase.instance.client.from('products').upsert(productList);

      _showSuccessSnackBar('Successfully uploaded products!');
      setState(() {
        _fileName = null;
        _csvData = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error uploading to Supabase: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Products',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildFilePickerCard(),
              // **FIX 2**: The condition MUST check _csvData, not just the file name.
              // This is the key to preventing the crash.
              if (_csvData != null) ...[
                const SizedBox(height: 24),
                _buildPreviewCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a CSV File',
              style:
                  GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a CSV file to upload your product data. The first row should contain the column headers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview Data',
              style:
                  GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('File: $_fileName'),
            // **FIX 3**: Using '!' is now safe because the parent build method
            // already checked that _csvData is not null.
            Text('Rows to upload: ${_csvData!.length - 1}'),
            const SizedBox(height: 16),
            _buildDataTable(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _fileName = null;
                    _csvData = null;
                  }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadToSupabase,
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload to Supabase'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    // This check is good practice, but the parent build method already protects it.
    if (_csvData == null || _csvData!.isEmpty) {
      return const Text('No data to display.');
    }

    final headers = _csvData![0];
    final rows = _csvData!.sublist(1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: headers
            .map((header) => DataColumn(label: Text(header.toString())))
            .toList(),
        rows: rows.map((row) {
          return DataRow(
            cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
          );
        }).toList(),
      ),
    );
  }
}
