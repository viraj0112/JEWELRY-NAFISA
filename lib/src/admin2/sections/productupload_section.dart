import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import '../widgets/admin_page_header.dart';

class ImagePreview {
  final String name;
  final int size;
  final int width;
  final int height;
  final List<int> bytes;

  ImagePreview({
    required this.name,
    required this.size,
    required this.width,
    required this.height,
    required this.bytes,
  });
}

class _StepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final int index;

  _StepData(this.title, this.subtitle, this.icon, this.index);
}

class ProductUploadSection extends StatefulWidget {
  const ProductUploadSection({super.key});

  @override
  State<ProductUploadSection> createState() => _ProductUploadSectionState();
}

class _ProductUploadSectionState extends State<ProductUploadSection>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _fileName;
  List<List<dynamic>>? _csvData;
  List<PlatformFile>? _selectedImages;
  Map<String, String> _imageNameToUrl = {};
  int _currentStep = 0;
  late TabController _tabController;
  List<ImagePreview> _imagePreviews = [];

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
        allowCompression: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImages = result.files;
          _generateImagePreviews();
        });
        _showSuccessSnackBar('${result.files.length} images selected');
        setState(() {
          _currentStep = 1;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking images: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generateImagePreviews() async {
    _imagePreviews.clear();
    if (_selectedImages != null) {
      for (final file in _selectedImages!) {
        if (file.bytes != null) {
          try {
            final bytes = file.bytes!;
            _imagePreviews.add(ImagePreview(
              name: file.name,
              size: file.size,
              width:
                  300, // Default width since we can't easily decode image without additional package
              height: 300, // Default height
              bytes: bytes,
            ));
          } catch (e) {
            // Skip invalid images
          }
        }
      }
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
          final filePath = fileName;

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

      _showSuccessSnackBar(
          '${_selectedImages!.length} images uploaded successfully');
      setState(() {
        _currentStep = 2;
      });
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

    // Check if we have selected images (either uploaded or ready to upload)
    if (_selectedImages == null || _selectedImages!.isEmpty) {
      _showErrorSnackBar('Please select images first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // If images haven't been uploaded to Supabase yet, upload them now
      if (_imageNameToUrl.isEmpty) {
        _showSuccessSnackBar('Uploading images to Supabase...');
        for (final imageFile in _selectedImages!) {
          if (imageFile.bytes != null) {
            final fileName = imageFile.name;
            final filePath = fileName;

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
        _showSuccessSnackBar(
            '${_imageNameToUrl.length} images uploaded to Supabase');
      }

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
        'embedding', // Singular (matches your CSV)
        'embeddings', // Plural (kept just in case)
      };

      final List<Map<String, dynamic>> productList = [];
      for (final row in rows) {
        final product = <String, dynamic>{};
        String? productTitle;

        for (int i = 0; i < headers.length; i++) {
          if (i < row.length) {
            final String header = headers[i];
            if (header.isEmpty) continue;
            dynamic value = row[i];

            if (header == 'Product Title') {
              productTitle = value.toString().trim();
            }

            // --- LOGIC FIX START ---
            if (arrayHeaders.contains(header)) {
              // Check for empty or null values specifically for array columns
              if (value == null || value.toString().trim().isEmpty) {
                // Send NULL for empty optional arrays/vectors.
                // Sending "" (empty string) causes the 'malformed array literal' error.
                product[header] = null;
              } else {
                // Parse valid strings into a List
                product[header] =
                    value.toString().split(',').map((t) => t.trim()).toList();
              }
            }
            // --- LOGIC FIX END ---

            else if (header == 'Price' && value is String) {
              final cleanedPriceString =
                  value.replaceAll('₹', '').replaceAll(',', '').trim();
              product[header] = double.tryParse(cleanedPriceString);
            } else {
              // For non-array fields, check if empty and send null if needed
              if (value != null && value.toString().trim().isNotEmpty) {
                product[header] = value;
              } else {
                product[header] = null;
              }
            }
          }
        }

       if (productTitle != null && productTitle.isNotEmpty) {
          // Find ALL matching image URLs based on the product title prefix
          final matchingImageUrls = _imageNameToUrl.entries
              .where((entry) => entry.key.startsWith(productTitle!))
              .map((entry) => entry.value)
              .toList();

          // If Image column is now an Array (TEXT[]):
          if (matchingImageUrls.isNotEmpty) {
            // Send the List of URLs to the single 'Image' column
            product['Image'] = matchingImageUrls;
          } else {
            // Send NULL if no images match
            product['Image'] = null;
          }

        } else {
          // If no title, ensure Image field is null
          product['Image'] = null;
        }

        productList.add(product);
      }
      
      await Supabase.instance.client.from('products').upsert(productList);

      _showSuccessSnackBar(
          '🎉 Successfully uploaded ${productList.length} products!');
      _resetForm();
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
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _fileName = null;
      _csvData = null;
      _selectedImages = null;
      _imageNameToUrl.clear();
      _imagePreviews.clear();
      _currentStep = 0;
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: AdminPageHeader(
        leading: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: 'Product Upload Center',
        subtitle:
            'Upload product data and images efficiently to your inventory',
        actions: [
          if (_csvData != null || _selectedImages != null)
            IconButton(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh, size: 24),
              tooltip: 'Reset Form',
              style: IconButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.error.withOpacity(0.1),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      _StepData('Images', 'Upload product images', Icons.image, 0),
      _StepData('Data', 'Import CSV data', Icons.table_chart, 1),
      _StepData('Review', 'Review & upload', Icons.upload_file, 2),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: steps.map((step) {
          final isActive = _currentStep == step.index;
          final isCompleted = _currentStep > step.index;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green
                        : isActive
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: isActive
                          ? Theme.of(context).primaryColor
                          : isCompleted
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : step.icon,
                    color: isCompleted || isActive
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isActive || isCompleted
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isActive || isCompleted
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (step.index < steps.length - 1)
                  Container(
                    height: 2,
                    width: 40,
                    color: isCompleted
                        ? Colors.green
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentStep) {
      case 0:
        return _buildImageUploadStep();
      case 1:
        return _buildDataUploadStep();
      case 2:
        return _buildReviewStep();
      default:
        return _buildImageUploadStep();
    }
  }

  Widget _buildImageUploadStep() {
    return Column(
      children: [
        if (_selectedImages == null || _selectedImages!.isEmpty) ...[
          _buildUploadCard(
            title: 'Upload Product Images',
            subtitle:
                'Select high-quality images for your products. Image filenames should start with the product title for automatic matching.',
            icon: Icons.image_outlined,
            onTap: _pickImages,
            isLoading: _isLoading,
          ),
        ] else ...[
          _buildImagePreviewGrid(),
          const SizedBox(height: 24),
          _buildImageActionButtons(),
        ],
      ],
    );
  }

  Widget _buildDataUploadStep() {
    return Column(
      children: [
        if (_csvData == null) ...[
          _buildUploadCard(
            title: 'Import Product Data',
            subtitle:
                'Upload a CSV file containing your product information. Ensure the first row contains column headers.',
            icon: Icons.table_chart_outlined,
            onTap: _pickFile,
            isLoading: _isLoading,
          ),
        ] else ...[
          _buildDataPreview(),
          const SizedBox(height: 24),
          _buildDataActionButtons(),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return _buildFinalReviewCard();
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.add),
                    label: const Text('Select Files'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviewGrid() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Selected Images (${_selectedImages?.length ?? 0})',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: _selectedImages?.length ?? 0,
                itemBuilder: (context, index) {
                  final file = _selectedImages![index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.memory(
                              file.bytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            file.name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _selectedImages = null;
                    _imagePreviews.clear();
                    _currentStep = 0;
                  });
                },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _isLoading ? null : _uploadImagesToSupabase,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: const Text('Upload Images'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataPreview() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Data Imported',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'File: $_fileName • ${_csvData!.length - 1} products',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Ready',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _csvData = null;
              _fileName = null;
              _currentStep = 1;
            });
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear Data'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: (_selectedImages?.isNotEmpty ?? false) && _csvData != null
              ? () {
                  setState(() {
                    _currentStep = 2;
                  });
                }
              : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue to Review'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalReviewCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.rate_review,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review & Upload',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Verify your data before final upload',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.05),
            Theme.of(context).primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryItem(
                'Images',
                '${_selectedImages?.length ?? 0}',
                Icons.image,
                Colors.blue,
              ),
              _buildSummaryItem(
                'Products',
                '${(_csvData?.length ?? 1) - 1}',
                Icons.inventory_2,
                Colors.green,
              ),
              _buildSummaryItem(
                'Uploaded',
                '${_imageNameToUrl.length}',
                Icons.cloud_done,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _isLoading ? null : _uploadToSupabase,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload),
          label: const Text('Upload to Supabase'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
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
        headingRowColor: MaterialStateProperty.all(
          Theme.of(context).colorScheme.surface.withOpacity(0.5),
        ),
        border: TableBorder(
          borderRadius: BorderRadius.circular(8),
          horizontalInside: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        columns: headers
            .map((header) => DataColumn(
                  label: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      header.toString(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ))
            .toList(),
        rows: rows.take(5).map((row) {
          return DataRow(
            cells: row.map((cell) {
              return DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Text(
                    cell.toString(),
                    style: GoogleFonts.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildProgressSteps(),
                const SizedBox(height: 32),
                _buildMainContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
