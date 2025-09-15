import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/widgets/get_quote_dialog.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class JewelryDetailScreen extends StatefulWidget {
  final String imageUrl;
  final String itemName;
  final String? pinId;

  const JewelryDetailScreen({
    super.key,
    required this.imageUrl,
    required this.itemName,
    this.pinId,
  });

  @override
  State<JewelryDetailScreen> createState() => _JewelryDetailScreenState();
}

class _JewelryDetailScreenState extends State<JewelryDetailScreen> {
  final supabase = Supabase.instance.client;
  final JewelryService _jewelryService = JewelryService();
  late Future<List<JewelryItem>> _similarItemsFuture;
  bool isLiking = false;
  bool isSaving = false;
  String? pinId;
  String? shareSlug;
  int likeCount = 0;
  bool userLiked = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    pinId = widget.pinId;
    _initializePin();
    _similarItemsFuture = _jewelryService.fetchJewelryItems(
      limit: 10,
      offset: 10,
    );
  }

  Future<void> _ensureSupabaseSession() async {
    try {
      if (supabase.auth.currentUser != null) {
        return;
      }
      debugPrint('No Supabase session found');
    } catch (e) {
      debugPrint('Error ensuring Supabase session: $e');
    }
  }

  Future<void> _initializePin() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await _ensureSupabaseSession();
      final uid = supabase.auth.currentUser?.id;
      debugPrint('Current Supabase user ID: $uid');

      var response = await supabase
          .from('pins')
          .select('id, like_count, share_slug')
          .eq('image_url', widget.imageUrl)
          .maybeSingle();

      if (response == null) {
        if (uid == null) {
          debugPrint("Cannot create pin: User not logged in.");
          if (mounted) setState(() => isLoading = false);
          return;
        }
        debugPrint('Creating new pin for user: $uid');
        response = await supabase
            .from('pins')
            .insert({
              'owner_id': uid,
              'title': widget.itemName,
              'image_url': widget.imageUrl,
              'description': 'Beautiful jewelry piece from AKD',
            })
            .select('id, like_count, share_slug')
            .single();
      }

      pinId = response['id'] as String;
      likeCount = (response['like_count'] ?? 0) as int;
      shareSlug = response['share_slug'] as String?;

      await _incrementViewCount();

      if (uid != null) {
        final likeResponse = await supabase
            .from('user_likes')
            .select('user_id')
            .match({'user_id': uid, 'pin_id': pinId!})
            .maybeSingle();
        userLiked = (likeResponse != null);
      }
    } catch (e) {
      debugPrint('Error initializing pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load pin details.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (pinId == null || isLiking) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to like items.")),
      );
      return;
    }

    if (mounted) setState(() => isLiking = true);

    try {
      if (userLiked) {
        await supabase.from('user_likes').delete().match({
          'user_id': uid,
          'pin_id': pinId!,
        });
        await supabase.rpc(
          'increment_like_count',
          params: {'pin_id_to_update': pinId, 'delta': -1},
        );
      } else {
        await supabase.from('user_likes').insert({
          'user_id': uid,
          'pin_id': pinId,
        });
        await supabase.rpc(
          'increment_like_count',
          params: {'pin_id_to_update': pinId, 'delta': 1},
        );
      }

      final updatedData = await supabase
          .from('pins')
          .select('like_count')
          .eq('id', pinId!)
          .single();

      if (mounted) {
        setState(() {
          likeCount = updatedData['like_count'] ?? 0;
          userLiked = !userLiked;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like status.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLiking = false);
    }
  }

  Future<void> _sharePin() async {
    if (pinId == null) return;

    try {
      if (shareSlug == null || shareSlug!.isEmpty) {
        debugPrint('Generating new share slug for pin: $pinId');
        final generatedSlug = await supabase.rpc('gen_share_slug');
        shareSlug = generatedSlug as String;
        debugPrint('Generated share slug: $shareSlug');

        await supabase
            .from('pins')
            .update({'share_slug': shareSlug})
            .eq('id', pinId!);
      }

      final baseUrl = dotenv.env['BASE_SHARE_URL'] ?? 'https://daginawala.in';
      final shareUrl = '$baseUrl/p/$shareSlug';
      await Share.share(
        'Check out this beautiful ${widget.itemName} from AKD Designs: $shareUrl',
        subject: 'Beautiful Jewelry from AKD',
      );
    } catch (e) {
      debugPrint('Error sharing pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create share link.')),
        );
      }
    }
  }

  Future<void> _incrementViewCount() async {
    if (pinId == null) return;
    try {
      await supabase.rpc('increment_view_count', params: {'pin_id': pinId});
    } catch (_) {
      try {
        final res = await supabase
            .from('pins')
            .select('view_count')
            .eq('id', pinId!)
            .single();
        final current = (res['view_count'] ?? 0) as int;
        await supabase
            .from('pins')
            .update({'view_count': current + 1})
            .eq('id', pinId!);
      } catch (e) {
        debugPrint('Failed to increment view count: $e');
      }
    }
  }

  Future<void> _saveToBoard() async {
    if (pinId == null || isSaving) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save items.")),
      );
      return;
    }

    if (mounted) setState(() => isSaving = true);

    try {
      final boards = await supabase
          .from('boards')
          .select('id, name')
          .eq('user_id', uid)
          .order('created_at');

      if (!mounted) return;

      final selectedBoard = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _BoardPickerDialog(boards: boards),
      );

      if (selectedBoard == null) {
        if (mounted) setState(() => isSaving = false);
        return;
      }

      int boardId;

      if (selectedBoard['create_new'] == true) {
        final boardName = selectedBoard['name'] as String;
        debugPrint('Creating new board: $boardName for user: $uid');
        final newBoard = await supabase
            .from('boards')
            .insert({'user_id': uid, 'name': boardName})
            .select('id')
            .single();
        boardId = newBoard['id'] as int;
      } else {
        boardId = selectedBoard['id'] as int;
      }

      await supabase.from('boards_pins').upsert({
        'board_id': boardId,
        'pin_id': pinId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to board successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving to board: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
        _showItemDetails(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are out of credits!')),
        );
      }
    }
  }

  void _showItemDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.itemName),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Details revealed!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text("Metal: 18K Rose Gold"),
              Text("Weight: 3.5g"),
              Text("SKU: AKD-RN-1025"),
              SizedBox(height: 16),
              Text(
                "This is where you would show the detailed information after a credit is successfully used.",
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _useQuoteCredit(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    try {
      await supabase.rpc('decrement_credit');
      profile.decrementCredit();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Quote request sent! One credit used.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error using quote credit: $e');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Could not get quote. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
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
                      child: Text(
                        "More like this",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
              widget.imageUrl,
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
            child: Text(
              "More like this",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        _buildSimilarItemsGrid(isSliver: true),
      ],
    );
  }

  Widget _buildContentSection() {
    final theme = Theme.of(context);
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
          Text(widget.itemName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          if (likeCount > 0)
            Text(
              '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          Text("Description", style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            "A beautiful piece of jewelry crafted with precision and care. Each piece is unique and tells its own story.",
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
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    return [
      IconButton(
        onPressed: isLiking ? null : _toggleLike,
        icon: Icon(
          userLiked ? Icons.favorite : Icons.favorite_border,
          color: userLiked ? Colors.red : Theme.of(context).iconTheme.color,
        ),
        tooltip: userLiked ? 'Unlike' : 'Like',
      ),
      IconButton(
        onPressed: _sharePin,
        icon: const Icon(Icons.share_outlined),
        tooltip: 'Share',
      ),
      IconButton(
        onPressed: isSaving ? null : _saveToBoard,
        icon: isSaving
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
                  child: Center(child: CircularProgressIndicator()),
                )
              : const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return isSliver
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : const SizedBox.shrink();
        }

        final items = snapshot.data!;
        final grid = MasonryGridView.count(
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
                    builder: (_) => JewelryDetailScreen(
                      imageUrl: item.imageUrl,
                      itemName: item.name,
                      pinId: item.id,
                    ),
                  ),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            );
          },
        );

        if (isSliver) {
          return SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: grid,
          );
        } else {
          return Padding(padding: const EdgeInsets.all(8.0), child: grid);
        }
      },
    );
  }
}

class _BoardPickerDialog extends StatefulWidget {
  final List<dynamic> boards;

  const _BoardPickerDialog({required this.boards});

  @override
  State<_BoardPickerDialog> createState() => _BoardPickerDialogState();
}

class _BoardPickerDialogState extends State<_BoardPickerDialog> {
  int? selectedBoardId;
  final TextEditingController newBoardController = TextEditingController();
  bool showNewBoardField = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save to Board'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.boards.isNotEmpty) ...[
              SizedBox(
                height: 200,
                width: 300,
                child: ListView.builder(
                  itemCount: widget.boards.length,
                  itemBuilder: (_, i) {
                    final board = widget.boards[i] as Map<String, dynamic>;
                    return RadioListTile<int>(
                      value: board['id'] as int,
                      groupValue: selectedBoardId,
                      onChanged: (v) {
                        setState(() {
                          selectedBoardId = v;
                          showNewBoardField = false;
                        });
                      },
                      title: Text(board['name'] as String),
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            ListTile(
              leading: Radio<int?>(
                value: -1,
                groupValue: selectedBoardId,
                onChanged: (v) {
                  setState(() {
                    selectedBoardId = v;
                    showNewBoardField = true;
                  });
                },
              ),
              title: const Text('Create new board'),
              onTap: () {
                setState(() {
                  selectedBoardId = -1;
                  showNewBoardField = true;
                });
              },
            ),
            if (showNewBoardField) ...[
              const SizedBox(height: 8),
              TextField(
                controller: newBoardController,
                decoration: const InputDecoration(
                  labelText: 'Board name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (selectedBoardId == -1) {
              if (newBoardController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'id': -1,
                'name': newBoardController.text.trim(),
                'create_new': true,
              });
            } else if (selectedBoardId != null) {
              Navigator.pop(context, {
                'id': selectedBoardId,
                'create_new': false,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
