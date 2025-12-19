import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // For ImageFilter
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
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:jewelry_nafisa/src/services/quote_service.dart';
import 'package:jewelry_nafisa/src/widgets/quote_request_dialog.dart';
import 'package:jewelry_nafisa/src/widgets/login_required_dialog.dart';
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
    final ScrollController _thumbnailScrollController = ScrollController();
  late final PageController _pageController; // Add PageController
  int _thumbnailStartIndex = 0; // Track which thumbnails to show

  final supabase = Supabase.instance.client;
  late final JewelryService _jewelryService;
  late Future<List<JewelryItem>> _similarItemsFuture;
  int _selectedImageIndex = 0;
late List<String> _imageUrls;

  bool _detailsRevealed = false;
  JewelryItem? _fullProductDetails; // Store full product details after revealing
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
    _itemTable =
        widget.jewelryItem.isDesignerProduct ? 'designerproducts' : 'products';

    _jewelryService = JewelryService(supabase);
    // Use the images list if available, otherwise fallback to the single image
    if (widget.jewelryItem.images != null && widget.jewelryItem.images!.isNotEmpty) {
      _imageUrls = widget.jewelryItem.images!;
    } else {
      _imageUrls = [widget.jewelryItem.image];
    }
    _pageController = PageController(initialPage: _selectedImageIndex); // Initialize PageController
    _initializeInteractionState();
  void dispose() {
    _thumbnailScrollController.dispose();
    _pageController.dispose(); // Dispose PageController
    super.dispose();
  }
    _similarItemsFuture = _jewelryService.fetchSimilarItems(
        currentItemId: _itemId,
        productType: widget.jewelryItem.productType,
        category: widget.jewelryItem.category,
        subCategory: widget.jewelryItem.subCategory,
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
        final likeResponse = await supabase.from('likes').select('id').match({
          'user_id': uid,
          'item_id': _itemId,
          'item_table': _itemTable,
        }).maybeSingle();

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
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LoginRequiredDialog(),
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
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LoginRequiredDialog(),
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
        FirebaseAnalytics.instance.logEvent(
        name: 'like_item',
        parameters: {
          'item_id': _itemId,
          'item_name': widget.jewelryItem.productTitle,
          'content_type': 'jewelry',
        },
      );
        await supabase.from('likes').insert(
            {'user_id': uid, 'item_id': _itemId, 'item_table': _itemTable});

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

    FirebaseAnalytics.instance.logShare(
    contentType: 'jewelry_item',
    itemId: _itemId,
    method: kIsWeb ? 'web_share' : 'mobile_share',
  );

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
        showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LoginRequiredDialog(),
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
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LoginRequiredDialog(),
      );
      return;
    }

    try {
      // --- SECURE: Use RPC to deduct credit and create quote on server ---
      final response = await supabase.rpc('redeem_quote_credit', params: {
        'p_product_id': widget.jewelryItem.id.toString(),
        'p_is_designer': widget.jewelryItem.isDesignerProduct,
      });

      // Update local state based on server response
      if (response != null && response['success'] == true) {
        profile.decrementCredit(); // Optimistic update or sync with response
        

        await FirebaseAnalytics.instance.logSpendVirtualCurrency(
        itemName: 'reveal_details', // What they bought
        virtualCurrencyName: 'credits', // Currency type
        value: 1, // Amount spent
      );
      
      // Optional: Track specifically as a "lead" generation
      await FirebaseAnalytics.instance.logEvent(
        name: 'get_quote_unlocked',
        parameters: {
          'item_id': widget.jewelryItem.id,
          'item_name': widget.jewelryItem.productTitle,
        },
      );
      
        if (mounted) {
          // Refetch full product details with all columns
          // Pass isDesignerProduct flag to ensure we query the correct table
          final fullProduct = await _jewelryService.getJewelryItem(
            _itemId,
            isDesignerProduct: widget.jewelryItem.isDesignerProduct,
          );
          
          setState(() {
            _detailsRevealed = true;
            if (fullProduct != null) {
              _fullProductDetails = fullProduct;
              // Update image URLs if new images are available
              if (fullProduct.images != null && fullProduct.images!.isNotEmpty) {
                _imageUrls = fullProduct.images!;
              }
            }
            // Refetch similar items after revealing details to get more results
            _similarItemsFuture = _jewelryService.fetchSimilarItems(
              currentItemId: _itemId,
              productType: _fullProductDetails?.productType ?? widget.jewelryItem.productType,
              category: _fullProductDetails?.category ?? widget.jewelryItem.category,
              subCategory: _fullProductDetails?.subCategory ?? widget.jewelryItem.subCategory,
              limit: 80,
              isDesigner: widget.jewelryItem.isDesignerProduct,
            );
          });
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Details revealed! One credit used.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error using quote credit: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Could not get details. Please try again. Error: ${e is PostgrestException ? e.message : e.toString()}'),
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
                    Consumer<UserProfileProvider>(
                      builder: (context, userProfile, child) {
                        final bool isLocked = !userProfile.isMember && _selectedImageIndex > 0;
                        
                        return AspectRatio(
                          aspectRatio: widget.jewelryItem.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: _imageUrls.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _selectedImageIndex = index;
                                    // Update thumbnail scroll if needed
                                    if (index < _thumbnailStartIndex) {
                                      _thumbnailStartIndex = index;
                                    } else if (index >= _thumbnailStartIndex + 3) {
                                      _thumbnailStartIndex = index - 2;
                                    }
                                  });
                                },
                                itemBuilder: (context, index) {
                                  // Lock logic per image
                                  final bool isImageLocked = !userProfile.isMember && index > 0;
                                  
                                  return InteractiveViewer(
                                    minScale: 1.0,
                                    maxScale: isImageLocked ? 1.0 : 4.0, // Disable zoom if locked
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: isImageLocked ? 10.0 : 0.0,
                                          sigmaY: isImageLocked ? 10.0 : 0.0,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: _imageUrls[index],
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Center(
                                              child: Icon(Icons.broken_image, size: 48)),
                                          placeholder: (context, url) =>
                                              const Center(
                                                  child: CircularProgressIndicator()),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (isLocked)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        "Members Only",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // --- ADDITION: Desktop Navigation Arrows ---
                              if (_imageUrls.length > 1) ...[
                                Positioned(
                                  left: 16,
                                  child: IconButton(
                                    onPressed: _selectedImageIndex > 0
                                        ? () {
                                            _pageController.previousPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black.withOpacity(0.5),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 16,
                                  child: IconButton(
                                    onPressed: _selectedImageIndex < _imageUrls.length - 1
                                        ? () {
                                            _pageController.nextPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black.withOpacity(0.5),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ),
                              ],
                              // --- END ADDITION ---
                            ],
                          ),
                        );
                      },
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
                  Expanded(
                      child: _buildSimilarItemsGrid(
                          isSliver: false)), // Pass false for non-sliver
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
  return DefaultTabController(
    length: 2,
    child: CustomScrollView(
      slivers: [
        // ---------------- IMAGE SLIVER ----------------
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          stretch: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Consumer<UserProfileProvider>(
              builder: (context, userProfile, child) {
                final bool isLocked =
                    !userProfile.isMember && _selectedImageIndex > 0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _selectedImageIndex = index;
                          if (index < _thumbnailStartIndex) {
                            _thumbnailStartIndex = index;
                          } else if (index >= _thumbnailStartIndex + 3) {
                            _thumbnailStartIndex = index - 2;
                          }
                        });
                      },
                      itemBuilder: (context, index) {
                        final bool isImageLocked =
                            !userProfile.isMember && index > 0;

                        return InteractiveViewer(
                          minScale: 1.0,
                          maxScale: isImageLocked ? 1.0 : 4.0,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(
                              sigmaX: isImageLocked ? 10.0 : 0.0,
                              sigmaY: isImageLocked ? 10.0 : 0.0,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        );
                      },
                    ),
                    if (isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Members Only",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),

        // ---------------- TAB BAR (SEPARATE SLIVER) ----------------
        SliverToBoxAdapter(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(40),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromARGB(255, 194, 201, 198),
                    Color(0xFF006435).withOpacity(0.6),
                  ],
                ),
              ),
              child:const TabBar(
  indicator: BoxDecoration(), // removes underline completely
  indicatorSize: TabBarIndicatorSize.tab,
  labelColor: Colors.white,       // active tab text
  unselectedLabelColor: Colors.black, // inactive tab text
  labelStyle: TextStyle(
    fontWeight: FontWeight.bold,
  ),
  tabs: [
    Tab(text: 'Details'),
    Tab(text: 'More Like This'),
  ],
),
            ),
          ),
        ),

        // ---------------- TAB CONTENT ----------------
        SliverFillRemaining(
          child: TabBarView(
            children: [
              SingleChildScrollView(
                child: _buildContentSection(context),
              ),
              _buildSimilarItemsGrid(isSliver: false),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildContentSection(BuildContext context) {
  final theme = Theme.of(context);
  // Use full product details if available, otherwise use initial item
  final item = _fullProductDetails ?? widget.jewelryItem;

  final bool showTitle = _detailsRevealed;
  final bool showFullDetails = _detailsRevealed;
  print('showTitle: $showTitle, showFullDetails: $showFullDetails');
  print('Title: ${item.productTitle}');
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Updated Row with thumbnails and action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildImageThumbnails(), // Thumbnails on the left
            Row(
              children: _buildActionButtons(), // Action buttons on the right
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          showTitle ? item.productTitle : "Jewellery Design",
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
          ...(() {
            if (item.stoneType != null) {
              final stoneTypeValue = _filterAndJoinList(item.stoneType);
              if (stoneTypeValue.isNotEmpty) {
                return [_buildDetailRow("Stone Type:", stoneTypeValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneColor != null) {
              final stoneColorValue = _filterAndJoinList(item.stoneColor);
              if (stoneColorValue.isNotEmpty) {
                return [_buildDetailRow("Stone Color: ", stoneColorValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneCount != null) {
              final stoneCountValue = _filterAndJoinList(item.stoneCount);
              if (stoneCountValue.isNotEmpty) {
                return [_buildDetailRow("Stone Count: ", stoneCountValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stonePurity != null) {
              final stonePurityValue = _filterAndJoinList(item.stonePurity);
              if (stonePurityValue.isNotEmpty) {
                return [_buildDetailRow("Stone Purity: ", stonePurityValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneCut != null) {
              final stoneCutValue = _filterAndJoinList(item.stoneCut);
              if (stoneCutValue.isNotEmpty) {
                return [_buildDetailRow("Stone Cut", stoneCutValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneUsed != null) {
              final stoneUsedValue = _filterAndJoinList(item.stoneUsed);
              if (stoneUsedValue.isNotEmpty) {
                return [_buildDetailRow("Stone Used: ", stoneUsedValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneWeight != null) {
              final stoneWeightValue = _filterAndJoinList(item.stoneWeight);
              if (stoneWeightValue.isNotEmpty) {
                return [_buildDetailRow("Stone Weight: ", stoneWeightValue)];
              }
            }
            return <Widget>[];
          })(),
          ...(() {
            if (item.stoneSetting != null) {
              final stoneSettingValue = _filterAndJoinList(item.stoneSetting);
              if (stoneSettingValue.isNotEmpty) {
                return [_buildDetailRow("Stone Settings: ", stoneSettingValue)];
              }
            }
            return <Widget>[];
          })(),
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
  // Helper function to filter out null/empty values from lists
  String _filterAndJoinList(List<String>? list) {
    if (list == null || list.isEmpty) return '';
    final filtered = list.where((s) {
      final trimmed = s.trim();
      return trimmed.isNotEmpty && 
             trimmed.toLowerCase() != 'null' &&
             trimmed.toLowerCase() != 'none' &&
             trimmed.toLowerCase() != 'n/a' &&
             trimmed.toLowerCase() != 'na';
    }).toList();
    return filtered.join(', ');
  }

  Widget _buildDetailRow(String title, String value) {
    final trimmedValue = value.trim();
    // Don't display if value is empty, null, "null", "none", "n/a", or "na"
    if (trimmedValue.isEmpty || 
        trimmedValue.toLowerCase() == 'null' ||
        trimmedValue.toLowerCase() == 'none' ||
        trimmedValue.toLowerCase() == 'n/a' ||
        trimmedValue.toLowerCase() == 'na') {
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

Widget _buildImageThumbnails() {
  if (_imageUrls.length <= 1) return const SizedBox.shrink();
  
  // Calculate visible thumbnails (max 3 at a time)
  final visibleCount = _imageUrls.length > 3 ? 3 : _imageUrls.length;
  final maxStartIndex = _imageUrls.length - visibleCount;
  
  return SizedBox(
    width: 270, // Increased width: 3 thumbnails (60x3=180) + margins (8x6=48) + arrows (2x16=32)
    height: 60,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Arrow
        if (_imageUrls.length > 3)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _thumbnailStartIndex > 0
                ? () {
                    setState(() {
                      // Jump back by 3 images (but not below 0)
                      _thumbnailStartIndex = (_thumbnailStartIndex - 3).clamp(0, maxStartIndex);
                    });
                  }
                : null,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          const SizedBox(width: 0),
        
        // Thumbnails (show only 3)
        ...List.generate(visibleCount, (i) {
          final index = _thumbnailStartIndex + i;
          final isSelected = index == _selectedImageIndex;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedImageIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: _imageUrls[index],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
          );
        }),
        
        // Right Arrow
        if (_imageUrls.length > 3)
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _thumbnailStartIndex < maxStartIndex
                ? () {
                    setState(() {
                      // Jump forward by 3 images (but not beyond max)
                      _thumbnailStartIndex = (_thumbnailStartIndex + 3).clamp(0, maxStartIndex);
                    });
                  }
                : null,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          const SizedBox(width: 0),
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
                // --- FIX: Use GoRouter push for deep linking support ---
                context.push('/product/${item.id}');
                // --- END FIX ---
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image)),
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
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
