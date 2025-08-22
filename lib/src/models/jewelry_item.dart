import 'dart:math';

class JewelryItem {
  String? id; 
  final String url; 
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> category;
  bool isFavorite;

  JewelryItem({
    this.id, 
    required this.url,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.isFavorite = false,
  });

  factory JewelryItem.fromMap(Map<String, dynamic> map) {
    final images = (map['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final validImages = images.where((url) => url.startsWith('http')).toList();

    double parsedPrice = 0.0;
    if (map['price'] is num) {
      parsedPrice = (map['price'] as num).toDouble();
    } else if (map['price'] is String) {
      parsedPrice = double.tryParse(map['price'] as String) ?? 0.0;
    }

    return JewelryItem(
      id: map['id'] as String?, 
      url: map['url'] as String? ?? 'temp_url_${Random().nextDouble()}', 
      name: map['title'] as String? ?? 'No Name',
      description: map['description'] as String? ?? 'No Description',
      price: parsedPrice,
      imageUrl: validImages.isNotEmpty
          ? validImages.first
          : 'https://placehold.co/600x400?text=No+Image',
      category: (map['categories'] as List<dynamic>?)?.cast<String>() ?? [],
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }
}