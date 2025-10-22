import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart'; // Corrected path
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:provider/provider.dart';

class BoardDetailScreen extends StatefulWidget {
  final int boardId; // Use int ID
  final String boardName;

  const BoardDetailScreen({
    Key? key,
    required this.boardId,
    required this.boardName,
  }) : super(key: key);

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<JewelryItem> _pins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPinsForBoard();
  }

  Future<void> _fetchPinsForBoard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('boards_pins')
          .select('pins(*)') // Select all columns from the linked 'pins' table
          .eq('board_id', widget.boardId);

      final List<dynamic> data = response as List<dynamic>;
      final fetchedPins = data
          .map((e) => JewelryItem.fromJson(e['pins'] as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _pins = fetchedPins;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pins for board: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pins: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- This function correctly expects an int ---
  Future<void> _removePinFromBoard(int pinId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Remove Pin?"),
          content: const Text(
              "Are you sure you want to remove this pin from the board?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Remove", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('boards_pins')
          .delete()
          .eq('board_id', widget.boardId)
          .eq('pin_id', pinId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pin removed from board.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPinsForBoard(); // Refresh the list of pins
        // Also notify BoardsProvider to refresh cover images if this was one
        Provider.of<BoardsProvider>(context, listen: false).fetchBoards();
      }
    } catch (e) {
      debugPrint('Error removing pin from board: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove pin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pins.isEmpty
              ? const Center(
                  child: Text("No pins in this board yet. Start saving!"))
              : MasonryGridView.count(
                  crossAxisCount: (MediaQuery.of(context).size.width / 180)
                      .floor()
                      .clamp(2, 5),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  padding: const EdgeInsets.all(8),
                  itemCount: _pins.length,
                  itemBuilder: (context, index) {
                    final pin = _pins[index];
                    return GestureDetector(
                      onTap: () {
                        // --- This is the navigation logic you wanted ---
                        // It was already correct.
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => JewelryDetailScreen(
                                jewelryItem: pin), // Pass the entire item
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              // --- This now works due to the fix in jewelry_item.dart ---
                              aspectRatio: pin.aspectRatio,
                              child: Image.network(
                                pin.image,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                        child: Icon(Icons.broken_image)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                pin.productTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // --- Add a button to remove the pin ---
                            Align(
                              alignment: Alignment.bottomRight,
                              child: IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.grey),
                                // --- FIX: Parse the String ID to an int ---
                                onPressed: () =>
                                    _removePinFromBoard(int.parse(pin.id)),
                                tooltip: 'Remove from board',
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
