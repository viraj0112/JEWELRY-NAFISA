import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );
  
  final supabase = Supabase.instance.client;
  
  try {
    final response = await supabase.from('products').select('"Category"').eq('"Product Type"', 'Earrings');
    print('Products response length: ${response.length}');
    final categories = <String>{};
    for (var row in response) {
      final cat = row['Category'];
      if (cat != null) {
        categories.add(cat.toString());
      }
    }
    print('Categories found: $categories');
  } catch (e) {
    print('Products query failed: $e');
  }
}
