import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/get_quote_dialog.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:math';
import 'package:jewelry_nafisa/src/services/quote_service.dart';
import 'package:jewelry_nafisa/src/widgets/quote_request_dialog.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class JewelryDetailScreen extends StatefulWidget {
  final JewelryItem jewelryItem;

  const JewelryDetailScreen({
    super.key,
    required this.jewelryItem,
  });

  @override
  State<JewelryDetailScreen> createState() => _JewelryDetailScreenState();
}

class _JewelryDetailScreenState extends State<JewelryDetailScreen> {
  final supabase = Supabase.instance.client;
  late final JewelryService _jewelryService;
  late Future<List<JewelryItem>> _similarItemsFuture;

  bool _detailsRevealed = false;
  bool _isLoadingInteraction = true;
  bool _isLiking = false;
  bool _isSaving = false;

  bool _isSharing = false;

  late final String _itemId;
  late final String _itemTable;

  String? _pinId;
  int _likeCount = 0;
  bool _userLiked = false;
  String? _shareSlug;

  static const _unlockDuration = Duration(days: 7);

  @override
  void initState() {
    super.initState();

    _itemId = widget.jewelryItem.id;
    _itemTable = widget.jewelryItem.isDesignerProduct
        ? 'designerproducts'
        : 'products';

    _jewelryService = JewelryService(supabase);
    _initializeInteractionState();

    _similarItemsFuture = _jewelryService.fetchSimilarItems(
        currentItemId: _itemId,
        productType: widget.jewelryItem.productType,
        category: widget.jewelryItem.category,
        limit: 80,
        isDesigner: widget.jewelryItem.isDesignerProduct);

    final jewelryService = context.read<JewelryService>();

    _logView();
  }

  String _generateRandomSlug(int length) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _logView() async {
    final uid = supabase.auth.currentUser?.id;

    String? userCountry; // <-- TODO: Set this if you have it.

    try {
      await supabase.from('views').insert({
        'user_id': uid,
        'item_id': _itemId,
        'item_table': _itemTable,
        'country': userCountry,
      });
    } catch (e) {
      debugPrint('Error logging view: $e');
    }
  }

  Future<void> _initializeInteractionState() async {
    final uid = supabase.auth.currentUser?.id;

    try {
      _likeCount = await supabase
          .from('likes')
          .count(CountOption.exact)
          .match({'item_id': _itemId, 'item_table': _itemTable});
    } catch (e) {
      debugPrint("Error getting like count: $e");
      _likeCount = 0;
    }
    if (uid != null) {
      try {
        final likeResponse = await supabase
            .from('likes')
            .select('id')
            .match({
              'user_id': uid,
              'item_id': _itemId,
              'item_table': _itemTable,
            })
            .maybeSingle();

        _userLiked = (likeResponse != null);
      } catch (e) {
        debugPrint("Error checking user like: $e");
        _userLiked = false;
      }
    }

    if (uid != null) {
      try {
        final unlockData = await supabase
            .from('quotes')
            .select('status, expires_at')
            .match({
              'user_id': uid,
              'product_id': widget.jewelryItem.id.toString(),
              'status': 'valid',
            })
            .order('expires_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (unlockData != null) {
          final expiresAtStr = unlockData['expires_at'] as String?;
          if (expiresAtStr != null) {
            final expiresAt = DateTime.tryParse(expiresAtStr);
            if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
              _detailsRevealed = true;
            }
          }
        }
      } catch (e) {
        debugPrint("Error checking for unlocked item details: $e");
      }
    }

    if (mounted) {
      setState(() => _isLoadingInteraction = false);
    }
  }

  Future<String?> _ensurePinExists() async {
    if (_pinId != null) return _pinId;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to interact with items.")),
      );
      return null;
    }

    _shareSlug ??= _generateRandomSlug(8);

    try {
      final newPin = await supabase
          .from('pins')
          .insert({
            'owner_id': uid,
            'title': widget.jewelryItem.productTitle,
            'image_url': widget.jewelryItem.image,
            'description': widget.jewelryItem.description,
            'share_slug': _shareSlug
          })
          .select('id')
          .single();
      _pinId = newPin['id'];
      return _pinId;
    } catch (e) {
      debugPrint("Error creating pin on demand: $e");
      _shareSlug = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating interaction record: $e")),
        );
      }
      return null;
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _isLoadingInteraction) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to like items.")),
      );
      return;
    }

    setState(() => _isLiking = true);

    try {
      if (_userLiked) {
        await supabase.from('likes').delete().match(
            {'user_id': uid, 'item_id': _itemId, 'item_table': _itemTable});

        _likeCount--;
      } else {
        await supabase.from('likes').insert({
          'user_id': uid,
          'item_id': _itemId,
          'item_table': _itemTable
        });

        _likeCount++;
      }
      if (mounted) {
        setState(() => _userLiked = !_userLiked);
      }
    } catch (e) {
      debugPrint("Error toggling like: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating like status: $e")),
        );
      }
      // Revert count if error
      if (_userLiked)
        _likeCount++;
      else
        _likeCount--;
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _saveToBoard() async {
    if (_isSaving || _isLoadingInteraction) return;

    final pinId = await _ensurePinExists();
    if (pinId == null) {
      return;
    }

    setState(() => _isSaving = true);

    final boardsProvider = context.read<BoardsProvider>();
    await boardsProvider.fetchBoards();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => SaveToBoardDialog(item: widget.jewelryItem),
      );
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<Uint8List> _downloadImageBytes(String imageUrl) async {
    final uri = Uri.parse(imageUrl);

    if (uri.path.contains('/storage/v1/')) {
      final pathSegments = uri.pathSegments;
      int bucketIndex = pathSegments.indexOf('public');
      if (bucketIndex == -1) {
        bucketIndex = pathSegments.indexOf('object');
      }

      if (bucketIndex != -1 && (bucketIndex + 1) < pathSegments.length) {
        final bucket = pathSegments[bucketIndex + 1];
        final path = pathSegments.sublist(bucketIndex + 2).join('/');

        if (bucket == 'designer-files') {
          try {
            final bytes = await supabase.storage.from(bucket).download(path);
            return bytes;
          } catch (e) {
            debugPrint(
                'Supabase download failed: $e. Falling back to http.get');
          }
        }
      }
    }

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
  }

  Future<void> _shareItem() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    final item = widget.jewelryItem;
    const String productBaseUrl = 'https://www.dagina.design/product';

    final String slug = item.productTitle
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');

    final String productUrl = '$productBaseUrl/$slug';

    // Original Text (without image link)
    final String baseShareText =
        'Check out this beautiful ${item.productTitle}! $productUrl from Dagina Designs!';

    String sharePlatform = kIsWeb ? 'web' : 'mobile';

    try {
      if (item.image.isEmpty) {
        await Share.share(baseShareText, subject: 'Beautiful Jewelry');
      } else if (kIsWeb) {
        await Share.share(
          baseShareText,
          subject: 'Beautiful Jewelry',
        );
        // --- END WEB LOGIC ---
      } else {
        // --- MOBILE/DESKTOP LOGIC (Download and Share File) ---
        final bytes = await _downloadImageBytes(item.image);
        final tempDir = await getTemporaryDirectory();
        final fileName = 'shared_jewelry_image.png';
        final path = '${tempDir.path}/$fileName';
        final file = await File(path).writeAsBytes(bytes);
        final xFile = XFile(file.path, mimeType: 'image/png');

        await Share.shareXFiles(
          [xFile],
          text: baseShareText,
          subject: 'Check out this jewelry: ${item.productTitle}',
        );
      }

      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        try {
          await supabase.from('shares').insert({
            'user_id': uid,
            'item_id': _itemId,
            'item_table': _itemTable,
            'share_platform': sharePlatform,
          });
        } catch (e) {
          debugPrint('Error logging share: $e');
        }
      }
    } catch (e) {
      debugPrint("Error sharing item with image: $e");
      // If image download/saving fails, fall back to sharing text only
      await Share.share(baseShareText, subject: 'Beautiful Jewelry');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not share image, shared link only.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _showQuotePopup(BuildContext context) {
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final quoteService = Provider.of<QuoteService>(context, listen: false);
    final UserProfile? currentUser = userProfileProvider.userProfile;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to request a quote.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => QuoteRequestDialog(
        user: currentUser,
        product: widget.jewelryItem,
        quoteService: quoteService,
      ),
    );
  }

  void _onGetDetailsPressed(BuildContext context) async {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);

    if (profile.creditsRemaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'You are out of credits! Share your referral code to get more.')),
        );
      }
      return;
    }

    final bool? useCredit = await showDialog<bool>(
      context: context,
      builder: (context) => const GetQuoteDialog(),
    );

    if (useCredit == true) {
      await _useQuoteCredit(context);
    }
  }

  Future<void> _useQuoteCredit(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final uid = supabase.auth.currentUser?.id;

    if (uid == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to use credits.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await supabase.rpc('decrement_credit');
      profile.decrementCredit();
      final expiration = DateTime.now().add(_unlockDuration);

      await supabase.from('quotes').insert({
        'user_id': uid,
        'product_id': widget.jewelryItem.id.toString(),
        'status': 'valid',
        'expires_at': expiration.toIso8601String(),
      });
      if (widget.jewelryItem.isDesignerProduct) {
        // <-- ADD THIS CHECK
        await supabase.from('views').insert({
          'user_id': uid,
          'product_id': int.tryParse(widget.jewelryItem
              .id), // Also, ensure this is an int, since views.product_id is bigint
          'pin_id': null,
        });
      }

      if (mounted) {
        setState(() => _detailsRevealed = true);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Details revealed! One credit used.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error using quote credit: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not get details. Please try again. Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop && _detailsRevealed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Product details saved to "View Detail History" on your profile.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              return isWide ? _buildWideLayout(context) : _buildNarrowLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    // This is the "desktop" layout.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      // --- ADDITION: Wrapped image with InteractiveViewer for zoom ---
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0, // Allow zooming up to 4x
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            widget.jewelryItem.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, size: 48)),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                      // --- END ADDITION ---
                      const SizedBox(height: 16),
                      _buildContentSection(context),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                      child: Text("More like this",
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    Expanded(child: _buildSimilarItemsGrid(isSliver: false)), // Pass false for non-sliver
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    // This is the "mobile" layout.
    // --- MODIFICATION: Added DefaultTabController for mobile tabs ---
    return DefaultTabController(
      length: 2,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            stretch: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            // --- MODIFICATION: Added TabBar to the bottom of the app bar ---
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'More Like This'),
              ],
            ),
            // --- MODIFICATION: Wrapped image with InteractiveViewer for zoom ---
            flexibleSpace: FlexibleSpaceBar(
              background: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0, // Allow zooming up to 4x
                child: Image.network(
                  widget.jewelryItem.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image)),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            // --- END MODIFICATION ---
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
          ),
          // --- MODIFICATION: Replaced content/grid slivers with a TabBarView ---
          SliverFillRemaining(
            child: TabBarView(
              children: [
                // Tab 1: Details
                SingleChildScrollView(
                  child: _buildContentSection(context),
                ),
                // Tab 2: More Like This
                _buildSimilarItemsGrid(isSliver: false), // isSliver is false now
              ],
            ),
          ),
          // --- END MODIFICATION ---
        ],
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.jewelryItem;

    final bool showTitle = _detailsRevealed;
    final bool showFullDetails = _detailsRevealed;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildActionButtons(),
          ),
          const SizedBox(height: 8),
          Text(
            showTitle ? item.productTitle : "Jewelry Design",
            style: theme.textTheme.headlineMedium,
          ),
          if (_likeCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 24),
          if (showFullDetails) ...[
            Text("Product Details", style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (item.metalPurity != null && item.metalPurity!.isNotEmpty)
              _buildDetailRow("Metal Purity: ", item.metalPurity!),
            if (item.goldWeight != null && item.goldWeight!.isNotEmpty)
              _buildDetailRow("Metal Weight: ", item.goldWeight!),
            if (item.metalWeight != null && item.metalWeight!.isNotEmpty)
              _buildDetailRow("Metal Weight: ", item.metalWeight!),
            if (item.metalColor != null && item.metalColor!.isNotEmpty)
              _buildDetailRow("Metal Color: ", item.metalColor!),
            if (item.metalFinish != null && item.metalFinish!.isNotEmpty)
              _buildDetailRow("Metal Finish: ", item.metalFinish!),
            if (item.metalType != null && item.metalType!.isNotEmpty)
              _buildDetailRow("Metal Type: ", item.metalType!),
            if (item.stoneType != null && item.stoneType!.isNotEmpty)
              _buildDetailRow("Stone Type:", item.stoneType!.join(', ')),
            if (item.stoneColor != null && item.stoneColor!.isNotEmpty)
              _buildDetailRow("Stone Color: ", item.stoneColor!.join(', ')),
            if (item.stoneCount != null && item.stoneCount!.isNotEmpty)
              _buildDetailRow("Stone Count: ", item.stoneCount!.join(', ')),
            if (item.stonePurity != null && item.stonePurity!.isNotEmpty)
              _buildDetailRow("Stone Purity: ", item.stonePurity!.join(', ')),
            if (item.stoneCut != null && item.stoneCut!.isNotEmpty)
              _buildDetailRow("Stone Cut", item.stoneCut!.join(', ')),
            if (item.stoneUsed != null && item.stoneUsed!.isNotEmpty)
              _buildDetailRow("Stone Used: ", item.stoneUsed!.join(', ')),
            if (item.stoneWeight != null && item.stoneWeight!.isNotEmpty)
              _buildDetailRow("Stone Weight: ", item.stoneWeight!.join(', ')),
            if (item.stoneSetting != null && item.stoneSetting!.isNotEmpty)
              _buildDetailRow(
                  "Stone Settings: ", item.stoneSetting!.join(', ')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showQuotePopup(context),
                child: const Text('Get Quote'),
              ),
            ),
          ] else ...[
            Text(
              'Unlock detailed product specifications by using a credit.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onGetDetailsPressed(context),
                child: const Text('Get Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'n/a') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final iconColor = Theme.of(context).iconTheme.color;
    return [
      IconButton(
        onPressed: _isLiking ? null : _toggleLike,
        icon: _isLiking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                _userLiked ? Icons.favorite : Icons.favorite_border,
                color: _userLiked ? Colors.red : iconColor,
              ),
        tooltip: _userLiked ? 'Unlike' : 'Like',
      ),
      IconButton(
        onPressed: _isSharing ? null : _shareItem,
        icon: _isSharing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.share_outlined),
        tooltip: 'Share',
      ),
      IconButton(
        onPressed: _isSaving ? null : _saveToBoard,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_add_outlined),
        tooltip: 'Save to Board',
      ),
    ];
  }

  Widget _buildSimilarItemsGrid({bool isSliver = false}) {
    return FutureBuilder<List<JewelryItem>>(
      future: _similarItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return isSliver
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final errorText = 'Error loading similar items: ${snapshot.error}';
          debugPrint(errorText);
          return isSliver
              ? SliverToBoxAdapter(child: Center(child: Text(errorText)))
              : Center(child: Text(errorText));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return isSliver
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : const SizedBox.shrink();
        }

        final items = snapshot.data!;
        final gridWidget = MasonryGridView.count(
          // --- MODIFICATION: Set physics based on context ---
          // If it's in a tab (not sliver), it needs its own scroll physics.
          // If it was a sliver, it shouldn't scroll independently.
          physics: isSliver
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          shrinkWrap: isSliver, // Still true if it's a sliver
          crossAxisCount:
              (MediaQuery.of(context).size.width / 180).floor().clamp(2, 4),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () {
                // --- FIX: Use push instead of pushReplacement ---
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JewelryDetailScreen(jewelryItem: item)),
                );
                // --- END FIX ---
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  item.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image)),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          },
        );

        if (isSliver) {
          return SliverPadding(
              padding: const EdgeInsets.all(8.0), sliver: gridWidget);
        } else {
          // --- MODIFICATION: Add padding when not a sliver (for tab view) ---
          return Padding(padding: const EdgeInsets.all(8.0), child: gridWidget);
        }
      },
    );
  }
}