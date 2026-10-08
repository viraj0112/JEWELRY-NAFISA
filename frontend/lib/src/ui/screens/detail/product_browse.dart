import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/product_page_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The list a product page was opened from (home grid, search results, a
/// board, "More like this"), so the page can swipe to the next product.
///
/// It travels as the GoRouter `extra` of `/product/:identifier`. It is not
/// kept in browser history, so a refreshed page or a shared link simply has no
/// list and opens a single product with swiping off.
class ProductBrowseList {
  const ProductBrowseList(this.items, this.index);

  final List<JewelryItem> items;
  final int index;

  /// Whether this list was opened on the product named by [identifier] (the
  /// `:identifier` path segment: a uid or an integer id).
  bool isFor(String identifier) {
    if (index < 0 || index >= items.length) return false;
    final item = items[index];
    return identifier == item.uid || identifier == item.id;
  }
}

/// The public URL of [item]'s page.
String productPath(JewelryItem item) =>
    '/product/${item.uid ?? item.id}?isDesigner=${item.isDesignerProduct}'
    '&isManufacturer=${item.isManufacturerProduct}';

bool isSameProduct(JewelryItem a, JewelryItem b) {
  if (a.uid != null && b.uid != null) return a.uid == b.uid;
  return a.id == b.id &&
      a.isDesignerProduct == b.isDesignerProduct &&
      a.isManufacturerProduct == b.isManufacturerProduct;
}

/// Opens [item]'s page. Pass the list it was shown in as [from] to let the
/// user swipe through the rest of that list.
void openProduct(BuildContext context, JewelryItem item,
    {List<JewelryItem>? from}) {
  final list = from == null ? null : List<JewelryItem>.unmodifiable(from);
  final index = list?.indexWhere((i) => isSameProduct(i, item)) ?? -1;
  context.push(
    productPath(item),
    extra: (list != null && list.length > 1 && index >= 0)
        ? ProductBrowseList(list, index)
        : null,
  );
}

/// Loads the full record for a product seen in a list: list queries often
/// select only the columns a card needs, and the detail page needs them all.
Future<JewelryItem?> loadFullProduct(JewelryItem item) {
  final uid = item.uid;
  if (uid != null && uid.isNotEmpty) return fetchProductByUid(uid);
  return JewelryService(Supabase.instance.client).getJewelryItem(
    item.id,
    isDesignerProduct: item.isDesignerProduct,
    isManufacturerProduct: item.isManufacturerProduct,
  );
}
