import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:csv/csv.dart';

class ProductEntry {
  final int id;
  List<XFile> imageFiles = [];
  final TextEditingController productTitleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController productTagsController = TextEditingController();
  final TextEditingController goldWeightController = TextEditingController();
  final TextEditingController metalPurityController = TextEditingController();
  final TextEditingController metalFinishController = TextEditingController();
  final TextEditingController stoneWeightController = TextEditingController();
  final TextEditingController stoneTypeController = TextEditingController();
  String? stoneUsed;
  final TextEditingController stoneSettingController = TextEditingController();
  final TextEditingController stoneCountController = TextEditingController();
  final TextEditingController collectionNameController =
      TextEditingController();
  final TextEditingController productTypeController = TextEditingController();
  String? gender;
  final TextEditingController themeController = TextEditingController();
  final TextEditingController metalTypeController = TextEditingController();
  final TextEditingController metalColorController = TextEditingController();
  final TextEditingController netWeightController = TextEditingController();
  final TextEditingController stoneColorController = TextEditingController();
  final TextEditingController stoneCutController = TextEditingController();
  final TextEditingController dimensionController = TextEditingController();
  String? designType;
  final TextEditingController artFormController = TextEditingController();
  final TextEditingController platingController = TextEditingController();
  final TextEditingController enamelWorkController = TextEditingController();
  String? customizable;

  ProductEntry({required this.id});

  void dispose() {
    productTitleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    productTagsController.dispose();
    goldWeightController.dispose();
    metalPurityController.dispose();
    metalFinishController.dispose();
    stoneWeightController.dispose();
    stoneTypeController.dispose();
    stoneSettingController.dispose();
    stoneCountController.dispose();
    collectionNameController.dispose();
    productTypeController.dispose();
    themeController.dispose();
    metalTypeController.dispose();
    metalColorController.dispose();
    netWeightController.dispose();
    stoneColorController.dispose();
    stoneCutController.dispose();
    dimensionController.dispose();
    artFormController.dispose();
    platingController.dispose();
    enamelWorkController.dispose();
  }
}

class B2BProductUploadScreen extends StatefulWidget {
  const B2BProductUploadScreen({super.key});

  @override
  State<B2BProductUploadScreen> createState() => _B2BProductUploadScreenState();
}

class _B2BProductUploadScreenState extends State<B2BProductUploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: "Manual Upload"),
          Tab(text: "Bulk Upload"),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ManualUploadTab(),
          BulkUploadTab(),
        ],
        ),
      ),
    );
  }
}

class ManualUploadTab extends StatefulWidget {
  const ManualUploadTab({super.key});

  @override
  _ManualUploadTabState createState() => _ManualUploadTabState();
}

class _ManualUploadTabState extends State<ManualUploadTab> {
  final _formKey = GlobalKey<FormState>();
  List<ProductEntry> _productEntries = [ProductEntry(id: 1)];
  bool _isLoading = false;

  void _addProductEntry() {
    setState(() {
      _productEntries
          .add(ProductEntry(id: DateTime.now().millisecondsSinceEpoch));
    });
  }

  void _removeProductEntry(int id) {
    setState(() {
      final entry = _productEntries.firstWhere((e) => e.id == id);
      entry.dispose();
      _productEntries.removeWhere((e) => e.id == id);
    });
  }

  @override
  void dispose() {
    for (var entry in _productEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ProductEntry entry) async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        entry.imageFiles.addAll(pickedFiles);
      });
    }
  }

  void _removeImage(ProductEntry entry) {
    setState(() {
      entry.imageFiles.clear();
    });
  }

  Future<void> _submitAllForApproval() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please fill all required fields before submitting.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      int successCount = 0;
      
      for (final entry in _productEntries) {
        if (entry.imageFiles.isEmpty) continue;

        List<String> uploadedImageUrls = [];

        // Upload ALL images to designer-files bucket
        for (final imageFile in entry.imageFiles) {
          final fileBytes = await imageFile.readAsBytes();
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}-${imageFile.name}';
          await supabase.storage
              .from('designer-files')
              .uploadBinary(fileName, fileBytes);
          final imageUrl =
              supabase.storage.from('designer-files').getPublicUrl(fileName);
          uploadedImageUrls.add(imageUrl);
        }

        // Helper functions for array fields
        List<String>? textToList(TextEditingController controller) {
          final text = controller.text.trim();
          return text.isEmpty ? null : [text];
        }

        List<String>? tagsToList(TextEditingController controller) {
          final text = controller.text.trim();
          return text.isEmpty
              ? null
              : text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }

        String? getTextValue(TextEditingController controller) {
          final text = controller.text.trim();
          return text.isEmpty ? null : text;
        }

        // Insert directly into designerproducts table with proper column names
        final insertResult = await supabase.from('designerproducts').insert({
          'Product Title': entry.productTitleController.text.trim(),
          'Description': getTextValue(entry.descriptionController),
          'Image': uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
          'Price': getTextValue(entry.priceController),
          'Product Tags': tagsToList(entry.productTagsController),
          'Gold Weight': getTextValue(entry.goldWeightController),
          'Metal Purity': getTextValue(entry.metalPurityController),
          'Metal Finish': getTextValue(entry.metalFinishController),
          'Stone Weight': textToList(entry.stoneWeightController),
          'Stone Type': textToList(entry.stoneTypeController),
          'Stone Used': entry.stoneUsed == null ? null : [entry.stoneUsed],
          'Stone Setting': textToList(entry.stoneSettingController),
          'Stone Count': textToList(entry.stoneCountController),
          'Collection Name': getTextValue(entry.collectionNameController),
          'Product Type': getTextValue(entry.productTypeController),
          'Gender': entry.gender,
          'Theme': getTextValue(entry.themeController),
          'Metal Type': getTextValue(entry.metalTypeController),
          'Metal Color': getTextValue(entry.metalColorController),
          'Net Weight': getTextValue(entry.netWeightController),
          'Stone Color': textToList(entry.stoneColorController),
          'Stone Cut': textToList(entry.stoneCutController),
          'Dimension': getTextValue(entry.dimensionController),
          'Design Type': entry.designType,
          'Art Form': getTextValue(entry.artFormController),
          'Plating': getTextValue(entry.platingController),
          'Enamel Work': textToList(entry.enamelWorkController),
          'Customizable': entry.customizable == null ? null : [entry.customizable],
        }).select();
        
        if (insertResult.isEmpty) {
          throw Exception('Insert was rejected for "${entry.productTitleController.text}". Please check your permissions.');
        }
        successCount++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("$successCount product(s) uploaded successfully!"),
              backgroundColor: Colors.green),
        );
        setState(() {
          for (var entry in _productEntries) {
            entry.dispose();
          }
          _productEntries = [ProductEntry(id: 1)];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _productEntries.length,
              itemBuilder: (context, index) {
                final entry = _productEntries[index];
                return ProductFormCard(
                  key: ValueKey(entry.id),
                  entry: entry,
                  onRemove: () => _removeProductEntry(entry.id),
                  onPickImage: () => _pickImage(entry),
                  onRemoveImage: () => _removeImage(entry),
                  isFirst: index == 0,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _addProductEntry,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Another Product"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitAllForApproval,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Submit All for Review"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BulkUploadTab extends StatefulWidget {
  const BulkUploadTab({super.key});

  @override
  _BulkUploadTabState createState() => _BulkUploadTabState();
}

class _BulkUploadTabState extends State<BulkUploadTab> {
  List<PlatformFile>? _csvFiles;
  List<PlatformFile>? _imageFiles;
  bool _isLoading = false;

  void _downloadSampleCsv() {
    // Headers matching the designerproducts table schema
    // Note: 'Image' column is not needed in CSV - images are matched by file name
    final List<String> headers = [
      'Product Title',
      'Description',
      'Price',
      'Product Tags',
      'Gold Weight',
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
      'Collection Name',
      'Product Type',
      'Gender',
      'Theme',
      'Metal Type',
      'Metal Color',
      'Net Weight',
      'Dimension',
      'Design Type',
      'Art Form',
      'Plating',
      'Enamel Work',
      'Customizable',
      'Category',
      'Sub Category',
      'Plain',
      'Studded',
      'Category1',
      'Category2',
      'Category3',
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      setState(() {
        _csvFiles = result.files;
      });
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _imageFiles = result.files;
      });
    }
  }

  Future<void> _submitBulkUpload() async {
    if (_csvFiles == null || _imageFiles == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a CSV file and images.")),
      );
      return;
    }

    // Headers that should be stored as arrays in designerproducts table
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

        // Find ALL matching image files using pattern: {Product Title}-Image*
        // This matches files like "Gold Ring-Image1.jpg", "Gold Ring-Image2.png", etc.
        final matchingImageFiles = _imageFiles!.where((file) {
          final fileNameWithoutExt = file.name.split('.').first;
          // Match exact title OR title followed by -Image (for multiple images)
          return fileNameWithoutExt == title || 
                 fileNameWithoutExt.startsWith('$title-Image') ||
                 fileNameWithoutExt.startsWith('$title-image');
        }).toList();

        // Sort to ensure consistent ordering (Image1, Image2, etc.)
        matchingImageFiles.sort((a, b) => a.name.compareTo(b.name));

        List<String> uploadedImageUrls = [];

        // Upload all matching images to designer-files bucket
        for (final imageFile in matchingImageFiles) {
          try {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}-${imageFile.name}';
            await supabase.storage
                .from('designer-files')
                .uploadBinary(fileName, imageFile.bytes!);
            final imageUrl =
                supabase.storage.from('designer-files').getPublicUrl(fileName);
            uploadedImageUrls.add(imageUrl);
          } catch (e) {
            debugPrint("Failed to upload image ${imageFile.name}: $e");
          }
        }

        if (uploadedImageUrls.isEmpty) {
          debugPrint("No images uploaded for product: $title");
          // Continue without images - some products might not have images
        }

        // Helper function to convert comma-separated values to array
        List<String>? parseArrayValue(dynamic value) {
          if (value == null) return null;
          if (value is String) {
            if (value.isEmpty) return null;
            return value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
          }
          return [value.toString()];
        }

        // Helper function to get string value
        String? getStringValue(dynamic value) {
          if (value == null) return null;
          final str = value.toString().trim();
          return str.isEmpty ? null : str;
        }

        // Build the product data matching designerproducts table schema
        final Map<String, dynamic> productData = {
          'Product Title': title,
          'Image': uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
        };

        // Map CSV columns to designerproducts columns
        for (int j = 0; j < headers.length; j++) {
          if (j >= row.length) continue;
          
          final header = headers[j];
          final value = row[j];

          // Skip Product Title and Image - already handled
          if (header == 'Product Title' || header == 'Image') continue;

          if (arrayHeaders.contains(header)) {
            productData[header] = parseArrayValue(value);
          } else {
            productData[header] = getStringValue(value);
          }
        }

        try {
          // Insert directly into designerproducts table
          final insertResult = await supabase
              .from('designerproducts')
              .insert(productData)
              .select();
          
          if (insertResult.isNotEmpty) {
            successCount++;
            debugPrint("Successfully inserted product: $title");
          } else {
            failCount++;
            debugPrint("Failed to insert product: $title - Insert returned empty");
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(height: 8),
                      const Text(
                        "Image Naming Convention:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "For single image: {Product Title}.jpg\n"
                        "For multiple images: {Product Title}-Image1.jpg, {Product Title}-Image2.jpg, etc.\n\n"
                        "Example: If your product title is 'Gold Ring', name your images:\n"
                        "• Gold Ring.jpg (or Gold Ring-Image1.jpg)\n"
                        "• Gold Ring-Image2.jpg\n"
                        "• Gold Ring-Image3.jpg",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _downloadSampleCsv,
                        child: const Text("Download Sample CSV"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickCsv,
                icon: const Icon(Icons.upload_file),
                label: const Text("Upload CSV"),
              ),
              if (_csvFiles != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Selected CSV: ${_csvFiles!.first.name}"),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image),
                label: const Text("Upload Image Folder"),
              ),
              if (_imageFiles != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("${_imageFiles!.length} images selected"),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitBulkUpload,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Submit Bulk Upload"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductFormCard extends StatefulWidget {
  final ProductEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final bool isFirst;

  const ProductFormCard({
    super.key,
    required this.entry,
    required this.onRemove,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.isFirst,
  });

  @override
  _ProductFormCardState createState() => _ProductFormCardState();
}

class _ProductFormCardState extends State<ProductFormCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Product #${widget.key}",
                    style: Theme.of(context).textTheme.headlineSmall),
                if (!widget.isFirst)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildImagePicker(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: _buildFormFields(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: widget.entry.imageFiles.isEmpty
                ? InkWell(
                    onTap: widget.onPickImage,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48),
                          SizedBox(height: 8),
                          Text("Select Images"),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      // Show the first image as preview
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(widget.entry.imageFiles.first.path,
                                  fit: BoxFit.cover)
                              : Image.file(File(widget.entry.imageFiles.first.path),
                                  fit: BoxFit.cover),
                        ),
                      ),
                      // Badge showing count
                      if (widget.entry.imageFiles.length > 1)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${widget.entry.imageFiles.length - 1} more',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: widget.onRemoveImage,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.entry.productTitleController,
          decoration: const InputDecoration(labelText: "Product Title"),
          validator: (v) => v!.isEmpty ? "Product Title is required" : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.descriptionController,
          decoration: const InputDecoration(labelText: "Description"),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.priceController,
          decoration: const InputDecoration(labelText: "Price"),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.productTagsController,
          decoration: const InputDecoration(
              labelText: "Product Tags (comma-separated)"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.goldWeightController,
          decoration: const InputDecoration(labelText: "Gold Weight"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.metalPurityController,
          decoration: const InputDecoration(labelText: "Metal Purity"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.metalFinishController,
          decoration: const InputDecoration(labelText: "Metal Finish"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneWeightController,
          decoration: const InputDecoration(labelText: "Stone Weight"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneTypeController,
          decoration: const InputDecoration(labelText: "Stone Type"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: widget.entry.stoneUsed,
          decoration: const InputDecoration(labelText: "Stone Used"),
          items: ['Natural', 'Lab-created', 'Synthetic']
              .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)))
              .toList(),
          onChanged: (value) {
            setState(() {
              widget.entry.stoneUsed = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneSettingController,
          decoration: const InputDecoration(labelText: "Stone Setting"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneCountController,
          decoration: const InputDecoration(labelText: "Stone Count"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.collectionNameController,
          decoration: const InputDecoration(labelText: "Collection Name"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.productTypeController,
          decoration: const InputDecoration(labelText: "Product Type"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: widget.entry.gender,
          decoration: const InputDecoration(labelText: "Gender"),
          items: ['Women', 'Men', 'Unisex', 'Kids']
              .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)))
              .toList(),
          onChanged: (value) {
            setState(() {
              widget.entry.gender = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.themeController,
          decoration: const InputDecoration(labelText: "Theme"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.metalTypeController,
          decoration: const InputDecoration(labelText: "Metal Type"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.metalColorController,
          decoration: const InputDecoration(labelText: "Metal Color"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.netWeightController,
          decoration: const InputDecoration(labelText: "NET WEIGHT"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneColorController,
          decoration: const InputDecoration(labelText: "Stone Color"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.stoneCutController,
          decoration: const InputDecoration(labelText: "Stone Cut"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.dimensionController,
          decoration: const InputDecoration(labelText: "Dimension"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: widget.entry.designType,
          decoration: const InputDecoration(labelText: "Design Type"),
          items: ['Handcrafted', 'Machine-made', '3D cast']
              .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)))
              .toList(),
          onChanged: (value) {
            setState(() {
              widget.entry.designType = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.artFormController,
          decoration: const InputDecoration(labelText: "Art Form"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.platingController,
          decoration: const InputDecoration(labelText: "Plating"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.entry.enamelWorkController,
          decoration: const InputDecoration(labelText: "Enamel Work"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: widget.entry.customizable,
          decoration: const InputDecoration(labelText: "Customizable"),
          items: ['Yes', 'No']
              .map(
                  (label) => DropdownMenuItem(value: label, child: Text(label)))
              .toList(),
          onChanged: (value) {
            setState(() {
              widget.entry.customizable = value;
            });
          },
        ),
      ],
    );
  }
}

