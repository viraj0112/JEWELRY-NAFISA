class JewelryItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  bool isFavorite;

  JewelryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isFavorite = false,
  }) : imageUrl = 'https://placehold.co/600x400?text=${name.replaceAll(' ', '+')}';

  factory JewelryItem.fromMap(Map<String, dynamic> map) {
    return JewelryItem(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      price: map['price']?.toDouble() ?? 0.0,
      category: map['category'],
      isFavorite: map['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isFavorite': isFavorite,
    };
  }

  JewelryItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    bool? isFavorite,
  }) {
    return JewelryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}