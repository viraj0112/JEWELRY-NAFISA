import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class BoardDetailScreen extends StatefulWidget {
  final int boardId;
  final String boardName;

  const BoardDetailScreen({
    required this.boardId,
    required this.boardName,
    super.key,
  });

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _pinsFuture;

  @override
  void initState() {
    super.initState();
    _pinsFuture = _fetchPins();
  }

  Future<List<Map<String, dynamic>>> _fetchPins() async {
    try {
      final resp = await _supabase
          .from('boards_pins')
          .select('pin_id')
          .eq('board_id', widget.boardId)
          .order('created_at', ascending: false);
      final items = resp as List<dynamic>;
      final List<Map<String, dynamic>> pins = [];
      for (final i in items) {
        final pinId = i['pin_id'] as String;
        final pin = await _supabase
            .from('pins')
            .select('id, image_url, title, description')
            .eq('id', pinId)
            .maybeSingle();
        if (pin != null) pins.add(Map<String, dynamic>.from(pin as Map));
      }
      return pins;
    } catch (e) {
      debugPrint('Error fetching board pins: $e');
      return [];
    }
  }

  Future<void> _removePin(String pinId) async {
    try {
      await _supabase.from('boards_pins').delete().match({
        'board_id': widget.boardId,
        'pin_id': pinId,
      });
      if (mounted) setState(() => _pinsFuture = _fetchPins());
    } catch (e) {
      debugPrint('Error removing pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove pin')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pinsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final pins = snapshot.data ?? [];
          if (pins.isEmpty) {
            return const Center(
              child: Text('No images saved to this board yet'),
            );
          }

          return MasonryGridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.all(12),
            itemCount: pins.length,
            itemBuilder: (context, index) {
              final pin = pins[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(
                        pin['image_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pin['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove image?'),
                                  content: const Text(
                                    'Remove this image from the board?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _removePin(pin['id'] as String);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
