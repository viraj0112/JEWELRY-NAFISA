class JewelryItem {
  final String id;
  final String name;
  final String imageUrl;
  final double price;

  JewelryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
  });

  // A flexible factory constructor that allows you to specify the keys
  factory JewelryItem.fromMap(
    Map<String, dynamic> map, {
    String idKey = 'id',
    String nameKey = 'title',
    String imageUrlKey = 'image_url',
    String priceKey = 'price',
  }) {
    return JewelryItem(
      id: map[idKey]?.toString() ?? '',
      name: map[nameKey]?.toString() ?? 'Unnamed Jewelry',
      imageUrl: map[imageUrlKey]?.toString() ?? 'https://via.placeholder.com/200x300', // Placeholder image
      // Safely parse the price, defaulting to 0.0 if not found or invalid
      price: double.tryParse(map[priceKey]?.toString() ?? '0.0') ?? 0.0,
    );
  }
}