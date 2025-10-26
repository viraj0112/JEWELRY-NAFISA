import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class Board {
  final int id;
  final String name;
  final List<String> coverUrls;
  final List<JewelryItem> items;
  final bool isSecret;

  Board({
    required this.id,
    required this.name,
    List<String>? coverUrls,
    List<JewelryItem>? items,
    this.isSecret = false,
  })  : coverUrls = coverUrls ?? [],
        items = items ?? [];

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int,
      name: json['name'] as String,
      isSecret: json['is_secret'] as bool? ?? false,
      coverUrls: json['cover_urls'] != null
          ? List<String>.from(json['cover_urls'])
          : [],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => JewelryItem.fromJson(i)).toList()
          : [],
    );
  }

  Board copyWith({
    String? name,
    List<String>? coverUrls,
    List<JewelryItem>? items,
    bool? isSecret,
  }) {
    return Board(
      id: this.id,
      name: name ?? this.name,
      coverUrls: coverUrls ?? this.coverUrls,
      items: items ?? this.items,
      isSecret: isSecret ?? this.isSecret,
    );
  }
}
