import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/get_quote_dialog.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart'; 

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

  // --- MODIFIED ---
  // Default to false. _initializeInteractionState will check if it should be true.
  bool _detailsRevealed = false;
  // --- END MODIFIED ---

  bool _isLoadingInteraction = true;
  bool _isLiking = false;
  bool _isSaving = false;

  String? _pinId;
  int _likeCount = 0;
  bool _userLiked = false;
  String? _shareSlug;

  // Define a duration for how long details remain unlocked
  static const _unlockDuration = Duration(days: 7);

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(supabase);
    _initializeInteractionState();
    _similarItemsFuture = _jewelryService.fetchSimilarItems(
      currentItemId: widget.jewelryItem.id.toString(),
      category: widget.jewelryItem.collectionName,
      limit: 10,
    );
  }

  String _generateRandomSlug(int length) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _initializeInteractionState() async {
    final uid = supabase.auth.currentUser?.id;

    final pinData = await supabase
        .from('pins')
        .select('id, like_count, share_slug')
        .eq('image_url', widget.jewelryItem.image)
        .maybeSingle();

    if (pinData != null) {
      final pinId = pinData['id'] as String;
      _pinId = pinId;
      _likeCount = (pinData['like_count'] ?? 0) as int;
      _shareSlug = pinData['share_slug'] as String?;

      if (uid != null) {
        final likeResponse = await supabase
            .from('user_likes')
            .select('user_id')
            .match({'user_id': uid, 'pin_id': pinId}).maybeSingle();
        _userLiked = (likeResponse != null);
      }
    }

    // --- ADDED: Check for existing unlock ---
    if (uid != null) {
      try {
        // Find the most recent 'valid' quote/unlock for this item
        final unlockData = await supabase
            .from('quotes')
            .select('status, expires_at')
            .match({
              'user_id': uid,
              'product_id': widget.jewelryItem.id.toString(),
              'status': 'valid',
            })
            .order('expires_at', ascending: false) // Get the latest one
            .limit(1)
            .maybeSingle();

        if (unlockData != null) {
          final expiresAtStr = unlockData['expires_at'] as String?;
          if (expiresAtStr != null) {
            final expiresAt = DateTime.tryParse(expiresAtStr);
            // Check if the expiration date is in the future
            if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
              _detailsRevealed = true; // Set to true if valid and not expired
            }
          }
        }
      } catch (e) {
        debugPrint("Error checking for unlocked item: $e");
        // _detailsRevealed remains false
      }
    }
    // --- END ADDED ---

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
      return null;
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _isLoadingInteraction) return;
    setState(() => _isLiking = true);

    final pinId = await _ensurePinExists();
    if (pinId == null) {
      setState(() => _isLiking = false);
      return;
    }

    final uid = supabase.auth.currentUser!.id;

    try {
      if (_userLiked) {
        await supabase
            .from('user_likes')
            .delete()
            .match({'user_id': uid, 'pin_id': pinId});
        await supabase.rpc('increment_like_count',
            params: {'pin_id_to_update': pinId, 'delta': -1});
        _likeCount--;
      } else {
        await supabase
            .from('user_likes')
            .insert({'user_id': uid, 'pin_id': pinId});
        await supabase.rpc('increment_like_count',
            params: {'pin_id_to_update': pinId, 'delta': 1});
        _likeCount++;
      }
      setState(() => _userLiked = !_userLiked);
    } catch (e) {
      debugPrint("Error toggling like: $e");
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _saveToBoard() async {
    if (_isSaving || _isLoadingInteraction) return;
    setState(() => _isSaving = true);

    final pinId = await _ensurePinExists();
    if (pinId == null) {
      setState(() => _isSaving = false);
      return;
    }

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

  Future<void> _shareItem() async {
    const String productBaseUrl = 'https://www.dagina.design/product';

    final String productUrl =
        '$productBaseUrl/${widget.jewelryItem.productTitle.toLowerCase().replaceAll(' ', '-')}'
        '${_shareSlug != null ? '?ref=${_shareSlug!}' : ''}';
    final String shareText =
        'Check out this beautiful ${widget.jewelryItem.productTitle}! $productUrl from Dagina Designs!';

    await Share.share(
      shareText,
      subject: 'Beautiful Jewelry from Dagina Designs',
    );
  }

  void _onGetQuotePressed() async {

    const String fromEnv = String.fromEnvironment('GOOGLE_FORM');
    final String fromDotEnv = dotenv.env['GOOGLE_FORM'] ?? '';
    final String googleFormUrl = fromEnv.isNotEmpty ? fromEnv : fromDotEnv;
    if (googleFormUrl.isEmpty) {
      debugPrint("GOOGLE_FORM environment variable is not set.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not open quote form. Please try again later.')),
        );
      }
      return;
    }

    final Uri googleFormUri = Uri.parse(googleFormUrl);

    if (await canLaunchUrl(googleFormUri)) {
      await launchUrl(googleFormUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open the form. Please try again later."),
          ),
        );
      }
    }
  }

  void _onGetDetailsPressed(BuildContext context) async {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);


    if (profile.creditsRemaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are out of credits! Share to get more.')),
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
          const SnackBar(
            content: Text('Could not get details. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_detailsRevealed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Product details saved to "View Detail History" on your profile.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return true; 
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WillPopScope(
          onWillPop: _onWillPop,
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
                  _onWillPop();
                  Navigator.of(context).pop();
                },
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.jewelryItem.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 48)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContentSection(),
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
                    Expanded(child: _buildSimilarItemsGrid()),
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
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 400,
          stretch: true,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            background: Image.network(
              widget.jewelryItem.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildContentSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("More like this",
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        _buildSimilarItemsGrid(isSliver: true),
      ],
    );
  }

  Widget _buildContentSection() {
    final theme = Theme.of(context);
    final userProfile = context.watch<UserProfileProvider>();
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
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          if (showFullDetails) ...[
            Text("Product Details", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),

            if (item.metalPurity != null && item.metalPurity!.isNotEmpty)
              _buildDetailRow("Metal Purity: ", item.metalPurity!),
            if (item.goldWeight != null && item.goldWeight!.isNotEmpty)
              _buildDetailRow("Metal Weight: ", item.goldWeight!),
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
                onPressed: _onGetQuotePressed, // Opens Google Form
                child: const Text('Get Quote'),
              ),
            ),
            // --- END ADDED ---
          ] else ...[
            Text("Description", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              "Full product details including metal type, purity, and stone details are available to members or by using a credit.",
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),

            // --- MODIFIED: This is now the "Get Details" button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onGetDetailsPressed(context),
                child: const Text('Get Details'),
              ),
            ),
            // --- END MODIFIED ---
          ],
        ],
      ),
    );
  }
  // --- END MODIFIED ---

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
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
                color:
                    _userLiked ? Colors.red : Theme.of(context).iconTheme.color,
              ),
        tooltip: _userLiked ? 'Unlike' : 'Like',
      ),
      IconButton(
        onPressed: _shareItem,
        icon: const Icon(Icons.share_outlined),
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
              ? const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()))
              : const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return isSliver
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : const SizedBox.shrink();
        }

        final items = snapshot.data!;
        final grid = MasonryGridView.count(
          physics: isSliver ? const NeverScrollableScrollPhysics() : null,
          shrinkWrap: isSliver,
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () {
                // Use pushReplacement to avoid building up a stack of detail pages
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JewelryDetailScreen(jewelryItem: item)),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  item.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[200]),
                ),
              ),
            );
          },
        );

        if (isSliver) {
          return SliverPadding(
              padding: const EdgeInsets.all(8.0), sliver: grid);
        } else {
          return Padding(padding: const EdgeInsets.all(8.0), child: grid);
        }
      },
    );
  }
}
