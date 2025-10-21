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
  final String? stoneWeight;
  final String? stoneType;
  final String? stoneUsed;
  final String? stoneSetting;
  final String? stoneCount;
  final String? scrapedUrl;
  final String? collectionName;
  final String? productType;
  final String? gender;
  final String? theme;
  final String? metalType;
  final String? metalColor;
  final double? netWeight;
  final String? stoneColor;
  final String? stoneCut;
  final String? dimension;
  final String? designType;
  final String? artForm;
  final String? plating;
  final String? enamelWork;
  final bool? customizable;
  bool isFavorite;

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

  // Helper function to handle different tag formats
  static List<String>? _parseTags(dynamic tags) {
    if (tags is List) {
      return tags.cast<String>().toList();
    } else if (tags is String) {
      return tags.split(',').map((t) => t.trim()).toList();
    }
    return null;
  }

  static String? _parseStringOrFirst(dynamic value) {
    if (value is String) {
      return value;
    }
    if (value is List && value.isNotEmpty) {
      // Safely convert the first element to string
      return value.first?.toString();
    }
    // Return null if it's an empty list or not a string/list
    return null;
  }

  // The corrected fromJson factory
  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    return JewelryItem(
      id: json['id'].toString(),
      productTitle: json['title'] ?? json['Product Title'] ?? '',
      image: json['image'] ?? json['Image'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',

      price: _parseDouble(json['price'] ?? json['Price']),

      tags: _parseTags(json['tags'] ?? json['Product Tags']),

      goldWeight: json['gold_weight'] ?? json['Gold Weight'],
      metalPurity: json['metal_purity'] ?? json['Metal Purity'],
      metalFinish: json['metal_finish'] ?? json['Metal Finish'],

      // --- APPLY THE FIX TO THESE FIELDS ---
      stoneWeight:
          _parseStringOrFirst(json['stone_weight'] ?? json['Stone Weight']),
      stoneType: _parseStringOrFirst(json['stone_type'] ?? json['Stone Type']),
      stoneUsed: _parseStringOrFirst(json['stone_used'] ?? json['Stone Used']),
      stoneSetting:
          _parseStringOrFirst(json['stone_setting'] ?? json['Stone Setting']),
      stoneCount:
          _parseStringOrFirst(json['stone_count'] ?? json['Stone Count']),
      // --- END FIX ---

      scrapedUrl: json['scraped_url'] ?? json['Scraped URL'],
      collectionName: json['sub_category'] ?? json['Collection Name'],
      productType: json['category'] ?? json['Product Type'],
      gender: json['gender'] ?? json['Gender'],
      theme: json['occasions'] ?? json['Theme'],
      metalType: json['metal_type'] ?? json['Metal Type'],
      metalColor: json['metal_color'] ??
          json['Metal Color'], // This is 'text' in DB, so no change needed
      netWeight: _parseDouble(json['net_weight'] ?? json['NET WEIGHT']),

      // --- APPLY THE FIX TO THESE FIELDS ---
      stoneColor:
          _parseStringOrFirst(json['stone_color'] ?? json['Stone Color']),
      stoneCut: _parseStringOrFirst(json['stone_cut'] ?? json['Stone Cut']),
      // --- END FIX ---

      dimension: json['size'] ?? json['Dimension'],
      designType: json['style'] ?? json['Design Type'],
      artForm: json['art_form'] ?? json['Art Form'],
      plating: json['plating'] ?? json['Plating'],
      enamelWork: json['enamel_work'] ?? json['Enamel Work'],
      customizable: (json['customizable'] is bool)
          ? json['customizable']
          : (json['Customizable'] == 'Yes'),
    );
  }
}
