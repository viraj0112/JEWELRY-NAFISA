import 'package:flutter/foundation.dart';

class JewelryItem {
  final String id;
  final bool isDesignerProduct;
  final String productTitle;
  final String image;

  // ⭐️ NEW FIELD: Array of images (Ready for future use)
  // ⭐️ NEW FIELD: Array of images
  final List<String>? images; 
  
  final String description;
  final double? price;
  final List<String>? tags;
  final String? goldWeight;
  final String? metalWeight;
  final String? metalPurity;
  final String? metalFinish;

  final List<String>? stoneWeight;
  final List<String>? stoneType;
  final List<String>? stoneUsed;
  final List<String>? stoneSetting;
  final List<String>? stoneCount;
  final List<String>? stonePurity;
  // --- END MODIFICATION ---
  final String? scrapedUrl;
  final String? category;
  final String? subCategory;
  final String? productType;
  final String? gender;
  final String? theme;
  final String? metalType;
  final String? metalColor;
  final double? netWeight;
  // --- MODIFIED: Changed types from String? to List<String>? ---
  final List<String>? stoneColor;
  final List<String>? stoneCut;
  // --- END MODIFICATION ---
  final String? dimension;
  final String? designType;
  final String? artForm;
  final String? plating;
  final String? enamelWork;
  final bool? customizable;
  bool isFavorite;
  final double aspectRatio;

  JewelryItem({
    required this.id,
    required this.productTitle,
    required this.image,
    this.images,
    required this.description,
    this.price,
    this.isDesignerProduct = false,
    this.tags,
    this.goldWeight,
    this.metalPurity,
    this.metalFinish,
    this.metalWeight,
    this.stoneWeight,
    this.stoneType,
    this.stoneUsed,
    this.stoneSetting,
    this.stoneCount,
    this.stonePurity,
    this.scrapedUrl,
    this.category,
    this.subCategory,
    this.productType,
    this.gender,
    this.theme,
    this.metalType,
    this.metalColor,
    this.netWeight,
    this.stoneColor,
    this.stoneCut,
    this.dimension,
    this.designType,
    this.artForm,
    this.plating,
    this.enamelWork,
    this.customizable,
    this.isFavorite = false,
    this.aspectRatio = 1.0,
  });

factory JewelryItem.fromJson(Map<String, dynamic> json) {
  return JewelryItem(
    id: json['id']?.toString() ?? '',
    
    // FIX: Add check for 'title' (used in designerproducts)
    productTitle: json['Product Title'] ?? json['product_title'] ?? json['title'] ?? '',

    // Handle both single string and array for image
    image: json['Image'] is List
        ? (json['Image'] as List).firstOrNull ?? ''
        : json['Image'] ?? json['image'] ?? json['image_url'] ?? '',
        
    // Parse the new 'images' array
    images: (json['images'] is List)
        ? (json['images'] as List).map((e) => e.toString()).toList()
        : (json['Image'] is List)
            ? (json['Image'] as List).map((e) => e.toString()).toList()
            : null,
            
    description: json['description'] ?? '',
    price: _parseDouble(json['Price'] ?? json['price']),
    isDesignerProduct: json['is_designer_product'] ?? false,
    tags: _parseList(json['Product Tags'] ?? json['tags']),
    
    goldWeight: _parseString(
        json['Gold Weight'] ?? json['gold_weight']), 
        
    // FIX: Add check for 'gold_carat' (used in designerproducts)
    metalPurity: _parseString(
        json['Metal Purity'] ?? json['metal_purity'] ?? json['gold_carat']), 
        
    // FIX: Add check for 'gold_finish' (used in designerproducts)
    metalFinish: _parseString(
        json['Metal Finish'] ?? json['metal_finish'] ?? json['gold_finish']), 
        
    metalWeight: _parseString(
        json['Metal Weight'] ?? json['metal_weight']),

    stoneWeight: _parseList(json['Stone Weight'] ?? json['stone_weight']),
    stoneType: _parseList(json['Stone Type'] ?? json['stone_type']),
    stoneUsed: _parseList(json['Stone Used'] ?? json['stone_used']),
    stoneSetting: _parseList(json['Stone Setting'] ?? json['stone_setting']),
    stoneCount: _parseList(json['Stone Count'] ?? json['stone_count']),
    stonePurity: _parseList(json['Stone Purity'] ?? json['stone_purity']),

    scrapedUrl: _parseString(
        json['Scraped URL'] ?? json['scraped_url']), 
    category: _parseString(
        json['Category'] ?? json['category']), 
    subCategory: _parseString(
        json['Sub Category'] ?? json['sub_category'] ?? json['SubCategory']), 
    productType: _parseString(
        json['Product Type'] ?? json['product_type']), 
    gender:
        _parseString(json['Gender'] ?? json['gender']), 
    theme:
        _parseString(json['Theme'] ?? json['occasions']), 
    metalType: _parseString(
        json['Metal Type'] ?? json['metal_type']), 
    metalColor: _parseString(
        json['Metal Color'] ?? json['metal_color']), 

    netWeight: _parseDouble(
        json['NET WEIGHT'] ?? json['net_weight']), 

    stoneColor: _parseList(json['Stone Color'] ?? json['stone_color']),
    stoneCut: _parseList(json['Stone Cut'] ?? json['stone_cut']),

    dimension:
        _parseString(json['Dimension'] ?? json['size']), 
    designType: _parseString(
        json['Design Type'] ?? json['style']), 
    artForm: _parseString(
        json['Art Form'] ?? json['art_form']), 
    plating:
        _parseString(json['Plating'] ?? json['plating']), 
    enamelWork: _parseString(
        json['Enamel Work'] ?? json['enamel_work']), 

    customizable: (json['Customizable'] is bool)
        ? json['Customizable']
        : (json['Customizable'] == 'Yes' || json['customizable'] == true),
    aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
  );
}

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    // Return null if the string is empty, "null", "None", or "N/A"
    if (str.isEmpty || 
        str.toLowerCase() == 'null' || 
        str.toLowerCase() == 'none' || 
        str.toLowerCase() == 'n/a' ||
        str.toLowerCase() == 'na') {
      return null;
    }
    return str;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String>? _parseList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final list = value
          .map((e) => e.toString().trim())
          .where((e) => 
              e.isNotEmpty && 
              e.toLowerCase() != 'null' && 
              e.toLowerCase() != 'none' &&
              e.toLowerCase() != 'n/a' &&
              e.toLowerCase() != 'na')
          .toList();
      return list.isEmpty ? null : list;
    }
    if (value is String) {
      final str = value.trim();
      if (str.isEmpty || 
          str.toLowerCase() == 'null' || 
          str.toLowerCase() == 'none' ||
          str.toLowerCase() == 'n/a' ||
          str.toLowerCase() == 'na') {
        return null;
      }
      return [str];
    }
    return null;
  }
}