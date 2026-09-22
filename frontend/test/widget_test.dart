// Regression tests for the model/role logic behind this session's fixes.
//
// This file previously held the stock `flutter create` counter smoke test -
// it pumped MyApp and looked for a "+" button and a counter reading "0".
// This app has neither, and MyApp needs an initialised Supabase before it can
// even build, so that test could never pass. Replaced with assertions that
// actually pin down behaviour we changed.

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';

void main() {
  group('userRoleFromString', () {
    // AdminGuard renders the admin console only for UserRole.admin, so what
    // this returns for junk input decides whether the guard fails open.
    test('maps the known roles', () {
      expect(userRoleFromString('admin'), UserRole.admin);
      expect(userRoleFromString('designer'), UserRole.designer);
      expect(userRoleFromString('manufacturer'), UserRole.manufacturer);
      expect(userRoleFromString('member'), UserRole.member);
    });

    test('fails closed: null and unknown values are members, never admin', () {
      expect(userRoleFromString(null), UserRole.member);
      expect(userRoleFromString(''), UserRole.member);
      expect(userRoleFromString('Admin'), UserRole.member); // case-sensitive
      expect(userRoleFromString('superuser'), UserRole.member);
      expect(userRoleFromString('admin '), UserRole.member);
    });
  });

  group('JewelryItem source-table flags', () {
    // QuoteService._getProductTable used to infer the source table from
    // `tags != null`, which filed quotes against the wrong table and could
    // never produce 'manufacturerproducts'. It now reads these flags, so the
    // flags have to be right.
    Map<String, dynamic> base() => <String, dynamic>{
          'id': 42,
          'Product Title': 'Test Ring',
          'Description': 'desc',
        };

    test('plain product row sets neither flag', () {
      final item = JewelryItem.fromJson(base());
      expect(item.isDesignerProduct, isFalse);
      expect(item.isManufacturerProduct, isFalse);
    });

    test('is_designer_product flag is honoured', () {
      final item = JewelryItem.fromJson(base()..['is_designer_product'] = true);
      expect(item.isDesignerProduct, isTrue);
      expect(item.isManufacturerProduct, isFalse);
    });

    test('is_manufacturer_product flag is honoured', () {
      final item =
          JewelryItem.fromJson(base()..['is_manufacturer_product'] = true);
      expect(item.isManufacturerProduct, isTrue);
      expect(item.isDesignerProduct, isFalse);
    });

    test('tags alone do NOT imply a designer product', () {
      // The exact misreading the old heuristic made: a scraped product that
      // happens to carry tags is still a `products` row.
      final item = JewelryItem.fromJson(
          base()..['Product Tags'] = <String>['gold', 'ring']);
      expect(item.tags, isNotNull);
      expect(item.isDesignerProduct, isFalse,
          reason: 'tags must not be used to infer the source table');
    });

    test('a designer product with no tags is still a designer product', () {
      final item = JewelryItem.fromJson(base()..['is_designer_product'] = true);
      expect(item.tags, anyOf(isNull, isEmpty));
      expect(item.isDesignerProduct, isTrue);
    });
  });

  group('JewelryItem image parsing', () {
    // fromJson has to cope with three schema generations at once while the
    // Phase 1 -> Phase 3 column rename is only half-done.
    test('prefers the unified images_arr column', () {
      final item = JewelryItem.fromJson({
        'id': 1,
        'images_arr': ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
        'Image': ['https://cdn/legacy.jpg'],
      });
      expect(item.image, 'https://cdn/a.jpg');
      expect(item.images, hasLength(2));
    });

    test('falls back to the legacy Image array', () {
      final item = JewelryItem.fromJson({
        'id': 1,
        'Image': ['https://cdn/legacy.jpg'],
      });
      expect(item.image, 'https://cdn/legacy.jpg');
    });

    test('survives a row with no image at all', () {
      final item = JewelryItem.fromJson({'id': 1});
      expect(item.image, '');
    });
  });
}
