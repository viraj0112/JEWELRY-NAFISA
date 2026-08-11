import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../../../utils/product_image_matcher.dart';

class BulkUploadUploadCard extends StatelessWidget {
  const BulkUploadUploadCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BulkUploadWizard()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.lightBlue[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Bulk Upload",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Upload multiple products at once with a guided flow",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 8),
                    _Bullet(text: "Upload multiple products simultaneously"),
                    _Bullet(text: "CSV template provided"),
                    _Bullet(text: "Great for catalog uploads"),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 6, color: Colors.blue),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }
}

class BulkUploadWizard extends StatefulWidget {
  const BulkUploadWizard({super.key});

  @override
  State<BulkUploadWizard> createState() => _BulkUploadWizardState();
}

class _BulkUploadWizardState extends State<BulkUploadWizard> {
  List<PlatformFile>? _csvFiles;
  List<PlatformFile>? _imageFiles;
  bool _isLoading = false;

  void _downloadSampleCsv() {
    // Headers matching the designerproducts/manufacturerproducts table
    // schema. "Gold Weight", "Collection Name", "Net Weight", "Design Type",
    // "Art Form", "Category1/2/3" are dropped (confirmed unused, Phase 3
    // cleanup) - no longer offered as upload columns.
    final List<String> headers = [
      'Product Title',
      'Description',
      'Price',
      'SKU',
      'Product Tags',
      'Metal Weight',
      'Metal Purity',
      'Metal Finish',
      'Stone Weight',
      'Stone Type',
      'Stone Used',
      'Stone Setting',
      'Stone Count',
      'Stone Color',
      'Stone Cut',
      'Stone Purity',
      'Product Type',
      'Gender',
      'Metal Type',
      'Metal Color',
      'Dimension',
      'Plating',
      'Enamel Work',
      'Customizable',
      'Category',
      'Sub Category',
      'Jewelry Type',
    ];

    final String csvContent = const ListToCsvConverter().convert([headers]);
    final blob = html.Blob([csvContent], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sample_products.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null) {
        setState(() {
          _csvFiles = result.files;
        });
      }
    } catch (e) {
      debugPrint('Error picking CSV: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      // Using FilePicker for consistency with web bytes support
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          _imageFiles = result.files;
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _submitBulkUpload() async {
    if (_csvFiles == null || _imageFiles == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a CSV file and images.")),
      );
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
      'Enamel Work',
      'Customizable',
      'Studded',
    };

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    // CRITICAL: Get authenticated user
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You must be logged in to upload products."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Check if user has manufacturer or designer profile
      final manufacturerProfileQuery = await supabase
          .from('manufacturer_profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final designerProfileQuery = await supabase
          .from('designer_profiles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      final isManufacturer = manufacturerProfileQuery != null;
      final isDesigner = designerProfileQuery != null;

      if (!isManufacturer && !isDesigner) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "You must have a manufacturer or designer profile to upload products."),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Prioritize manufacturer profile if both exist
      final storageBucket =
          isManufacturer ? 'manufacturer-files' : 'designer-files';
      final tableName =
          isManufacturer ? 'manufacturerproducts' : 'designerproducts';

      final input = utf8.decode(_csvFiles!.first.bytes!);
      final fields = const CsvToListConverter().convert(input);
      final headers = fields[0].map((e) => e.toString().trim()).toList();

      // Keep the CSV's Metal Type verbatim, INCLUDING any leading "AKD-".
      // That prefix is how a product is classified into the "Get it" catalog:
      // the home/welcome screens query `Metal Type ILIKE 'AKD-%'`, and strip
      // the prefix only for display. Stripping it here (an earlier change)
      // silently dropped every uploaded product out of "Get it".
      String? normalizeMetalType(dynamic value) {
        final text = value?.toString().trim();
        if (text == null || text.isEmpty) return null;
        return text;
      }

      // debugPrint("=== CSV DATA ===");
      // debugPrint("Headers: $headers");
      // debugPrint("Total rows: ${fields.length - 1}");
      // for (int i = 1; i < fields.length; i++) {
      //   debugPrint("Row $i: ${fields[i]}");
      // }
      // debugPrint("================");

      int successCount = 0;
      int failCount = 0;
      final List<String> imageWarnings = [];

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        // Check all required fields
        final requiredFields = [
          'Product Title',
          'SKU',
          'Product Type',
          'Metal Weight (in gm)',
          'Gender',
          'Jewelry Type',
          'Metal Type'
        ];

        bool missingRequired = false;
        for (final reqField in requiredFields) {
          final idx = headers.indexOf(reqField);
          if (idx == -1 ||
              idx >= row.length ||
              row[idx].toString().trim().isEmpty) {
            debugPrint("Row $i: Missing or empty $reqField");
            imageWarnings.add('Row $i: Missing required field "$reqField"');
            missingRequired = true;
          }
        }

        if (missingRequired) {
          failCount++;
          continue;
        }

        final titleIndex = headers.indexOf('Product Title');
        final title = row[titleIndex].toString().trim();

        // Find ALL matching image files (case-insensitive, natural ordering so
        // -Image2 precedes -Image10).
        final matchingImageFiles =
            matchingImagesForTitle(_imageFiles!, title, (file) => file.name);

        if (matchingImageFiles.isEmpty) {
          imageWarnings.add('$title: no matching image files selected');
        }

        List<String> uploadedImageUrls = [];
        for (final imageFile in matchingImageFiles) {
          try {
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}-${imageFile.name}';
            await supabase.storage
                .from(storageBucket)
                .uploadBinary(fileName, imageFile.bytes!);
            final imageUrl =
                supabase.storage.from(storageBucket).getPublicUrl(fileName);
            uploadedImageUrls.add(imageUrl);
          } catch (e) {
            // Surface this instead of only logging it: the product row still
            // inserts with Images = null, which previously reported as a fully
            // successful upload.
            debugPrint("Failed to upload image ${imageFile.name}: $e");
            imageWarnings
                .add('$title: ${imageFile.name} failed to upload ($e)');
          }
        }

        List<String>? parseArrayValue(dynamic value) {
          if (value == null) return null;
          if (value is String) {
            if (value.isEmpty) return null;
            return value
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
          }
          return [value.toString()];
        }

        String? getStringValue(dynamic value) {
          if (value == null) return null;
          final str = value.toString().trim();
          return str.isEmpty ? null : str;
        }

        final imagesList = uploadedImageUrls.isEmpty ? null : uploadedImageUrls;
        // Unified schema: "Images"/"Category"/"Metal Color" are all text[].
        final Map<String, dynamic> productData = {
          'user_id': user.id, // Automatically associate with logged-in user
          'Product Title': title,
          'Images': imagesList,
        };

        for (int j = 0; j < headers.length; j++) {
          if (j >= row.length) continue;
          final header = headers[j];
          final value = row[j];

          if (header == 'Product Title' || header == 'Image') continue;

          if (arrayHeaders.contains(header)) {
            productData[header] = parseArrayValue(value);
          } else if (header == 'Metal Type') {
            productData[header] = normalizeMetalType(value);
          } else if (header == 'Metal Color') {
            final metalColor = getStringValue(value);
            productData['Metal Color'] =
                metalColor != null ? [metalColor] : null;
          } else if (header == 'Category') {
            final category = getStringValue(value);
            productData['Category'] = category != null ? [category] : null;
          } else {
            productData[header] = getStringValue(value);
          }
        }

        // assets.media_url is NOT NULL, so a product whose images all failed to
        // upload cannot be submitted. Skip it with a clear reason rather than
        // letting the DB reject the insert with a raw constraint error.
        if (uploadedImageUrls.isEmpty) {
          failCount++;
          debugPrint("Skipping $title: no image uploaded");
          continue;
        }

        // Submit for admin approval instead of writing straight to the catalog.
        // Mirrors sinlgeFile.dart: `source` carries the destination table so
        // approve-product knows where to publish the row on approval.
        final Map<String, dynamic> assetData = {
          'owner_id': user.id,
          'title': title,
          'status': 'pending',
          'source': tableName,
          'description': getStringValue(productData['Description']),
          'category': getStringValue(productData['Product Type']),
          'media_url': uploadedImageUrls.first,
          'thumb_url': uploadedImageUrls.first,
        };

        // Everything else rides in attributes JSONB. Fields promoted to real
        // asset columns above are removed to avoid storing them twice.
        final attributes = Map<String, dynamic>.from(productData);
        attributes.remove('user_id');
        attributes.remove('Description');
        attributes.remove('Product Type');
        // assets.media_url only holds one image; keep the full ordered list so
        // approve-product can restore the Images text[] array intact.
        attributes['Images'] = uploadedImageUrls;
        attributes.removeWhere((key, value) => value == null);
        assetData['attributes'] = attributes;

        try {
          final insertResult =
              await supabase.from('assets').insert(assetData).select();

          if (insertResult.isNotEmpty) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint("Error submitting product $title: $e");
        }
      }

      if (mounted) {
        final catalogType = isManufacturer ? 'Manufacturer' : 'Designer';
        final buffer = StringBuffer(
          failCount == 0
              ? "$successCount products submitted for review. They will appear in the $catalogType catalog once approved."
              : "Submitted $successCount for review, $failCount failed ($catalogType catalog).",
        );
        if (imageWarnings.isNotEmpty) {
          buffer.write("\n${imageWarnings.length} product(s) had image "
              "problems:\n${imageWarnings.take(3).join('\n')}");
          if (imageWarnings.length > 3) {
            buffer.write("\n...and ${imageWarnings.length - 3} more.");
          }
        }
        final hasProblem = failCount > 0 || imageWarnings.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buffer.toString()),
            backgroundColor: hasProblem ? Colors.orange : Colors.green,
            duration: Duration(seconds: hasProblem ? 8 : 3),
          ),
        );
        setState(() {
          _csvFiles = null;
          _imageFiles = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during bulk upload: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Bulk Upload",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bulk Upload",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    "Upload multiple products at once using CSV and images",
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Upload Instructions",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0))),
                      const SizedBox(height: 16),
                      _instructionStep(
                          "1. Download and fill the CSV template with your product data"),
                      const SizedBox(height: 8),
                      _instructionStep(
                          "2. Prepare a folder with product images (named exactly as in CSV)"),
                      const SizedBox(height: 8),
                      _instructionStep(
                          "3. Upload both CSV and images, then validate before submitting"),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _downloadSampleCsv,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text("Download CSV Template"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF448AFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _UploadZone(
                        title: "Upload CSV File *",
                        icon: Icons.description_outlined,
                        mainText: "Upload CSV",
                        subText: "Click to browse files",
                        onTap: _pickCsv,
                        isUploaded: _csvFiles != null,
                        fileName: _csvFiles?.first.name,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _UploadZone(
                        title: "Upload Image Folder *",
                        icon: Icons.folder_open_outlined,
                        mainText: "Upload Images",
                        subText: "Select multiple files",
                        onTap: _pickImages,
                        isUploaded: _imageFiles != null,
                        fileName: _imageFiles != null
                            ? "${_imageFiles!.length} images selected"
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Required CSV Columns:",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _ColumnChip("Product Title"),
                          _ColumnChip("SKU"),
                          _ColumnChip("Product Type"),
                          _ColumnChip("Metal Weight"),
                          _ColumnChip("Gender"),
                          _ColumnChip("Jewelry Type"),
                          _ColumnChip("Metal Type"),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300)),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.black)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBulkUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text("Submit Bulk Upload"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _instructionStep(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF1565C0), height: 1.5));
  }
}

class _UploadZone extends StatelessWidget {
  final String title;
  final IconData icon;
  final String mainText;
  final String subText;
  final VoidCallback onTap;
  final bool isUploaded;
  final String? fileName;

  const _UploadZone({
    required this.title,
    required this.icon,
    required this.mainText,
    required this.subText,
    required this.onTap,
    required this.isUploaded,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            painter: _DottedBorderPainter(color: Colors.grey.shade300),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isUploaded ? Icons.check : icon,
                        color: isUploaded
                            ? const Color(0xFF00BFA5)
                            : Colors.grey.shade400,
                        size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(isUploaded ? "File Selected" : mainText,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    isUploaded ? (fileName ?? "Click to change") : subText,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnChip extends StatelessWidget {
  final String label;
  const _ColumnChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DottedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    final PathMetrics pathMetrics = path.computeMetrics();
    for (final PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double len = (distance + 6 > pathMetric.length)
            ? pathMetric.length - distance
            : 6;
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + len),
          paint,
        );
        distance += 6 + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
