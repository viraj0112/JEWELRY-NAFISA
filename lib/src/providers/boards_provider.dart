
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/board.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoardsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final List<Board> _boards = [];

  List<Board> get boards => _boards;

  Future<void> fetchBoards() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('boards')
          .select('id, name')
          .eq('user_id', userId);

      _boards.clear();
      for (var boardData in response) {
        _boards.add(
          Board(
            id: boardData['id'], 
            name: boardData['name'],
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching boards: $e");
    }
  }

  Future<void> createBoard(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final newBoardData = await _supabase
          .from('boards')
          .insert({'user_id': userId, 'name': name})
          .select()
          .single();

      final newBoard = Board(
        id: newBoardData['id'], 
        name: newBoardData['name'],
      );
      _boards.add(newBoard);
      notifyListeners();
    } catch (e) {
      debugPrint("Error creating board: $e");
    }
  }

  Future<void> saveToBoard(Board board, JewelryItem item) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {

      final existingPin = await _supabase
          .from('pins')
          .select('id')
          .eq('image_url', item.imageUrl)
          .maybeSingle();

      String pinId;

      if (existingPin != null) {
        pinId = existingPin['id'];
      } else {
        final newPin = await _supabase
            .from('pins')
            .insert({
              'owner_id': userId,
              'title': item.name,
              'image_url': item.imageUrl,
              'description': item.description,
            })
            .select('id')
            .single();
        pinId = newPin['id'];
      }

      await _supabase.from('boards_pins').insert({
        'board_id': board.id,
        'pin_id': pinId,
      });

      final boardIndex = _boards.indexWhere((b) => b.id == board.id);
      if (boardIndex != -1 &&
          !_boards[boardIndex].items.any((i) => i.id == item.id)) {
        _boards[boardIndex].items.add(item);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error saving to board: $e");
      rethrow;
    }
  }
}