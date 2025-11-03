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
  List<List<dynamic>>? _csvData;
  List<PlatformFile>? _selectedImages;
  Map<String, String> _imageNameToUrl = {};

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

  void _pickImages() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImages = result.files;
        });
        _showSuccessSnackBar('${result.files.length} images selected');
      }
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadImagesToSupabase() async {
    if (_selectedImages == null || _selectedImages!.isEmpty) {
      _showErrorSnackBar('No images selected');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _imageNameToUrl.clear();

      for (final imageFile in _selectedImages!) {
        if (imageFile.bytes != null) {
          final fileName = imageFile.name;
          final filePath = 'product-images/$fileName';

          await Supabase.instance.client.storage
              .from('product-images')
              .uploadBinary(
                filePath,
                imageFile.bytes!,
                fileOptions: const FileOptions(upsert: true),
              );

          final imageUrl = Supabase.instance.client.storage
              .from('product-images')
              .getPublicUrl(fileName);

          _imageNameToUrl[fileName] = imageUrl;
        }
      }

      _showSuccessSnackBar('${_selectedImages!.length} images uploaded successfully');
    } catch (e) {
      _showErrorSnackBar('Error uploading images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadToSupabase() async {
    if (_csvData == null || _csvData!.length < 2) {
      _showErrorSnackBar('No data to upload or header is missing.');
      return;
    }

    if (_imageNameToUrl.isEmpty) {
      _showErrorSnackBar('Please upload images first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = _csvData![0].map((e) => e.toString().trim()).toList();
      final rows = _csvData!.sublist(1);
      final titleIndex = headers.indexOf('Product Title');

      if (titleIndex == -1) {
        _showErrorSnackBar('CSV must contain a "Product Title" column.');
        setState(() => _isLoading = false);
        return;
      }

      const arrayHeaders = {
        'Product Tags',
        'Stone Weight',
        'Stone Type',
        'Stone Used',
        'Stone Setting',
        'Stone Count',
        'Stone Color',
        'Stone Cut',
        'Stone Purity',
      };

      final List<Map<String, dynamic>> productList = [];
      for (final row in rows) {
        final product = <String, dynamic>{};
        String? productTitle;

        for (int i = 0; i < headers.length; i++) {
          if (i < row.length) {
            final String header = headers[i];
            dynamic value = row[i];

            if (header == 'Product Title') {
              productTitle = value.toString().trim();
            }

            if (arrayHeaders.contains(header)) {
              if (value == null) {
                product[header] = null;
              } else if (value is String) {
                if (value.isEmpty) {
                  product[header] = null;
                } else {
                  product[header] =
                      value.split(',').map((t) => t.trim()).toList();
                }
              } else {
                product[header] = [value.toString()];
              }
            } else if (header == 'Price' && value is String) {
              final cleanedPriceString =
                  value.replaceAll('₹', '').replaceAll(',', '').trim();
              product[header] = double.tryParse(cleanedPriceString);
            } else {
              product[header] = value;
            }
          }
        }

        if (productTitle != null && productTitle.isNotEmpty) {
          // Find matching image by product title prefix
          String? matchingImageUrl;
          for (final entry in _imageNameToUrl.entries) {
            if (entry.key.startsWith(productTitle)) {
              matchingImageUrl = entry.value;
              break;
            }
          }

          if (matchingImageUrl != null) {
            product['Image'] = matchingImageUrl;
          } else {
            _showErrorSnackBar('Image not found for product: $productTitle');
            product['Image'] = null;
          }
        }

        productList.add(product);
      }

      await Supabase.instance.client.from('products').upsert(productList);

      _showSuccessSnackBar('Successfully uploaded products!');
      setState(() {
        _fileName = null;
        _csvData = null;
        _selectedImages = null;
        _imageNameToUrl.clear();
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
              _buildImagePickerCard(),
              const SizedBox(height: 24),
              _buildFilePickerCard(),
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

  Widget _buildImagePickerCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.image_outlined,
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Select Product Images',
              style:
                  GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose image files for your products. Image names should start with the product title.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_selectedImages != null && _selectedImages!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedImages!.length} images selected:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedImages!.take(5).map((file) => Text(
                          '• ${file.name}',
                          style: const TextStyle(fontSize: 12),
                        )),
                    if (_selectedImages!.length > 5)
                      Text(
                        '• +${_selectedImages!.length - 5} more',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickImages,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse Images'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 16),
                if (_selectedImages != null && _selectedImages!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _uploadImagesToSupabase,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload Images'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
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
            Text('Rows to upload: ${_csvData!.length - 1}'),
            Text(
              'Images uploaded: ${_imageNameToUrl.length}',
              style: TextStyle(
                color: _imageNameToUrl.isNotEmpty ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                    _selectedImages = null;
                    _imageNameToUrl.clear();
                  }),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading || _imageNameToUrl.isEmpty
                      ? null
                      : _uploadToSupabase,
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
