import 'package:flutter/foundation.dart';

class JewelryItem {
  final int id;
  final String title;
  final String image;
  final String? description;
  final String? price;
  final List<String> tags;
  final String? goldWeight;
  final String? goldCarat;
  final String? goldFinish;
  final String? stoneWeight;
  final String? stoneType;
  final String? stoneUsed;
  final String? stoneSetting;
  final String? stonePurity;
  final String? stoneCount;
  final String? category;
  final String? subCategory;
  final String? size;
  final String? occasions;
  final String? style;
  final String? scrapedUrl;
  bool isFavorite;

  JewelryItem({
    required this.id,
    required this.title,
    required this.image,
    this.description,
    this.price,
    this.tags = const [],
    this.goldWeight,
    this.goldCarat,
    this.goldFinish,
    this.stoneWeight,
    this.stoneType,
    this.stoneUsed,
    this.stoneSetting,
    this.stonePurity,
    this.stoneCount,
    this.category,
    this.subCategory,
    this.size,
    this.occasions,
    this.style,
    this.scrapedUrl,
    this.isFavorite = false,
  });

  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    // Safely parse the list of tags
    List<String> parsedTags = [];
    if (json['tags'] != null && json['tags'] is List) {
      parsedTags = List<String>.from(json['tags']);
    }

    return JewelryItem(
      // The 'id' from the database is an integer.
      id: json['id'] ?? 0,
      title: json['title'] ?? 'No Title',
      image: json['image'] ?? '',
      description: json['description'] as String?,
      price: json['price'] as String?,
      tags: parsedTags,
      goldWeight: json['gold_weight'] as String?,
      goldCarat: json['gold_carat'] as String?,
      goldFinish: json['gold_finish'] as String?,
      stoneWeight: json['stone_weight'] as String?,
      stoneType: json['stone_type'] as String?,
      stoneUsed: json['stone_used'] as String?,
      stoneSetting: json['stone_setting'] as String?,
      stonePurity: json['stone_purity'] as String?,
      stoneCount: json['stone_count'] as String?,
      category: json['category'] as String?,
      subCategory: json['sub_category'] as String?,
      size: json['size'] as String?,
      occasions: json['occasions'] as String?,
      style: json['style'] as String?,
      scrapedUrl: json['scraped_url'] as String?,
    );
  }
}