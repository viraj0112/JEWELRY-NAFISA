import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:file_picker/file_picker.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

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
                    Text("Bulk Upload", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Upload multiple products at once with a guided flow", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
    // Headers matching the designerproducts table schema
    final List<String> headers = [
      'Product Title', 'Description', 'Price', 'Product Tags', 'Gold Weight',
      'Metal Purity', 'Metal Finish', 'Stone Weight', 'Stone Type', 'Stone Used',
      'Stone Setting', 'Stone Count', 'Stone Color', 'Stone Cut', 'Stone Purity',
      'Collection Name', 'Product Type', 'Gender', 'Theme', 'Metal Type',
      'Metal Color', 'Net Weight', 'Dimension', 'Design Type', 'Art Form',
      'Plating', 'Enamel Work', 'Customizable', 'Category', 'Sub Category',
      'Plain', 'Studded', 'Category1', 'Category2', 'Category3',
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
      'Product Tags', 'Stone Weight', 'Stone Type', 'Stone Used',
      'Stone Setting', 'Stone Count', 'Stone Color', 'Stone Cut',
      'Stone Purity', 'Enamel Work', 'Customizable', 'Studded',
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
      final input = utf8.decode(_csvFiles!.first.bytes!);
      final fields = const CsvToListConverter().convert(input);
      final headers = fields[0].map((e) => e.toString().trim()).toList();

      int successCount = 0;
      int failCount = 0;

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        final titleIndex = headers.indexOf('Product Title');
        if (titleIndex == -1 || titleIndex >= row.length) {
          debugPrint("Row $i: Missing Product Title");
          failCount++;
          continue;
        }
        
        final title = row[titleIndex].toString().trim();
        if (title.isEmpty) {
          debugPrint("Row $i: Empty Product Title");
          failCount++;
          continue;
        }

        // Find ALL matching image files
        final matchingImageFiles = _imageFiles!.where((file) {
          final fileNameWithoutExt = file.name.split('.').first;
          return fileNameWithoutExt == title || 
                 fileNameWithoutExt.startsWith('$title-Image') ||
                 fileNameWithoutExt.startsWith('$title-image');
        }).toList();

        matchingImageFiles.sort((a, b) => a.name.compareTo(b.name));

        List<String> uploadedImageUrls = [];
        for (final imageFile in matchingImageFiles) {
          try {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}-${imageFile.name}';
            await supabase.storage
                .from('designer-files')
                .uploadBinary(fileName, imageFile.bytes!);
            final imageUrl = supabase.storage.from('designer-files').getPublicUrl(fileName);
            uploadedImageUrls.add(imageUrl);
          } catch (e) {
            debugPrint("Failed to upload image ${imageFile.name}: $e");
          }
        }

        List<String>? parseArrayValue(dynamic value) {
          if (value == null) return null;
          if (value is String) {
            if (value.isEmpty) return null;
            return value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
          }
          return [value.toString()];
        }

        String? getStringValue(dynamic value) {
          if (value == null) return null;
          final str = value.toString().trim();
          return str.isEmpty ? null : str;
        }

        final Map<String, dynamic> productData = {
          'user_id': user.id, // Automatically associate with logged-in user
          'Product Title': title,
          'Image': uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
        };

        for (int j = 0; j < headers.length; j++) {
          if (j >= row.length) continue;
          final header = headers[j];
          final value = row[j];

          if (header == 'Product Title' || header == 'Image') continue;

          if (arrayHeaders.contains(header)) {
            productData[header] = parseArrayValue(value);
          } else {
            productData[header] = getStringValue(value);
          }
        }

        try {
          final insertResult = await supabase
              .from('designerproducts')
              .insert(productData)
              .select();
          
          if (insertResult.isNotEmpty) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint("Error inserting product $title: $e");
        }
      }

      if (mounted) {
        final message = failCount == 0
            ? "Bulk upload successful! $successCount products uploaded."
            : "Upload completed. $successCount succeeded, $failCount failed.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
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
        title: const Text("Bulk Upload", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                const Text("Bulk Upload", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Upload multiple products at once using CSV and images", style: TextStyle(color: Colors.grey, fontSize: 15)),
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
                      const Text("Upload Instructions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                      const SizedBox(height: 16),
                      _instructionStep("1. Download and fill the CSV template with your product data"),
                      const SizedBox(height: 8),
                      _instructionStep("2. Prepare a folder with product images (named exactly as in CSV)"),
                      const SizedBox(height: 8),
                      _instructionStep("3. Upload both CSV and images, then validate before submitting"),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _downloadSampleCsv,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text("Download CSV Template"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF448AFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        fileName: _imageFiles != null ? "${_imageFiles!.length} images selected" : null,
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
                      const Text("Required CSV Columns:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _ColumnChip("Product Title"), // Changed from Image Filename to match logic
                          _ColumnChip("Gold Weight"),
                          _ColumnChip("Metal Type"),
                          _ColumnChip("Product Type"),
                          _ColumnChip("Category"),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.shade300)
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    return Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0), height: 1.5));
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
        Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
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
                    child: Icon(isUploaded ? Icons.check : icon, color: isUploaded ? const Color(0xFF00BFA5) : Colors.grey.shade400, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(isUploaded ? "File Selected" : mainText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(isUploaded ? (fileName ?? "Click to change") : subText, 
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
      child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
