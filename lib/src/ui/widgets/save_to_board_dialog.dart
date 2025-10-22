import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/boards_provider.dart';
import 'package:provider/provider.dart';

class SaveToBoardDialog extends StatefulWidget {
  final JewelryItem item;

  const SaveToBoardDialog({super.key, required this.item});

  @override
  State<SaveToBoardDialog> createState() => _SaveToBoardDialogState();
}

class _SaveToBoardDialogState extends State<SaveToBoardDialog> {
  final _newBoardController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newBoardController.dispose();
    super.dispose();
  }

  Future<void> _createBoard() async {
    if (_formKey.currentState!.validate()) {
      final boardName = _newBoardController.text.trim();
      final boardsProvider = context.read<BoardsProvider>();

      if (boardsProvider.boards.any((board) => board.name == boardName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A board with this name already exists.'),
          ),
        );
      } else {
        await boardsProvider.createBoard(boardName);
        _newBoardController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to rebuild the list when boards change
    return Consumer<BoardsProvider>(
      builder: (context, boardsProvider, child) {
        return AlertDialog(
          title: const Text('Save to Board'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // List of existing boards
                if (boardsProvider.boards.isNotEmpty)
                  SizedBox(
                    height: 200, // Constrain height to make it scrollable
                    child: ListView(
                      shrinkWrap: true,
                      children: boardsProvider.boards.map((board) {
                        return ListTile(
                          title: Text(board.name),
                          onTap: () async {
                            // --- FIX: Pass board.id (int) instead of board (Board) ---
                            await boardsProvider.saveToBoard(
                              board.id,
                              widget.item,
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved to ${board.name}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),

                // Form to create a new board
                Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newBoardController,
                          decoration: const InputDecoration(
                            labelText: 'Create a new board',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a board name';
                            }
                            return null;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _createBoard,
                        tooltip: 'Create Board',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}