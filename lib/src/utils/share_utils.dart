import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/jewelry_item.dart';

class ShareUtils {
  // ── Public entry point ────────────────────────────────────────────────────
  // Shows a bottom sheet with Copy Link + Share options.
  static Future<void> shareJewelryItem(
      BuildContext context, JewelryItem item, SupabaseClient supabase) async {
    final String productUrl = await _buildProductUrl(item, supabase);
    final String shareText =
        'Check out this beautiful ${_cleanTitle(item.productTitle)}! $productUrl from Dagina Designs!';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareBottomSheet(
        item: item,
        productUrl: productUrl,
        shareText: shareText,
        supabase: supabase,
      ),
    );
  }

  // ── URL builder ───────────────────────────────────────────────────────────
  // When item.uid is null (common for bulk-loaded home/welcome screen items),
  // we do a targeted single-column DB lookup to get the uid before sharing.
  static Future<String> _buildProductUrl(
      JewelryItem item, SupabaseClient supabase) async {
    const String productBaseUrl = 'https://www.dagina.design/product';

    // 1. uid already on the item (best case)
    if (item.uid != null && item.uid!.isNotEmpty) {
      debugPrint('Share URL: using uid=${item.uid}');
      return '$productBaseUrl/${item.uid}';
    }

    // 2. uid is null — fetch it directly from the right table
    debugPrint('Share URL: uid is null for ${item.productTitle}, fetching from DB…');
    try {
      String table = 'products';
      if (item.isDesignerProduct) table = 'designerproducts';
      if (item.isManufacturerProduct) table = 'manufacturerproducts';

      final idInt = int.tryParse(item.id);
      if (idInt != null) {
        final response = await supabase
            .from(table)
            .select('uid')
            .eq('id', idInt)
            .maybeSingle();

        final fetchedUid = response?['uid']?.toString();
        if (fetchedUid != null && fetchedUid.isNotEmpty) {
          debugPrint('Share URL: fetched uid=$fetchedUid from $table');
          return '$productBaseUrl/$fetchedUid';
        }
      }
    } catch (e) {
      debugPrint('Share URL: DB uid fetch failed: $e');
    }

    // 3. Final fallback: clean slug (uid not yet populated in DB for this item)
    final String slug = _buildSlug(item.productTitle);
    debugPrint('Share URL: uid still null after DB fetch, using slug=$slug');
    return '$productBaseUrl/$slug';
  }

  static String _buildSlug(String title) {
    final String cleanTitle = title
        .replaceAll(RegExp(r'[A-Z]{2,}[0-9]+|[0-9]+[A-Z]{2,}'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    final words = cleanTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(6)
        .toList();

    return words.join('-');
  }

  static String _cleanTitle(String title) =>
      title.replaceAll(RegExp(r'[A-Z]{2,}[0-9]+|[0-9]+[A-Z]{2,}'), '').trim();

  // ── Log share event to Supabase ───────────────────────────────────────────
  static Future<void> _logShare(
      JewelryItem item, SupabaseClient supabase, String platform) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    String itemTable = 'products';
    if (item.isDesignerProduct) itemTable = 'designerproducts';
    if (item.isManufacturerProduct) itemTable = 'manufacturerproducts';

    try {
      await supabase.from('shares').insert({
        'user_id': userId,
        'item_id': item.id,
        'item_table': itemTable,
        if (item.uid != null) 'item_uid': item.uid,
        'share_platform': platform,
      });
    } catch (e) {
      debugPrint('Error logging share: $e');
    }
  }

  // ── Image download helper ─────────────────────────────────────────────────
  static Future<Uint8List> downloadImageBytes(
      String imageUrl, SupabaseClient supabase) async {
    final uri = Uri.parse(imageUrl);

    if (uri.path.contains('/storage/v1/')) {
      final pathSegments = uri.pathSegments;
      int bucketIndex = pathSegments.indexOf('public');
      if (bucketIndex == -1) bucketIndex = pathSegments.indexOf('object');

      if (bucketIndex != -1 && (bucketIndex + 1) < pathSegments.length) {
        final bucket = pathSegments[bucketIndex + 1];
        final path = pathSegments.sublist(bucketIndex + 2).join('/');
        if (bucket == 'designer-files') {
          try {
            return await supabase.storage.from(bucket).download(path);
          } catch (e) {
            debugPrint(
                'Supabase download failed: $e. Falling back to http.get');
          }
        }
      }
    }

    final response = await http.get(uri);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Failed to download image: ${response.statusCode}');
  }

  // ── Native share (text + optional image) ─────────────────────────────────
  static Future<void> doNativeShare({
    required JewelryItem item,
    required String shareText,
    required SupabaseClient supabase,
    required BuildContext context,
  }) async {
    try {
      if (item.image.isEmpty || kIsWeb) {
        await Share.share(shareText, subject: 'Beautiful Jewelry');
      } else {
        final bytes = await downloadImageBytes(item.image, supabase);
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/shared_jewelry_image.png';
        final file = await File(path).writeAsBytes(bytes);
        final xFile = XFile(file.path, mimeType: 'image/png');
        await Share.shareXFiles(
          [xFile],
          text: shareText,
          subject: 'Check out this jewelry: ${item.productTitle}',
        );
      }
      await _logShare(item, supabase, kIsWeb ? 'web' : 'mobile');
    } catch (e) {
      debugPrint('Native share failed: $e');
      await Share.share(shareText, subject: 'Beautiful Jewelry');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not share image, shared link only.')),
        );
      }
    }
  }
}

// ── Bottom Sheet Widget ───────────────────────────────────────────────────────
class _ShareBottomSheet extends StatelessWidget {
  final JewelryItem item;
  final String productUrl;
  final String shareText;
  final SupabaseClient supabase;

  const _ShareBottomSheet({
    required this.item,
    required this.productUrl,
    required this.shareText,
    required this.supabase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Share this product',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),

          // URL preview chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    productUrl,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Copy Link button
          _ActionTile(
            icon: Icons.copy_rounded,
            label: 'Copy link',
            subtitle: 'Copy the product link to clipboard',
            color: const Color(0xFF7B5EA7),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: productUrl));
              await ShareUtils._logShare(item, supabase, 'clipboard');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Link copied to clipboard!'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF7B5EA7),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Share via... button
          _ActionTile(
            icon: Icons.share_rounded,
            label: 'Share via…',
            subtitle: 'Send to WhatsApp, Instagram, Email & more',
            color: const Color(0xFF2196F3),
            onTap: () async {
              Navigator.pop(context);
              await ShareUtils.doNativeShare(
                item: item,
                shareText: shareText,
                supabase: supabase,
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
