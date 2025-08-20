import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class JewelryService {
  final _supabase = Supabase.instance.client;

  // This is the central function for fetching data.
  // You can modify this to fetch from a local file or a different API.
  Future<List<JewelryItem>> fetchJewelryItems({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      // --- CURRENT LOGIC: FETCH FROM SUPABASE ---
      // Replace this block if you switch to JSON/Excel
      const String tableName = 'pins'; // The name of your Supabase table
      final response = await _supabase
          .from(tableName)
          .select() // Select all columns for flexibility
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      // The `fromMap` constructor handles the mapping.
      // You only need to adjust the keys inside the JewelryItem model.
      final items = (response as List<dynamic>)
          .map((item) => JewelryItem.fromMap(item as Map<String, dynamic>))
          .toList();
      return items;

      // --- EXAMPLE: HOW TO FETCH FROM A LOCAL JSON ASSET ---
      /*
      // 1. Add your json file to an 'assets' folder and declare it in pubspec.yaml
      // final String jsonString = await rootBundle.loadString('assets/your_data.json');
      // final List<dynamic> jsonList = json.decode(jsonString);
      // final items = jsonList
      //     .map((item) => JewelryItem.fromMap(item as Map<String, dynamic>))
      //     .toList();
      // return items;
      */

    } catch (e) {
      debugPrint("Error fetching jewelry items: $e");
      return []; // Return an empty list on error
    }
  }
}