import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
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

  // Ensures a Supabase session exists.
  Future<void> _ensureSupabaseSession() async {
    try {
      if (supabase.auth.currentUser != null) {
        return; // Session already exists
      }
      // If no session exists, user needs to log in again
      debugPrint('No Supabase session found');
    } catch (e) {
      debugPrint('Error ensuring Supabase session: $e');
    }
  }

  // Fetches pin details or creates a new pin if it doesn't exist.
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
          // Can't create a pin if user is not logged in.
          debugPrint("Cannot create pin: User not logged in.");
          if (mounted) setState(() => isLoading = false);
          return;
        }
        // Pin doesn't exist, so we create it.
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

      // Increment view count for analytics
      await _incrementViewCount();

      // If a user is logged in, check their like status for this pin.
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

  // Toggles the like status for a pin.
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
        // Unlike
        await supabase.from('user_likes').delete().match({
          'user_id': uid,
          'pin_id': pinId!,
        });
        await supabase.rpc(
          'increment_like_count',
          params: {'pin_id_to_update': pinId, 'delta': -1},
        );
      } else {
        // Like
        await supabase.from('user_likes').insert({
          'user_id': uid,
          'pin_id': pinId,
        });
        await supabase.rpc(
          'increment_like_count',
          params: {'pin_id_to_update': pinId, 'delta': 1},
        );
      }

      // Fetch the updated count to ensure UI is accurate
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

  // Generates a unique link and opens the native share dialog.
  Future<void> _sharePin() async {
    if (pinId == null) return;

    try {
      // Generate and save the slug if it doesn't exist yet
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

      // Allow base share URL to be configured via env; fallback to daginawala.in
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

  // Increment view count for the pin. Tries an RPC first, otherwise does a safe select+update.
  Future<void> _incrementViewCount() async {
    if (pinId == null) return;
    try {
      // Prefer RPC if available for atomic increment
      await supabase.rpc('increment_view_count', params: {'pin_id': pinId});
    } catch (_) {
      try {
        // Fallback: read current count and increment
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

  // Allows the user to save a pin to a new or existing board.
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
      // Fetch user's existing boards
      final boards = await supabase
          .from('boards')
          .select('id, name')
          .eq('user_id', uid)
          .order('created_at');

      if (!mounted) return;

      // Show the dialog to pick or create a board
      final selectedBoard = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _BoardPickerDialog(boards: boards),
      );

      // If the user cancelled, do nothing
      if (selectedBoard == null) {
        if (mounted) setState(() => isSaving = false);
        return;
      }

      int boardId;

      // If user chose to create a new board
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

      // Use upsert to prevent duplicates
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

  void _onGetQuotePressed(BuildContext context) {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    if (profile.isMember) {
      if (profile.creditsRemaining > 0) {
        _useQuoteCredit(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are out of quotes for today!')),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Member Exclusive"),
          content: const Text(
            "Getting a quote is a premium feature available only to lifetime members.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Maybe Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BuyMembershipScreen(),
                  ),
                );
              },
              child: const Text("Upgrade Now"),
            ),
          ],
        ),
      );
    }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Image.network(widget.imageUrl, fit: BoxFit.cover),
              ),
              Expanded(
                flex: 2,
                child: Scaffold(
                  appBar: AppBar(elevation: 0),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildContentSection(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        _buildSimilarItemsGrid(),
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
          Text(widget.itemName, style: theme.textTheme.displaySmall),
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
              child: const Text('Get Quote'),
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

  Widget _buildSimilarItemsGrid() {
    return FutureBuilder<List<JewelryItem>>(
      future: _similarItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final items = snapshot.data!;
        return SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () {
                  // Navigate to the detail screen for the similar item
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
          ),
        );
      },
    );
  }
}

// Keep the _BoardPickerDialog class exactly as it is.
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
              // Create new board
              if (newBoardController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'id': -1,
                'name': newBoardController.text.trim(),
                'create_new': true,
              });
            } else if (selectedBoardId != null) {
              // Use existing board
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
