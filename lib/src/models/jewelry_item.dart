import 'dart:convert';
import 'package:flutter/foundation.dart';

class JewelryItem {
  /// Integer primary key – kept for internal DB joins only. Never expose in URLs.
  final String id;

  /// UUID column added to every product table. Use this for all public-facing
  /// URLs, links, and polymorphic table (likes / saves / views / shares) references.
  final String? uid;

  /// SKU / product code for B2B display.
  final String? sku;
  final bool isDesignerProduct;
  final bool isManufacturerProduct;
  final String productTitle;
  final String image;
  final List<String>? images;

  final String description;
  final double? price;
  final List<String>? tags;
  final String? goldWeight;
  final String? metalWeight;
  final String? metalPurity;
  final String? metalFinish;

  final List<String>? stoneWeight;
  final List<String>? stoneType;
  final List<String>? stoneUsed;
  final List<String>? stoneSetting;
  final List<String>? stoneCount;
  final List<String>? stonePurity;
  // --- END MODIFICATION ---
  final String? scrapedUrl;
  final String? category;
  final String? subCategory;
  final String? productType;
  final String? gender;
  final String? metalType;
  final String? metalColor;
  final double? netWeight;
  final List<String>? stoneColor;
  final List<String>? stoneCut;
  final String? dimension;
  final String? designType;
  final String? artForm;
  final String? plating;
  final String? enamelWork;
  final bool? customizable;
  bool isFavorite;
  final double aspectRatio;

  // --- NEW FIELDS FOR UI ---
  final Map<String, dynamic>? users;
  int? likes;
  final int? saves;
  final int? credits;
  final int? share;
  final bool? isTrending;
  final List<Map<String, dynamic>>? geoAnalytics;
  // --- CATEGORY SUB-FILTERS ---
  final String? category1;
  final String? category2;
  final String? category3;

  // --- MODERATION STATUS ---
  final String? status;

  JewelryItem({
    required this.id,
    this.uid,
    this.sku,
    required this.productTitle,
    required this.image,
    this.images,
    required this.description,
    this.price,
    this.isDesignerProduct = false,
    this.isManufacturerProduct = false,
    this.tags,
    this.goldWeight,
    this.metalPurity,
    this.metalFinish,
    this.metalWeight,
    this.stoneWeight,
    this.stoneType,
    this.stoneUsed,
    this.stoneSetting,
    this.stoneCount,
    this.stonePurity,
    this.scrapedUrl,
    this.category,
    this.subCategory,
    this.productType,
    this.gender,
    this.metalType,
    this.metalColor,
    this.netWeight,
    this.stoneColor,
    this.stoneCut,
    this.dimension,
    this.designType,
    this.artForm,
    this.plating,
    this.enamelWork,
    this.customizable,
    this.isFavorite = false,
    this.aspectRatio = 1.0,
    this.users,
    this.likes,
    this.saves,
    this.isTrending,
    this.category1,
    this.category2,
    this.category3,
    this.credits,
    this.share,
    this.geoAnalytics,
    this.status,
  });

  factory JewelryItem.fromJson(Map<String, dynamic> json) {
    // Handles all 3 schema shapes for images: pre-Phase-1 (Image = array
    // already, or Images = text scalar on products), Phase 1/2 today
    // (images_arr = array, Image/Images still the old columns), and
    // post-Phase-3 (Images IS the renamed array; images_arr no longer exists
    // as a key, old Image/Images columns are dropped).
    List? imgList = json['images_arr'] is List
        ? json['images_arr'] as List
        : json['Image'] is List
            ? json['Image'] as List
            : json['Images'] is List
                ? json['Images'] as List
                : (json['images'] is List ? json['images'] as List : null);

    // If it's still null, try parsing from a JSON string.
    if (imgList == null) {
      for (final key in ['images_arr', 'Images', 'Image', 'image', 'image_url']) {
        final val = json[key];
        if (val is String && val.startsWith('[') && val.endsWith(']')) {
          try {
            imgList = jsonDecode(val) as List;
            break;
          } catch (_) {}
        }
      }
    }

    return JewelryItem(
      id: json['id']?.toString() ?? '',
      uid: _parseString(json['uid']),
      sku: _parseString(json['SKU'] ?? json['sku']),
      productTitle:
          json['Product Title'] ?? json['product_title'] ?? json['title'] ?? '',
      image: imgList?.firstOrNull?.toString() ??
          _parseImageString(json['Image']) ??
          _parseImageString(json['Images']) ??
          _parseImageString(json['image']) ??
          _parseImageString(json['image_url']) ??
          '',
      images: imgList?.map((e) => e.toString()).toList(),
      description: json['description'] ?? '',
      price: _parseDouble(json['Price'] ?? json['price']),
      isDesignerProduct: json['is_designer_product'] ??
          (json['source'] == 'designerproducts') ??
          false,
      isManufacturerProduct: json['is_manufacturer_product'] ??
          (json['source'] == 'manufacturerproducts') ??
          false,
      tags: _parseList(json['Product Tags'] ?? json['tags']),
      goldWeight: _parseString(json['Gold Weight'] ?? json['gold_weight']),
      metalPurity: _parseString(
          json['Metal Purity'] ?? json['metal_purity'] ?? json['gold_carat']),
      metalFinish: _parseString(
          json['Metal Finish'] ?? json['metal_finish'] ?? json['gold_finish']),
      metalWeight: _parseString(json['Metal Weight'] ?? json['metal_weight']),
      stoneWeight: _parseList(json['Stone Weight'] ?? json['stone_weight']),
      stoneType: _parseList(json['Stone Type'] ?? json['stone_type']),
      stoneUsed: _parseList(json['Stone Used'] ?? json['stone_used']),
      stoneSetting: _parseList(json['Stone Setting'] ?? json['stone_setting']),
      stoneCount: _parseList(json['Stone Count'] ?? json['stone_count']),
      stonePurity: _parseList(json['Stone Purity'] ?? json['stone_purity']),
      scrapedUrl: _parseString(json['Scraped URL'] ?? json['scraped_url']),
      // Handles all 3 schema shapes: pre-Phase-1 (Category = scalar text),
      // Phase 1/2 today (category_arr = array, Category = scalar), and
      // post-Phase-3 (Category IS the renamed array; category_arr no longer
      // exists as a key at all).
      category: _firstFromArrayOrScalarKey(json, 'category_arr', 'Category',
          legacyCamelKey: 'category'),
      subCategory: _parseString(
          json['Sub Category'] ?? json['sub_category'] ?? json['SubCategory']),
      productType: _parseString(json['Product Type'] ?? json['product_type']),
      gender: _parseString(json['Gender'] ?? json['gender']),
      metalType: _parseString(json['Metal Type'] ?? json['metal_type']),
      // Same 3-shape handling as `category` above.
      metalColor: _firstFromArrayOrScalarKey(
          json, 'metal_color_arr', 'Metal Color',
          legacyCamelKey: 'metal_color'),
      netWeight: _parseDouble(json['NET WEIGHT'] ?? json['net_weight']),
      stoneColor: _parseList(json['Stone Color'] ?? json['stone_color']),
      stoneCut: _parseList(json['Stone Cut'] ?? json['stone_cut']),
      dimension: _parseString(json['Dimension'] ?? json['size']),
      designType: _parseString(json['Design Type'] ?? json['style']),
      artForm: _parseString(json['Art Form'] ?? json['art_form']),
      plating: _parseString(json['Plating'] ?? json['plating']),
      enamelWork: _parseString(json['Enamel Work'] ?? json['enamel_work']),
      customizable: (json['Customizable'] is bool)
          ? json['Customizable']
          : (json['Customizable'] == 'Yes' || json['customizable'] == true),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      // --- NEW FIELDS ---
      users: json['users'] is Map<String, dynamic>
          ? json['users'] as Map<String, dynamic>
          : (json['users'] != null
              ? Map<String, dynamic>.from(json['users'])
              : null),
      likes: json['likes'] is int
          ? json['likes']
          : int.tryParse(json['likes']?.toString() ?? ''),
      saves: json['saves'] is int
          ? json['saves']
          : int.tryParse(json['saves']?.toString() ?? ''),
      credits: json['credits'] is int
          ? json['credits']
          : int.tryParse(json['credits']?.toString() ?? ''),
      share: json['share'] is int
          ? json['share']
          : int.tryParse(json['share']?.toString() ?? ''),
      isTrending: json['isTrending'] is bool
          ? json['isTrending']
          : (json['isTrending']?.toString().toLowerCase() == 'true'),
      geoAnalytics: (json['geoAnalytics'] is List)
          ? (json['geoAnalytics'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      // --- CATEGORY SUB-FILTERS ---
      category1: _parseString(json['Category1'] ?? json['category1']),
      category2: _parseString(json['Category2'] ?? json['category2']),
      category3: _parseString(json['Category3'] ?? json['category3']),
      status: _parseString(json['status']) ?? 'published',
    );
  }

  // Dirty-data placeholders seen in the scraped product tables: some upstream
  // ingestion step serialized empty/null array values as the literal STRING
  // "{null}" (or similar bracket-wrapped variants) instead of a real SQL NULL,
  // so it reads back as ordinary text and must be pattern-matched out here.
  static bool _isFakeEmptyValue(String lower) {
    return lower.isEmpty ||
        lower == 'null' ||
        lower == 'none' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '{null}' ||
        lower == '{}' ||
        lower == '[null]' ||
        lower == '[]';
  }

  // Resolves a field that has TWO possible JSON keys for the same underlying
  // data: a "new" key which may already be the renamed array column (Phase 3)
  // or the pre-rename staging column (Phase 1's `*_arr`), and a "legacy" key
  // which is the pre-migration scalar column. Handles all three schema shapes
  // this app has to work against over the migration's lifetime:
  //   1. Pre-Phase-1: only `legacyKey` exists, as a scalar.
  //   2. Phase 1/2 (today): BOTH keys exist - `newKey` is the array, `legacyKey`
  //      is still the original scalar.
  //   3. Post-Phase-3: only `legacyKey`'s NAME exists in the response, but it
  //      now holds the renamed ARRAY (e.g. "Category" is category_arr renamed).
  // Never calls .toString() on a raw List - every path explicitly checks
  // `is List` before deciding to treat a value as an array or a scalar.
  static List<dynamic>? _resolveArrayField(
      Map<String, dynamic> json, String newKey, String legacyKey) {
    if (json[newKey] is List) return json[newKey] as List;
    if (json[legacyKey] is List) return json[legacyKey] as List;
    return null;
  }

  static String? _firstFromArrayOrScalarKey(
      Map<String, dynamic> json, String newKey, String legacyKey,
      {String? legacyCamelKey}) {
    final arr = _resolveArrayField(json, newKey, legacyKey);
    if (arr != null) return _parseString(arr.firstOrNull);
    // Neither key is an array (pre-Phase-1 world, or both genuinely absent):
    // legacyKey is safe to read as a scalar here.
    return _parseString(
        json[legacyKey] ?? (legacyCamelKey != null ? json[legacyCamelKey] : null));
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (_isFakeEmptyValue(str.toLowerCase())) {
      return null;
    }
    return str;
  }

  /// Like [_parseString] but rejects Lists outright instead of stringifying
  /// them - used for legacy "Image"/"Images" fallback keys that may now hold
  /// a text[] (post-Phase-3) instead of the scalar string they used to be.
  static String? _parseImageString(dynamic value) {
    if (value == null) return null;
    if (value is List) return _parseString(value.firstOrNull);
    
    final str = _parseString(value);
    if (str != null && str.startsWith('[') && str.endsWith(']')) {
      try {
        final List decoded = jsonDecode(str);
        if (decoded.isNotEmpty) return _parseString(decoded.first);
      } catch (_) {
        // Fallthrough on parse error
      }
    }
    return str;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String>? _parseList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final list = value
          .map((e) => e.toString().trim())
          .where((e) => !_isFakeEmptyValue(e.toLowerCase()))
          .toList();
      return list.isEmpty ? null : list;
    }
    if (value is String) {
      final str = value.trim();
      if (_isFakeEmptyValue(str.toLowerCase())) {
        return null;
      }
      return [str];
    }
    return null;
  }
}
