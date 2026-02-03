import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SingleProductUploadCard extends StatelessWidget {
  const SingleProductUploadCard({super.key});


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
          MaterialPageRoute(builder: (_) => const ProductUploadWizard()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FAF3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_outlined, color: Color(0xFF00BFA5)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Single Product Upload", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Upload one product at a time with a guided flow", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 8),
                    _Bullet(text: "Step-by-step process"),
                    _Bullet(text: "Easy for beginners"),
                    _Bullet(text: "Perfect for individual pieces"),
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
        const Icon(Icons.circle, size: 6, color: Color(0xFF00BFA5)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }
}

class ProductUploadWizard extends StatefulWidget {
  const ProductUploadWizard({super.key});

  @override
  State<ProductUploadWizard> createState() => _ProductUploadWizardState();
}

class _ProductUploadWizardState extends State<ProductUploadWizard> {
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  List<Uint8List> _allImageBytes = [];
  final List<XFile> _images = [];
  Uint8List? imageBytes;
  String? fileName;
  bool _isUploading = false;
  
  int step = 0;

  final designCtrl = TextEditingController();
  final goldCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final tagsCtrl = TextEditingController();

  String? metalType;
  String? productType;
  String? category;
  String visibility = 'Public';

  final steps = ['Upload', 'Details', 'Visibility', 'Publish'];

  bool get _isStepValid {
  switch (step) {
    case 0:
      // Valid if at least one image is uploaded
      return _images.isNotEmpty;
    case 1:
      // Valid if Gold Weight is not empty and Dropdowns are selected
      return designCtrl.text.isNotEmpty && 
      goldCtrl.text.isNotEmpty && 
             metalType != null && 
             productType != null && 
             category != null;
    case 2:
      // Visibility always has a default ('Public'), so it's usually valid
      return true;
    default:
      return true;
  }
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color.fromARGB(255, 0, 0, 0)), onPressed: () => Navigator.pop(context)),
        title: const Text('Upload Product', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          _StepperHeader(step: step, steps: steps, isMobile: isMobile),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: _content(),
            ), 
          ),
          _BottomNav(
            step: step,
            max: steps.length - 1,
            isStepValid: _isStepValid,
            isUploading: _isUploading,
            onBack: () => setState(() => step--),
            onNext: () => setState(() => step++),
            onPublish: _publishProduct,
            isMobile: isMobile,
          )
        ],
      ),
    );
  }

  Widget _content() {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upload Images', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add photos of your jewellery product', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          if (_images.isEmpty)
             _buildUploadBox()
          else
            _buildImagePreviewList(),
        ]);

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Text('Product Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fill in the required information', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _field('Design Name *', designCtrl, hintText: 'e.g., Royal Kundan Necklace'),
            _field('Gold Weight (g) *', goldCtrl, number: true, hintText: 'e.g., 45.5'),
            _dropdown('Metal Type *', ['18K Gold', '22K Gold'], metalType, (v) => setState(() => metalType = v), hintText: 'Select metal type'),
            _dropdown('Product Type *', ['Necklace', 'Ring', 'Bracelet'], productType, (v) => setState(() => productType = v), hintText: 'Select product type'),
            _dropdown('Category *', ['Daily Wear', 'Wedding', 'Traditional'], category, (v) => setState(() => category = v), hintText: 'Select category'),
            _field('Description (Optional)', descCtrl, lines: 3, hintText: 'Add details about your product...'),
            _field('Tags (Optional)', tagsCtrl, hintText: 'e.g., wedding, kundan, traditional'),
          ], 
        );

      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Visibility Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Choose who can see detailed insights', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _radio('Public', 'Everyone can view full insights'),
          const SizedBox(height: 16),
          _radio('Member Only', 'Only paid members can view full insights', premium: true),
        ]);

      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Review & Publish', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Check everything looks good', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB), // Very light grey background
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Preview
                if (_images.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(_images.first.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (_images.length > 1) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 180,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _images.skip(1).take(4).map((file) {
                              return Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: DecorationImage(
                                    image: NetworkImage(file.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (_images.length > 5)
                           Padding(
                             padding: const EdgeInsets.only(top: 4),
                             child: Text('+${_images.length - 5} more', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                           ),
                      ]
                    ],
                  )
                else
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                  ),
                  
                const SizedBox(width: 32),
                
                // Details Grid
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _reviewItem('Design Name', designCtrl.text.isEmpty ? '-' : designCtrl.text),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _reviewItem('Gold Weight', '${goldCtrl.text}g')),
                          Expanded(child: _reviewItem('Metal Type', metalType ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _reviewItem('Product Type', productType ?? '-')),
                          Expanded(child: _reviewItem('Category', category ?? '-')),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _reviewItem('Description', descCtrl.text.isEmpty ? '-' : descCtrl.text),
                      const SizedBox(height: 20),
                      _reviewItem('Visibility', visibility),
                    ],
                  ),
                ),
              ],
            ),
          )
        ]);
    }
  }

  Widget _field(String label, TextEditingController c, {String? hintText, bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          onChanged: (value) => setState(() {}), 
          keyboardType: number ? TextInputType.number : TextInputType.text,
          maxLines: lines,
          decoration: InputDecoration(
            isDense: true, 
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,   
              horizontal: 12, 
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          
        ),
      ]),
    );
  }

  Widget _dropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged, {String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField(
          value: value, 
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
          onChanged: onChanged, 
          hint: hintText != null ? Text(hintText, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)) : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          )
        ),
      ]),
    );
  }

  Widget _radio(String value, String subtitle, {bool premium = false}) {
    final bool isSelected = visibility == value;
    return GestureDetector(
      onTap: () => setState(() => visibility = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BFA5) : Colors.grey.shade300, 
            width: isSelected ? 2 : 1
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // Align to center vertically
          children: [
            // Radio Circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00BFA5) : Colors.grey.shade400,
                  width: 2
                ),
              ),
              child: isSelected 
                  ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00BFA5), shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      if (premium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Text('Premium', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                        )
                      ]
                    ], 
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  Widget _reviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }

  Widget _buildUploadBox({bool isSmall = false}) {
    return GestureDetector(
      onTap: _pickImages,
      child: CustomPaint(
        painter: _DottedBorderPainter(color: Colors.grey.shade400),
        child: Container(
          height: isSmall ? 80 : 250,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isSmall 
            ? [
                 const Text('+ Add more images', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))
              ]
            : [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.image_outlined, size: 32, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Click to upload images', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('PNG, JPG up to 10MB each', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviewList() {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _images.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(file.path),
                      fit: BoxFit.cover,
                    ),
                    color: Colors.grey.shade200,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        _buildUploadBox(isSmall: true),
      ],
    );
  }

  Future<void> _pickImages() async {
    final List<XFile> selectedFiles = await _picker.pickMultiImage(imageQuality: 85);
    if (selectedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(selectedFiles);
      });
    }
  }

  Future<void> _publishProduct() async {
    // 1. Check authentication
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to upload products.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 2. Upload images to designer-files storage bucket
      List<String> uploadedImageUrls = [];
      
      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}-${user.id}-${i + 1}.jpg';
        
        try {
          await _supabase.storage
              .from('designer-files')
              .uploadBinary(fileName, bytes);
          
          final imageUrl = _supabase.storage
              .from('designer-files')
              .getPublicUrl(fileName);
          
          uploadedImageUrls.add(imageUrl);
        } catch (e) {
          debugPrint('Error uploading image ${i + 1}: $e');
          // Continue with other images even if one fails
        }
      }

      // 3. Prepare product data
      final Map<String, dynamic> productData = {
        'user_id': user.id, // Automatically associate with logged-in user
        'Product Title': designCtrl.text.trim(),
        'Image': uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
        'Gold Weight': goldCtrl.text.trim(),
        'Metal Type': metalType,
        'Product Type': productType,
        'Category': category,
        'Description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'Product Tags': tagsCtrl.text.trim().isEmpty 
            ? null 
            : tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      };

      // 4. Insert to designerproducts table
      final result = await _supabase
          .from('designerproducts')
          .insert(productData)
          .select();

      if (mounted) {
        if (result.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product published successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Navigate back to B2B home after successful upload
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          throw Exception('Failed to insert product');
        }
      }
    } catch (e) {
      debugPrint('Error publishing product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing product: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

}



class _StepperHeader extends StatelessWidget {
  final int step;
  final List<String> steps;
  final bool isMobile;
  const _StepperHeader({required this.step, required this.steps, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 16 : 24, 
        horizontal: isMobile ? 16 : 48
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: List.generate(steps.length, (i) {
          final isCompleted = i < step;
          final isActive = i == step;
          final isLast = i == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: isMobile ? 12 : 14,
                      backgroundColor: (isCompleted || isActive) 
                          ? const Color(0xFF00BFA5) 
                          : Colors.grey.shade200,
                      child: isCompleted
                          ? Icon(Icons.check, size: isMobile ? 14 : 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey,
                                fontSize: isMobile ? 10 : 12,
                              ),
                            ),
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.black : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? const Color(0xFF00BFA5) : Colors.grey.shade200,
                      margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int step;
  final int max;
  final bool isStepValid;
  final bool isUploading;
  final bool isMobile;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onPublish;

  const _BottomNav({
    required this.step,
    required this.max,
    required this.isStepValid,
    this.isUploading = false,
    this.isMobile = false,
    required this.onBack,
    required this.onNext,
    required this.onPublish
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (step > 0)
            Flexible(
              flex: isMobile ? 1 : 0,
              child: SizedBox(
                width: isMobile ? null : 100, 
                child: OutlinedButton(
                  onPressed: onBack, 
                  child: const Text('Back')
                )
              ),
            ),
          if (step > 0) SizedBox(width: isMobile ? 8 : 12),
          Flexible(
            flex: isMobile ? 2 : 0,
            child: SizedBox(
              width: isMobile ? null : 500,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  disabledBackgroundColor: Colors.grey.shade300, 
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                onPressed: (isStepValid && !isUploading)
                  ? (step == max ? onPublish : onNext) 
                  : null, 
                child: isUploading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(step == max ? 'Publish Product' : 'Next Step >'),
              )
            ),
          )
        ],
      ),
      
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
