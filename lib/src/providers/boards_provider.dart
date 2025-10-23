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
          .select('id, name, is_secret')
          .eq('user_id', userId);

      _boards.clear();
      for (var boardData in response) {
        _boards.add(
          Board(
            id: boardData['id'],
            name: boardData['name'],
            isSecret: boardData['is_secret'] ?? false,
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching boards: $e");
    }
  }

  Future<void> updateBoard(int boardId, String name, bool isSecret) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('boards')
          .update({
            'name': name,
            'is_secret': isSecret,
          })
          .eq('id', boardId)
          .eq('user_id', user.id);
      final index = _boards.indexWhere((board) => board.id == boardId);
      if (index != -1) {
        _boards[index] = Board(
          id: boardId,
          name: name,
          isSecret: isSecret,
          coverUrls: _boards[index].coverUrls,
          items: _boards[index].items,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating board: $e');
      throw Exception('Failed to update board');
    }
  }

  Future<void> createBoard(String name, {bool isSecret = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final response = await _supabase.from('boards').insert({
      'user_id': user.id,
      'name': name,
      'is_secret': isSecret,
    }).select();

    final newBoard = Board.fromJson(response.first);
    _boards.add(newBoard);
    notifyListeners();
  }

  Future<void> deleteBoard(int boardId) async {
    await _supabase.from('boards').delete().eq('id', boardId);

    _boards.removeWhere((board) => board.id == boardId);
    notifyListeners();
  }

  Future<void> saveToBoard(int boardId, JewelryItem item) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final existingPin = await _supabase
          .from('pins')
          .select('id')
          .eq('image_url', item.image)
          .maybeSingle();

      String pinId;
      if (existingPin != null) {
        pinId = existingPin['id'] as String;
      } else {
        final newPin = await _supabase.from('pins').insert({
          'image_url': item.image,
          'title': item.productTitle,
          'description': item.description,
          'owner_id': user.id,
        }).select('id').single();
       
        pinId = newPin['id'] as String;
      }

      final existingBoardPin = await _supabase
        .from('boards_pins')
        .select('board_id')
        .match({'board_id': boardId, 'pin_id': pinId})
        .maybeSingle();

      if (existingBoardPin == null) {
        await _supabase.from('boards_pins').insert({
          'board_id': boardId,
          'pin_id': pinId, 
        });
      } else {
         debugPrint("Pin already exists in this board.");
      
         throw Exception('Item is already in this board.');
      }

      final boardIndex = _boards.indexWhere((board) => board.id == boardId);
      if (boardIndex != -1) {
        final existingBoard = _boards[boardIndex];
        if (!existingBoard.items.any((i) => i.id == item.id)) {
            final updatedItems = List<JewelryItem>.from(existingBoard.items)
            ..add(item);
             _boards[boardIndex] = existingBoard.copyWith(items: updatedItems);
             notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error saving to board: $e');
      rethrow;
    }
  }
}