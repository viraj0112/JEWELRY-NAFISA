// lib/src/models/jewelry_item.dart

import 'package:flutter/foundation.dart';

class JewelryItem {
  final String id;
  final String productTitle;
  final String image;
  final String description;
  final double? price;
  final List<String>? tags;
  final String? goldWeight;
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
  final String? collectionName;
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
    required this.description,
    this.price,
    this.tags,
    this.goldWeight,
    this.metalPurity,
    this.metalFinish,
    this.stoneWeight,
    this.stoneType,
    this.stoneUsed,
    this.stoneSetting,
    this.stoneCount,
    this.stonePurity,
    this.scrapedUrl,
    this.collectionName,
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

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleanedString =
          value.replaceAll('₹', '').replaceAll(',', '').trim();
      return double.tryParse(cleanedString);
    }
    return null;
  }

  // --- MODIFIED: Unified list parsing logic ---
  static List<String>? _parseList(dynamic value) {
    if (value is List) {
      // If it's already a list, ensure all elements are strings and are not null/empty.
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String) {
      // If it's a comma-separated string, split it.
      return value.split(',').map((t) => t.trim()).toList();
    }
    return null; // Return null for other types
  }

  static String? _parseString(dynamic value) {
    if (value is String) {
      return value.isNotEmpty ? value : null;
    }
    if (value is List) {
      if (value.isNotEmpty) {
        final firstElement = value[0];
        if (firstElement is String && firstElement.isNotEmpty) {
          return firstElement;
        }
      }
    }
    return null;
  }

  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    return JewelryItem(
      id: json['id'].toString(),
      productTitle:
          json['Product Title'] ?? json['title'] ?? json['product_title'] ?? '',
      image: json['Image'] ?? json['image'] ?? json['image_url'] ?? '',
      description: json['Description'] ?? json['description'] ?? '',
      price: _parseDouble(json['Price'] ?? json['price']),
      
      // --- APPLY THE FIX HERE ---
      tags: _parseList(json['Product Tags'] ?? json['tags']), // Keep _parseList
      goldWeight: _parseString(json['Gold Weight'] ?? json['gold_weight']), // Use _parseString
      metalPurity: _parseString(json['Metal Purity'] ?? json['metal_purity']), // Use _parseString
      metalFinish: _parseString(json['Metal Finish'] ?? json['metal_finish']), // Use _parseString

      // These already use _parseList, which is correct
      stoneWeight: _parseList(json['Stone Weight'] ?? json['stone_weight']),
      stoneType: _parseList(json['Stone Type'] ?? json['stone_type']),
      stoneUsed: _parseList(json['Stone Used'] ?? json['stone_used']),
      stoneSetting: _parseList(json['Stone Setting'] ?? json['stone_setting']),
      stoneCount: _parseList(json['Stone Count'] ?? json['stone_count']),
      stonePurity: _parseList(json['Stone Purity'] ?? json['stone_purity']),

      // --- APPLY THE FIX HERE ---
      scrapedUrl: _parseString(json['Scraped URL'] ?? json['scraped_url']), // Use _parseString
      collectionName: _parseString(json['Collection Name'] ?? json['sub_category']), // Use _parseString
      productType: _parseString(json['Product Type'] ?? json['category']), // Use _parseString
      gender: _parseString(json['Gender'] ?? json['gender']), // Use _parseString
      theme: _parseString(json['Theme'] ?? json['occasions']), // Use _parseString
      metalType: _parseString(json['Metal Type'] ?? json['metal_type']), // Use _parseString
      metalColor: _parseString(json['Metal Color'] ?? json['metal_color']), // Use _parseString
      
      netWeight: _parseDouble(json['NET WEIGHT'] ?? json['net_weight']), // Keep _parseDouble

      // These already use _parseList, which is correct
      stoneColor: _parseList(json['Stone Color'] ?? json['stone_color']),
      stoneCut: _parseList(json['Stone Cut'] ?? json['stone_cut']),

      // --- APPLY THE FIX HERE ---
      dimension: _parseString(json['Dimension'] ?? json['size']), // Use _parseString
      designType: _parseString(json['Design Type'] ?? json['style']), // Use _parseString
      artForm: _parseString(json['Art Form'] ?? json['art_form']), // Use _parseString
      plating: _parseString(json['Plating'] ?? json['plating']), // Use _parseString
      enamelWork: _parseString(json['Enamel Work'] ?? json['enamel_work']), // Use _parseString

      customizable: (json['Customizable'] is bool)
          ? json['Customizable']
          : (json['Customizable'] == 'Yes' || json['customizable'] == true),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
