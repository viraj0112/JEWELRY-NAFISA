import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class Board {
  final int id;
  final String name;
  final List<String> coverUrls;
  final List<JewelryItem> items;

  Board({
    required this.id,
    required this.name,
    this.coverUrls = const [],
    this.items = const [],
  });
}