import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class Board {
  final String id;
  final String name;
  final List<JewelryItem> items;

  Board({
    required this.id,
    required this.name,
    List<JewelryItem>? items,
  }) : items = items ?? []; 
}