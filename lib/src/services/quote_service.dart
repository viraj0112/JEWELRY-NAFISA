// lib/src/services/quote_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class QuoteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _getProductTable(JewelryItem product) {
    bool isDesignerProduct = product.tags != null;
    return isDesignerProduct ? 'designerproducts' : 'products';
  }

  Future<void> submitQuoteRequest({
    required UserProfile user,
    required JewelryItem product,
    required String? phoneNumber,
    String? additionalNotes,
  }) async {
    try {
      final productTable = _getProductTable(product);
      const String productBaseUrl = 'https://www.dagina.design/product';
      final String slug = product.productTitle
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'[^a-z0-9-]'), '');
      final String productUrl = '$productBaseUrl/$slug';

      final productIdBigInt = int.tryParse(product.id);
      if (productIdBigInt == null) {
        throw Exception('Invalid product ID format: ${product.id}');
      }

      await _supabase.from('quote_requests').insert({
        // User Details
        'user_id': user.id,
        'user_name': user.username ?? user.fullName ?? user.email,
        'user_email': user.email,
        'user_phone': user.phone ?? phoneNumber,

        'product_id': productIdBigInt,
        'product_table': productTable,
        'product_title': product.productTitle,

        'metal_purity': product.metalPurity,
        'gold_weight': product.goldWeight,
        'metal_color': product.metalColor,
        'metal_finish': product.metalFinish,
        'metal_type': product.metalType,
        'stone_type': product.stoneType,
        'stone_color': product.stoneColor,
        'stone_count': product.stoneCount,
        'stone_purity': product.stonePurity,
        'stone_cut': product.stoneCut,
        'stone_used': product.stoneUsed,
        'stone_weight': product.stoneWeight,
        'stone_setting': product.stoneSetting,
        'product_url': productUrl,
        'additional_notes': additionalNotes?.trim().isEmpty ?? true
            ? null
            : additionalNotes!.trim(),
      });
    } on PostgrestException catch (e) {
      debugPrint('Supabase error submitting quote: ${e.message}');
      throw Exception(
          'Failed to submit quote request. ${e.details ?? e.message}');
    } catch (e) {
      debugPrint('Unexpected error submitting quote: $e');
      throw Exception('An unexpected error occurred while submitting.');
    }
  }
}
