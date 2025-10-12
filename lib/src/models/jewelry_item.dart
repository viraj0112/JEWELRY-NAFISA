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

  // Helper function to safely parse a double from a formatted string
  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final cleanedString = value.replaceAll('₹', '').replaceAll(',', '').trim();
      return double.tryParse(cleanedString);
    }
    return null;
  }

  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    return JewelryItem(
      id: json['id'].toString(),
      productTitle: json['Product Title'] ?? '',
      image: json['Image'] ?? '',
      description: json['Description'] ?? '',
      price: _parseDouble(json['Price']),
      tags: (json['Product Tags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      goldWeight: json['Gold Weight'],
      metalPurity: json['Metal Purity'],
      metalFinish: json['Metal Finish'],
      stoneWeight: json['Stone Weight'],
      stoneType: json['Stone Type'],
      stoneUsed: json['Stone Used'],
      stoneSetting: json['Stone Setting'],
      stoneCount: json['Stone Count'],
      scrapedUrl: json['Scraped URL'],
      collectionName: json['Collection Name'],
      productType: json['Product Type'],
      gender: json['Gender'],
      theme: json['Theme'],
      metalType: json['Metal Type'],
      metalColor: json['Metal Color'],
      netWeight: _parseDouble(json['NET WEIGHT']),
      stoneColor: json['Stone Color'],
      stoneCut: json['Stone Cut'],
      dimension: json['Dimension'],
      designType: json['Design Type'],
      artForm: json['Art Form'],
      plating: json['Plating'],
      enamelWork: json['Enamel Work'],
      customizable: json['Customizable'] == 'Yes',
    );
  }
}