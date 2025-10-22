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
  // --- MODIFIED: Changed types from String? to List<String>? ---
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

  // The corrected fromJson factory
  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    return JewelryItem(
      id: json['id'].toString(),
      productTitle:
          json['Product Title'] ?? json['title'] ?? json['product_title'] ?? '',
      image: json['Image'] ?? json['image'] ?? json['image_url'] ?? '',
      description: json['Description'] ?? json['description'] ?? '',
      price: _parseDouble(json['Price'] ?? json['price']),
      tags: _parseList(json['Product Tags'] ?? json['tags']),
      goldWeight: json['Gold Weight'] ?? json['gold_weight'],
      metalPurity: json['Metal Purity'] ?? json['metal_purity'],
      metalFinish: json['Metal Finish'] ?? json['metal_finish'],
      // --- MODIFIED: Use _parseList for array fields ---
      stoneWeight: _parseList(json['Stone Weight'] ?? json['stone_weight']),
      stoneType: _parseList(json['Stone Type'] ?? json['stone_type']),
      stoneUsed: _parseList(json['Stone Used'] ?? json['stone_used']),
      stoneSetting: _parseList(json['Stone Setting'] ?? json['stone_setting']),
      stoneCount: _parseList(json['Stone Count'] ?? json['stone_count']),
      stonePurity: _parseList(json['Stone Purity'] ?? json['stone_purity']),
      // --- END MODIFICATION ---
      scrapedUrl: json['Scraped URL'] ?? json['scraped_url'],
      collectionName: json['Collection Name'] ?? json['sub_category'],
      productType: json['Product Type'] ?? json['category'],
      gender: json['Gender'] ?? json['gender'],
      theme: json['Theme'] ?? json['occasions'],
      metalType: json['Metal Type'] ?? json['metal_type'],
      metalColor: json['Metal Color'] ?? json['metal_color'],
      netWeight: _parseDouble(json['NET WEIGHT'] ?? json['net_weight']),
      // --- MODIFIED: Use _parseList for array fields ---
      stoneColor: _parseList(json['Stone Color'] ?? json['stone_color']),
      stoneCut: _parseList(json['Stone Cut'] ?? json['stone_cut']),
      // --- END MODIFICATION ---
      dimension: json['Dimension'] ?? json['size'],
      designType: json['Design Type'] ?? json['style'],
      artForm: json['Art Form'] ?? json['art_form'],
      plating: json['Plating'] ?? json['plating'],
      enamelWork: json['Enamel Work'] ?? json['enamel_work'],
      customizable: (json['Customizable'] is bool)
          ? json['Customizable']
          : (json['Customizable'] == 'Yes' || json['customizable'] == true),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
    );
  }
}