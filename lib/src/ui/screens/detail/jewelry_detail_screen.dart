import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/get_quote_dialog.dart';
import 'package:jewelry_nafisa/src/ui/widgets/save_to_board_dialog.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

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

  String? _pinId;
  int _likeCount = 0;
  bool _userLiked = false;

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(supabase);
    _initializeInteractionState();
    _similarItemsFuture = _jewelryService.fetchSimilarItems(
      // FIX: Changed currentItemId to be an int
      currentItemId: widget.jewelryItem.id.toString(),
      category: widget.jewelryItem.category,
      limit: 10,
    );
  }

  Future<void> _initializeInteractionState() async {
    final uid = supabase.auth.currentUser?.id;

    // FIX: Changed widget.jewelryItem.imageUrl to widget.jewelryItem.image
    final pinData = await supabase
        .from('pins')
        .select('id, like_count')
        .eq('image_url', widget.jewelryItem.image)
        .maybeSingle();

    if (pinData != null) {
      final pinId = pinData['id'] as String;
      _pinId = pinId;
      _likeCount = (pinData['like_count'] ?? 0) as int;

      if (uid != null) {
        final likeResponse = await supabase
            .from('user_likes')
            .select('user_id')
            .match({'user_id': uid, 'pin_id': pinId}).maybeSingle();
        _userLiked = (likeResponse != null);
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

    try {
      final newPin = await supabase
          .from('pins')
          .insert({
            'owner_id': uid,
            // FIX: Changed widget.jewelryItem.name to widget.jewelryItem.title
            'title': widget.jewelryItem.title,
            // FIX: Changed widget.jewelryItem.imageUrl to widget.jewelryItem.image
            'image_url': widget.jewelryItem.image,
            'description': widget.jewelryItem.description,
          })
          .select('id')
          .single();
      _pinId = newPin['id'];
      return _pinId;
    } catch (e) {
      debugPrint("Error creating pin on demand: $e");
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
    // FIX: Changed widget.jewelryItem.name to widget.jewelryItem.title
    final shareText =
        'Check out this beautiful ${widget.jewelryItem.title} from AKD Designs!';
    await Share.share(shareText, subject: 'Beautiful Jewelry from AKD');
  }

  void _onGetQuotePressed(BuildContext context) async {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final bool? useCredit = await showDialog<bool>(
      context: context,
      builder: (context) => const GetQuoteDialog(),
    );

    if (useCredit == true) {
      if (profile.creditsRemaining > 0) {
        await _useQuoteCredit(context);
        if (mounted) setState(() => _detailsRevealed = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are out of credits!')),
          );
        }
      }
    }
  }

  Future<void> _useQuoteCredit(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    try {
      await supabase.rpc('decrement_credit');
      profile.decrementCredit();
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isWide = constraints.maxWidth > 800;
            return isWide ? _buildWideLayout() : _buildNarrowLayout();
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
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
                          // FIX: Changed widget.jewelryItem.imageUrl to widget.jewelryItem.image
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
              // FIX: Changed widget.jewelryItem.imageUrl to widget.jewelryItem.image
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
    final isMember = userProfile.isMember;
    final item = widget.jewelryItem;

    final bool showTitle = isMember || _detailsRevealed;
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
            // FIX: Changed item.name to item.title
            showTitle ? item.title : "Jewelry Design",
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
            // FIX: Changed to convert int id to String and used new properties
            _buildDetailRow("SKU:", item.id.toString()),
            if (item.goldCarat != null)
              _buildDetailRow("Gold Carat:", item.goldCarat!),
            if (item.goldWeight != null)
              _buildDetailRow("Gold Weight:", item.goldWeight!),
            if (item.stoneType != null)
              _buildDetailRow("Stone:", item.stoneType!),
            if (item.description != null && item.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  item.description!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            const SizedBox(height: 24),
          ] else ...[
            Text("Description", style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              "Full product details including metal type, purity, weight, and SKU are available to members or by using a credit.",
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onGetQuotePressed(context),
                child: const Text('Get Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JewelryDetailScreen(jewelryItem: item)),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  // FIX: Changed item.imageUrl to item.image
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
