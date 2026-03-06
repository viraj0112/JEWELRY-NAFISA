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
                child:
                    const Icon(Icons.upload_outlined, color: Color(0xFF00BFA5)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Single Product Upload",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text("Upload one product at a time with a guided flow",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  // --- Controllers ---
  final productTitleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final metalWeightCtrl = TextEditingController();
  final goldNetWeightCtrl = TextEditingController();
  final metalColorCtrl = TextEditingController();
  final stoneCountCtrl = TextEditingController();
  final stoneColorCtrl = TextEditingController();
  final dimensionCtrl = TextEditingController();
  final enamelWorkCtrl = TextEditingController();
  final collectionNameCtrl = TextEditingController();
  final themeCtrl = TextEditingController();

  // --- Dropdown state ---
  String? metalType;
  String? metalPurity;
  String? productType;
  String? metalFinish;
  String? gender;
  String? jewelryType;
  String? stoneType;
  String? stoneUsed;
  String? stoneSetting;
  String? stoneCut;
  String visibility = 'Public';

  // --- Dynamic data ---
  List<String> _productTypes = [];
  bool _loadingProductTypes = true;

  // --- Purity options based on metal type ---
  List<String> get _metalPurityOptions {
    switch (metalType) {
      case 'Gold':
        return ['22KT', '18KT', '14KT', '9KT'];
      case 'Silver':
        return ['958', '925', '800', '700'];
      case 'Platinum':
        return ['950', '900', '850'];
      default:
        return [];
    }
  }

  static const List<String> _metalFinishOptions = [
    'High Polish',
    'Glossy',
    'Matte',
    'Satin',
    'Antique Finish',
    'Textured',
    'Brushed',
    'Sandblasted',
    'Hammered',
    'Dual Tone / Triple Tone',
  ];

  static const List<String> _stoneTypeOptions = [
    'Diamond',
    'Gemstone',
    'Labgrown Diamond',
    'Labgrown Gemstone',
    'CZ/American Diamond',
    'Moissanite',
  ];

  static const List<String> _stoneUsedOptions = [
    'VVS',
    'VS',
    'SI',
    'I',
    'IGS',
    'Synthetic',
    'Natural',
    'Lab-created',
  ];

  static const List<String> _stoneSettingOptions = [
    'Prong',
    'Bezel',
    'Pave',
    'Micro-Pave',
    'Channel',
    'Bar',
    'Flush (Gypsy)',
    'Tension',
    'Tension-Style',
    'Halo',
    'Cluster',
    'Invisible',
    'Illusion',
    'Basket',
    'Cathedral',
    'Pressure',
    'Floating',
    'Shared-Prong',
    'Grain/Bead',
  ];

  static const List<String> _stoneCutOptions = [
    'Round',
    'Princess',
    'Emerald',
    'Asscher',
    'Cushion',
    'Oval',
    'Pear',
    'Marquise',
    'Radiant',
    'Heart',
    'Trillion',
    'Baguette',
    'Tapered Baguette',
    'Square',
    'Rose Cut',
    'Old Mine Cut',
    'Old European Cut',
    'Cabochon',
  ];

  final steps = ['Upload', 'Details', 'Visibility', 'Publish'];

  @override
  void initState() {
    super.initState();
    _fetchProductTypes();
  }

  Future<void> _fetchProductTypes() async {
    try {
      final responses = await Future.wait([
        _supabase
            .from('products')
            .select('"Product Type"')
            .not('Product Type', 'is', null),
        _supabase
            .from('designerproducts')
            .select('"Product Type"')
            .not('Product Type', 'is', null),
      ]);

      final Set<String> uniqueTypes = {};
      for (var response in responses) {
        if (response is List) {
          for (var item in response) {
            final type = item['Product Type']?.toString().trim();
            if (type != null && type.isNotEmpty) {
              uniqueTypes.add(type);
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _productTypes = uniqueTypes.toList()..sort();
          _loadingProductTypes = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching product types: $e');
      if (mounted) {
        setState(() => _loadingProductTypes = false);
      }
    }
  }

  @override
  void dispose() {
    productTitleCtrl.dispose();
    descCtrl.dispose();
    metalWeightCtrl.dispose();
    goldNetWeightCtrl.dispose();
    metalColorCtrl.dispose();
    stoneCountCtrl.dispose();
    stoneColorCtrl.dispose();
    dimensionCtrl.dispose();
    enamelWorkCtrl.dispose();
    collectionNameCtrl.dispose();
    themeCtrl.dispose();
    super.dispose();
  }

  bool get _isStepValid {
    switch (step) {
      case 0:
        return _images.isNotEmpty;
      case 1:
        return productTitleCtrl.text.isNotEmpty &&
            metalType != null &&
            metalPurity != null &&
            productType != null &&
            metalWeightCtrl.text.isNotEmpty &&
            gender != null &&
            jewelryType != null &&
            goldNetWeightCtrl.text.isNotEmpty;
      case 2:
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
        leading: IconButton(
            icon: const Icon(Icons.close, color: Color.fromARGB(255, 0, 0, 0)),
            onPressed: () => Navigator.pop(context)),
        title:
            const Text('Upload Product', style: TextStyle(color: Colors.black)),
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
          const Text('Upload Images',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add photos of your jewellery product',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          if (_images.isEmpty) _buildUploadBox() else _buildImagePreviewList(),
        ]);

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Product Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fill in the required information',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // --- Product Title ---
            _field('Product Title *', productTitleCtrl,
                hintText: 'e.g., Royal Kundan Necklace'),

            // --- Description ---
            _field('Description', descCtrl,
                lines: 3, hintText: 'Add details about your product...'),

            // --- Metal Type ---
            _dropdown('Metal Type *', ['Gold', 'Silver', 'Platinum'], metalType,
                (v) {
              setState(() {
                metalType = v;
                metalPurity = null; // Reset purity when metal type changes
              });
            }, hintText: 'Select metal type'),

            // --- Metal Purity (conditional) ---
            if (metalType != null)
              _dropdown('Metal Purity *', _metalPurityOptions, metalPurity,
                  (v) => setState(() => metalPurity = v),
                  hintText: 'Select metal purity'),

            // --- Product Type (from Supabase) ---
            if (_loadingProductTypes)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading product types...',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              )
            else
              _dropdown('Product Type *', _productTypes, productType,
                  (v) => setState(() => productType = v),
                  hintText: 'Select product type'),

            // --- Metal Weight ---
            _field('Metal Weight (in grams) *', metalWeightCtrl,
                number: true, hintText: 'e.g., 45.5'),

            // --- Metal Color ---
            _field('Metal Color', metalColorCtrl,
                hintText: 'e.g., Yellow, Rose, White'),

            // --- Metal Finish ---
            _dropdown('Metal Finish', _metalFinishOptions, metalFinish,
                (v) => setState(() => metalFinish = v),
                hintText: 'Select metal finish'),

            // --- Gender ---
            _dropdown('Gender *', ['Women', 'Men', 'Unisex', 'Kids'], gender,
                (v) => setState(() => gender = v),
                hintText: 'Select gender'),

            // --- Jewelry Type ---
            _dropdown('Jewelry Type *', ['Studded', 'Plain'], jewelryType, (v) {
              setState(() {
                jewelryType = v;
                // Reset stone fields when switching
                if (v == 'Plain') {
                  stoneType = null;
                  stoneUsed = null;
                  stoneSetting = null;
                  stoneCountCtrl.clear();
                  stoneColorCtrl.clear();
                  stoneCut = null;
                }
              });
            }, hintText: 'Select jewelry type'),

            // --- Gold Net Weight ---
            _field('Gold Net Weight (in grams) *', goldNetWeightCtrl,
                number: true, hintText: 'e.g., 12.5'),

            // --- Stone fields (only if Studded) ---
            if (jewelryType == 'Studded') ...[
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: Text('Stone Details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00BFA5))),
              ),
              _dropdown('Stone Type', _stoneTypeOptions, stoneType,
                  (v) => setState(() => stoneType = v),
                  hintText: 'e.g., Diamond, Gemstone'),
              _dropdown('Stone Used', _stoneUsedOptions, stoneUsed,
                  (v) => setState(() => stoneUsed = v),
                  hintText: 'e.g., VVS, IGS, Synthetic'),
              _dropdown('Stone Setting', _stoneSettingOptions, stoneSetting,
                  (v) => setState(() => stoneSetting = v),
                  hintText: 'e.g., Prong, Bezel, Pave'),
              _field('Stone Count', stoneCountCtrl,
                  hintText: 'e.g., 3 Ruby, 4 Diamond'),
              _field('Stone Color', stoneColorCtrl,
                  hintText: 'e.g., Red, Blue, Green'),
              _dropdown('Stone Cut', _stoneCutOptions, stoneCut,
                  (v) => setState(() => stoneCut = v),
                  hintText: 'e.g., Round, Princess, Emerald'),
            ],

            // --- Dimension ---
            _field('Dimension', dimensionCtrl,
                hintText: 'e.g., Length x Width x Height'),

            // --- Enamel Work + Weight ---
            _field('Enamel Work + Weight', enamelWorkCtrl,
                hintText: 'e.g., Pink 0.6g, Blue 4g'),

            // --- Collection Name ---
            _field('Collection Name', collectionNameCtrl,
                hintText: 'e.g., Heritage Collection'),

            // --- Theme ---
            _field('Theme', themeCtrl,
                hintText: 'e.g., Bridal, Festive, Contemporary'),
          ],
        );

      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Visibility Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Choose who can see detailed insights',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _radio('Public', 'Everyone can view full insights'),
          const SizedBox(height: 16),
          _radio('Member Only', 'Only paid members can view full insights',
              premium: true),
        ]);

      default:
        return _buildReviewStep();
    }
  }

  Widget _buildReviewStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Review & Publish',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Check everything looks good',
          style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 900),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview Row
            if (_images.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(_images[i].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Details Grid
            _reviewItem('Product Title',
                productTitleCtrl.text.isEmpty ? '-' : productTitleCtrl.text),
            const SizedBox(height: 12),
            _reviewItem(
                'Description', descCtrl.text.isEmpty ? '-' : descCtrl.text),
            const SizedBox(height: 16),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _reviewItem('Metal Type', metalType ?? '-'),
                _reviewItem('Metal Purity', metalPurity ?? '-'),
                _reviewItem('Product Type', productType ?? '-'),
                _reviewItem('Metal Weight', '${metalWeightCtrl.text}g'),
                _reviewItem('Metal Color',
                    metalColorCtrl.text.isEmpty ? '-' : metalColorCtrl.text),
                _reviewItem('Metal Finish', metalFinish ?? '-'),
                _reviewItem('Gender', gender ?? '-'),
                _reviewItem('Jewelry Type', jewelryType ?? '-'),
                _reviewItem('Gold Net Weight', '${goldNetWeightCtrl.text}g'),
              ],
            ),
            if (jewelryType == 'Studded') ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Stone Details',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF00BFA5))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _reviewItem('Stone Type', stoneType ?? '-'),
                  _reviewItem('Stone Used', stoneUsed ?? '-'),
                  _reviewItem('Stone Setting', stoneSetting ?? '-'),
                  _reviewItem('Stone Count',
                      stoneCountCtrl.text.isEmpty ? '-' : stoneCountCtrl.text),
                  _reviewItem('Stone Color',
                      stoneColorCtrl.text.isEmpty ? '-' : stoneColorCtrl.text),
                  _reviewItem('Stone Cut', stoneCut ?? '-'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _reviewItem('Dimension',
                    dimensionCtrl.text.isEmpty ? '-' : dimensionCtrl.text),
                _reviewItem('Enamel Work',
                    enamelWorkCtrl.text.isEmpty ? '-' : enamelWorkCtrl.text),
                _reviewItem(
                    'Collection',
                    collectionNameCtrl.text.isEmpty
                        ? '-'
                        : collectionNameCtrl.text),
                _reviewItem(
                    'Theme', themeCtrl.text.isEmpty ? '-' : themeCtrl.text),
                _reviewItem('Visibility', visibility),
              ],
            ),
          ],
        ),
      )
    ]);
  }

  Widget _field(String label, TextEditingController c,
      {String? hintText, bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ]),
    );
  }

  Widget _dropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged,
      {String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField(
            value: value,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            hint: hintText != null
                ? Text(hintText,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14))
                : null,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            )),
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
              color:
                  isSelected ? const Color(0xFF00BFA5) : Colors.grey.shade300,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.grey.shade400,
                    width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: Color(0xFF00BFA5),
                              shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                          child: Text(value,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16))),
                      if (premium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Text('Premium',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800)),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
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
                    const Text('+ Add more images',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.w500))
                  ]
                : [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.image_outlined,
                          size: 32, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Text('Click to upload images',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('PNG, JPG up to 10MB each',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
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
    final List<XFile> selectedFiles =
        await _picker.pickMultiImage(imageQuality: 85);
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
      // 2. Fetch user profile to determine if they are a manufacturer
      final userProfileData = await _supabase
          .from('users')
          .select('id, manufacturer_profiles(user_id)')
          .eq('id', user.id)
          .single();

      final isManufacturer = userProfileData['manufacturer_profiles'] != null;

      // 3. Upload images to appropriate storage bucket
      final storageBucket =
          isManufacturer ? 'manufacturer-files' : 'designer-files';
      List<String> uploadedImageUrls = [];

      for (int i = 0; i < _images.length; i++) {
        final image = _images[i];
        final bytes = await image.readAsBytes();
        final uploadFileName =
            '${DateTime.now().millisecondsSinceEpoch}-${user.id}-${i + 1}.jpg';

        try {
          await _supabase.storage
              .from(storageBucket)
              .uploadBinary(uploadFileName, bytes);

          final imageUrl = _supabase.storage
              .from(storageBucket)
              .getPublicUrl(uploadFileName);

          uploadedImageUrls.add(imageUrl);
        } catch (e) {
          debugPrint('Error uploading image ${i + 1}: $e');
        }
      }

      // 4. Helper functions
      String? getTextValue(TextEditingController controller) {
        final text = controller.text.trim();
        return text.isEmpty ? null : text;
      }

      List<String>? textToList(TextEditingController controller) {
        final text = controller.text.trim();
        return text.isEmpty ? null : [text];
      }

      // 5. Prepare product data with all fields
      final Map<String, dynamic> productData = {
        'user_id': user.id,
        'Product Title': productTitleCtrl.text.trim(),
        'Description': getTextValue(descCtrl),
        'Image': uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
        'Metal Type': metalType,
        'Metal Purity': metalPurity,
        'Product Type': productType,
        'Gold Weight': getTextValue(metalWeightCtrl),
        'Metal Color': getTextValue(metalColorCtrl),
        'Metal Finish': metalFinish,
        'Gender': gender,
        'Design Type': jewelryType, // Jewelry Type maps to Design Type in DB
        'Net Weight': getTextValue(goldNetWeightCtrl),
        'Dimension': getTextValue(dimensionCtrl),
        'Enamel Work': textToList(enamelWorkCtrl),
        'Collection Name': getTextValue(collectionNameCtrl),
        'Theme': getTextValue(themeCtrl),
      };

      // Add stone fields only if Studded
      if (jewelryType == 'Studded') {
        productData['Stone Type'] = stoneType != null ? [stoneType] : null;
        productData['Stone Used'] = stoneUsed != null ? [stoneUsed] : null;
        productData['Stone Setting'] =
            stoneSetting != null ? [stoneSetting] : null;
        productData['Stone Count'] = textToList(stoneCountCtrl);
        productData['Stone Color'] = textToList(stoneColorCtrl);
        productData['Stone Cut'] = stoneCut != null ? [stoneCut] : null;
      }

      // 6. Insert to appropriate table
      final tableName =
          isManufacturer ? 'manufacturerproducts' : 'designerproducts';
      final result =
          await _supabase.from(tableName).insert(productData).select();

      if (mounted) {
        if (result.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Product published successfully to ${isManufacturer ? "Manufacturer" : "Designer"} catalog!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

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
  const _StepperHeader(
      {required this.step, required this.steps, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 16 : 24, horizontal: isMobile ? 16 : 48),
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
                          ? Icon(Icons.check,
                              size: isMobile ? 14 : 16, color: Colors.white)
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
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
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
                      color: isCompleted
                          ? const Color(0xFF00BFA5)
                          : Colors.grey.shade200,
                      margin:
                          const EdgeInsets.only(bottom: 20, left: 8, right: 8),
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

  const _BottomNav(
      {required this.step,
      required this.max,
      required this.isStepValid,
      this.isUploading = false,
      this.isMobile = false,
      required this.onBack,
      required this.onNext,
      required this.onPublish});

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
                      onPressed: onBack, child: const Text('Back'))),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(step == max ? 'Publish Product' : 'Next Step >'),
                )),
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
