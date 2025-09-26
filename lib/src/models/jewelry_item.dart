import 'package:flutter/foundation.dart';

class JewelryItem {
  final String id;
  final String name; 
  final String? description;
  final num? price;
  final String imageUrl;
  final List<String> tags;
  final String? category;
  final String? subCategory;
  final String? metal;
  final String? purity;
  final String? stoneType;
  final String? dimensions;
  final Map<String, dynamic>? attributes;
  final DateTime createdAt;
  bool isFavorite;

  JewelryItem({
    required this.id,
    required this.name,
    this.description,
    this.price,
    required this.imageUrl,
    this.tags = const [],
    this.category,
    this.subCategory,
    this.metal,
    this.purity,
    this.stoneType,
    this.dimensions,
    this.attributes,
    required this.createdAt,
    this.isFavorite = false,
  });

  String get url => id;

  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] != null && json['tags'] is List) {
      parsedTags = List<String>.from(json['tags']);
    }
    
    
    num? parsedPrice;
    final priceValue = json['price'];
    if (priceValue is num) {
      parsedPrice = priceValue;
    } else if (priceValue is String) {
      parsedPrice = num.tryParse(priceValue);
    }
    

    return JewelryItem(
      id: json['id'] as String,
      name: json['title'] as String,
      description: json['description'] as String?,
      price: parsedPrice,
      imageUrl: json['image_url'] as String,
      tags: parsedTags,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      metal: json['metal'] as String?,
      purity: json['purity'] as String?,
      stoneType: json['stone_type'] as String?,
      dimensions: json['dimensions'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}